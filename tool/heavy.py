#!/usr/bin/env python3
"""The queue every heavy command goes through, so a machine is never asked for more than it has.

    just heavy <command...>        run it when a slot is free (waits its turn)
    just heavy --status            who holds a slot, since when, who waits
    tool/heavy.py [--name WORDS] [--] <command...>

A whole-suite Flutter test, a web build, the phone-frames run and the backend suite each
take gigabytes and every core. Five at once restarted the machine; one at a time (an
ad hoc `flock`) made forty-minute queues. This is a counting queue: SLOTS jobs run at
once (what the machine's memory carries: `DEFAULT_SLOTS`, measured; `HEAVY_SLOTS=n`
overrides), the rest wait in the order they came.

- A slot is a file lock held by this process alone. It is opened so that no child
  inherits it (a command that leaves a daemon behind can never hold a slot), and it is
  released on any exit, `kill -9` included.
- The command runs in its own process group. Ctrl-C and `kill` reach all of it. When it
  ends, anything it left running in that group is stopped, and said. If this process is
  killed outright the command's own process is killed with it.
- Waiting is never silent: where you stand is printed at once, and again every
  `REPORT` seconds with who holds the slots.
- A command run by another heavy command (a recipe calling a recipe) runs at once: it
  is inside its parent's slot (`HEAVY_SLOT` in the environment says so). On GitHub
  (`CI` set) one job has the whole machine, so nothing queues.
- Each run records its time and its peak memory (the sum over every process it
  started) in `history.jsonl`, and prints them at the end: that is how SLOTS is chosen.

State lives in `HEAVY_DIR` (default /tmp/midnight-village-heavy), shared by every
checkout and session on the machine.
"""

import fcntl
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

# Measured on 27 Nov 2026, 15 GB and 4 cores (docs/dev/running-the-work.md, "Heavy work").
# The most any one job peaked at, in MB; a slot count is what fits after the headroom.
JOB_PEAK_MB = 4000
HEADROOM_MB = 3000
MAX_SLOTS = 3
# Waiting says where it is this often (seconds), and a job's memory is sampled this often.
REPORT = float(os.environ.get("HEAVY_REPORT") or 30)
SAMPLE = float(os.environ.get("HEAVY_SAMPLE") or 2)
HISTORY_LINES = 200


def state_dir() -> Path:
    return Path(os.environ.get("HEAVY_DIR") or "/tmp/midnight-village-heavy")


def memory_mb() -> int:
    for line in Path("/proc/meminfo").read_text().splitlines():
        if line.startswith("MemTotal:"):
            return int(line.split()[1]) // 1024
    return 0


def slot_count() -> int:
    """How many jobs run at once: set by HEAVY_SLOTS, else by the memory the machine has."""
    given = os.environ.get("HEAVY_SLOTS", "")
    if given.isdigit() and int(given) > 0:
        return int(given)
    fits = (memory_mb() - HEADROOM_MB) // JOB_PEAK_MB
    return max(1, min(MAX_SLOTS, fits))


def say(text: str) -> None:
    """A notice for whoever started this. A caller that keeps the command's output in a
    file passes a copy of its own stderr (`HEAVY_SAY_FD`), so the notice is not buried."""
    fd = os.environ.get("HEAVY_SAY_FD", "")
    try:
        os.write(int(fd) if fd.isdigit() else 2, (text + "\n").encode())
    except OSError:
        pass


def shorten(words: str, width: int = 70) -> str:
    return words if len(words) <= width else words[: width - 1] + "…"


def span(seconds: float) -> str:
    seconds = int(seconds)
    if seconds < 90:
        return f"{seconds} s"
    if seconds < 5400:
        return f"{seconds // 60} min {seconds % 60:02d} s"
    return f"{seconds // 3600} h {seconds % 3600 // 60:02d} min"


def open_lock(path: Path) -> int:
    """A lock file anyone may use. Not inheritable (Python's default): no child gets it."""
    fd = os.open(path, os.O_RDWR | os.O_CREAT, 0o666)
    try:
        os.chmod(path, 0o666)
    except OSError:
        pass  # another user's file: the mode is theirs, the lock still works
    return fd


def try_lock(fd: int) -> bool:
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return True
    except BlockingIOError:
        return False


def is_held(path: Path) -> bool:
    """True while some process holds the lock on this file."""
    if not path.exists():
        return False
    fd = open_lock(path)
    try:
        if try_lock(fd):
            return False
        return True
    finally:
        os.close(fd)


def read_info(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


def write_info(fd: int, info: dict) -> None:
    os.ftruncate(fd, 0)
    os.pwrite(fd, json.dumps(info).encode(), 0)


# ---- the queue --------------------------------------------------------------------


class Queue:
    def __init__(self, root: Path, slots: int):
        self.root, self.slots = root, slots
        self.waiting = root / "waiting"
        self.waiting.mkdir(parents=True, exist_ok=True)
        try:
            os.chmod(root, 0o1777)
            os.chmod(self.waiting, 0o1777)
        except OSError:
            pass
        self.gate = open_lock(root / "gate.lock")

    def slot_path(self, number: int) -> Path:
        return self.root / f"slot-{number}.lock"

    def holders(self) -> list[tuple[int, dict]]:
        """(slot number, what holds it) for every slot that is held now."""
        found = []
        for number in range(1, max(self.slots, self.highest_slot()) + 1):
            path = self.slot_path(number)
            if is_held(path):
                found.append((number, read_info(path)))
        return found

    def highest_slot(self) -> int:
        numbers = [
            int(p.stem.split("-")[1])
            for p in self.root.glob("slot-*.lock")
            if p.stem.split("-")[1].isdigit()
        ]
        return max(numbers, default=0)

    def line(self, sweep: bool = False) -> list[tuple[Path, dict]]:
        """The waiters still alive, the one who came first first. A dead one is swept,
        but only by a caller holding the gate: a place being made looks dead until it
        is locked."""
        alive = []
        for path in sorted(self.waiting.glob("*.wait")):
            if is_held(path):
                alive.append((path, read_info(path)))
            elif sweep:
                try:
                    path.unlink()
                except OSError:
                    pass
        return alive

    def enter(self, info: dict) -> tuple[Path, int]:
        """Take a place at the end of the line. The place is a locked file: it is
        alive while this process is."""
        fcntl.flock(self.gate, fcntl.LOCK_EX)
        try:
            name = f"{time.time_ns():020d}-{os.getpid()}.wait"
            path = self.waiting / name
            fd = open_lock(path)
            fcntl.flock(fd, fcntl.LOCK_EX)
            write_info(fd, info)
            return path, fd
        finally:
            fcntl.flock(self.gate, fcntl.LOCK_UN)

    def try_take(self, place: Path, info: dict) -> int | None:
        """The slot's fd when it is this waiter's turn and a slot is free, else None."""
        fcntl.flock(self.gate, fcntl.LOCK_EX)
        try:
            ahead = [p for p, _ in self.line(sweep=True) if p.name < place.name]
            if ahead:
                return None
            for number in range(1, self.slots + 1):
                fd = open_lock(self.slot_path(number))
                if try_lock(fd):
                    write_info(fd, {**info, "slot": number, "since": time.time()})
                    return fd
                os.close(fd)
            return None
        finally:
            fcntl.flock(self.gate, fcntl.LOCK_UN)

    def where(self, place: Path) -> tuple[int, list[tuple[int, dict]], int]:
        """(my place in the line, the slot holders, how many wait in all)."""
        line = [p for p, _ in self.line()]
        mine = line.index(place) + 1 if place in line else len(line) + 1
        return mine, self.holders(), len(line)


def who(info: dict) -> str:
    where = f" in {info['where']}" if info.get("where") else ""
    return f"`{info.get('name', '?')}`{where} (pid {info.get('pid', '?')})"


def status_text(queue: Queue) -> str:
    now = time.time()
    held = queue.holders()
    waiting = queue.line()
    out = [
        f"heavy: {len(held)} of {queue.slots} slots busy, {len(waiting)} waiting"
        f" (this machine: {memory_mb() // 1024} GB, a job peaks at up to"
        f" {JOB_PEAK_MB / 1000:.0f} GB)"
    ]
    for number, info in held:
        out.append(
            f"  slot {number}: {who(info)}, held {span(now - info.get('since', now))}"
        )
    for place, (path, info) in enumerate(waiting, 1):
        out.append(
            f"  waiting {place}: {who(info)}, for {span(now - info.get('queued', now))}"
        )
    recent = history(queue.root)[-3:]
    for row in recent:
        out.append(
            f"  last: `{row['name']}` {span(row['seconds'])}, peak {row['peak_mb'] / 1000:.1f} GB,"
            f" exit {row['exit']}"
        )
    return "\n".join(out)


# ---- running a command ---------------------------------------------------------------


def members(session: int) -> list[int]:
    """Every live process of the command's session (a zombie is not one). A command
    that gives a part of itself a group of its own (`set -m`) is still in its session."""
    found = []
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            fields = (entry / "stat").read_text().rsplit(")", 1)[1].split()
            if int(fields[3]) == session and fields[0] != "Z":
                found.append(int(entry.name))
        except (OSError, IndexError, ValueError):
            continue
    return found


def tree_memory_mb(session: int) -> int:
    """Memory of every process in the command's session, in MB (proportional set size
    where readable, so a library shared by ten processes counts once)."""
    total_kb = 0
    for pid in members(session):
        entry = Path("/proc") / str(pid)
        try:
            text = (entry / "smaps_rollup").read_text()
            total_kb += next(
                int(line.split()[1])
                for line in text.splitlines()
                if line.startswith("Pss:")
            )
        except (OSError, StopIteration):
            try:
                fields = (entry / "stat").read_text().rsplit(")", 1)[1].split()
                total_kb += int(fields[21]) * (os.sysconf("SC_PAGE_SIZE") // 1024)
            except (OSError, IndexError, ValueError):
                continue
    return total_kb // 1024


def signal_all(session: int, number: int) -> None:
    for pid in members(session):
        try:
            os.kill(pid, number)
        except (ProcessLookupError, PermissionError):
            pass


def stop_session(session: int, grace: float = 3.0) -> int:
    """Stop what is left of a command; how many were left (0: nothing)."""
    left = len(members(session))
    if not left:
        return 0
    signal_all(session, signal.SIGTERM)
    end = time.monotonic() + grace
    while members(session) and time.monotonic() < end:
        time.sleep(0.1)
    signal_all(session, signal.SIGKILL)
    return left


def die_with_parent() -> None:
    """The command is killed if this process is (Linux): a slot freed by a crash must
    not leave its work running unqueued."""
    try:
        import ctypes

        ctypes.CDLL("libc.so.6", use_errno=True).prctl(
            1, signal.SIGKILL
        )  # PR_SET_PDEATHSIG
    except (OSError, AttributeError):
        pass


def run_command(command: list[str], env: dict) -> tuple[int, int]:
    """Runs it, in a group of its own, until it ends: (exit code, peak MB)."""
    child = subprocess.Popen(
        command, env=env, start_new_session=True, preexec_fn=die_with_parent
    )
    group, peak = child.pid, 0

    def forward(number, _frame):
        signal_all(group, number)

    for number in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(number, forward)
    while True:
        try:
            code = child.wait(timeout=SAMPLE)
            break
        except subprocess.TimeoutExpired:
            peak = max(peak, tree_memory_mb(group))
    left = stop_session(group)
    if left:
        say(
            f"heavy: the command ended and left {left} process{'es' if left > 1 else ''}"
            " running; stopped them."
        )
    return (128 - code if code < 0 else code), peak


def history(root: Path) -> list[dict]:
    rows = []
    try:
        for line in (root / "history.jsonl").read_text().splitlines():
            try:
                rows.append(json.loads(line))
            except ValueError:
                continue
    except OSError:
        pass
    return rows


def record(root: Path, row: dict) -> None:
    path = root / "history.jsonl"
    rows = history(root)[-(HISTORY_LINES - 1) :] + [row]
    try:
        path.write_text("".join(json.dumps(r) + "\n" for r in rows))
        os.chmod(path, 0o666)
    except OSError:
        pass  # a history that cannot be kept is no reason to fail a job


def passes_through(env) -> bool:
    return bool(env.get("HEAVY_SLOT")) or bool(env.get("CI"))


LIGHT = {"check", "analyze", "format-check", "test-guardrails", "guard-edits", "lint", "typecheck"}


def wrap(command: list[str], name: str) -> list[str]:
    """The command, to be run through the queue unless it is a light one (a recipe
    that only reads or lints). Used by the tools that run steps themselves."""
    if command[:1] == ["just"] and len(command) > 1 and command[1] in LIGHT:
        return command
    return [sys.executable, str(Path(__file__).resolve()), "--name", name, "--", *command]


def wait_for_slot(queue: Queue, info: dict) -> tuple[int, float]:
    """Waits in line for a slot, saying where it stands at once and every REPORT
    seconds: (the slot's fd, seconds waited)."""
    queued = time.monotonic()
    place, wait_fd = queue.enter(info)
    slot_fd = queue.try_take(place, info)
    last_said = None
    while slot_fd is None:
        if last_said is None or time.monotonic() - last_said >= REPORT:
            last_said = time.monotonic()
            mine, held, _ = queue.where(place)
            running = ", ".join(
                f"{who(i)} for {span(time.time() - i.get('since', 0))}" for _, i in held
            )
            say(
                f"heavy: waiting for a slot ({len(held)} of {queue.slots} busy): number {mine}"
                f" in line, {span(time.monotonic() - queued)} so far."
                f" Running: {running or 'nothing (your turn soon)'}."
                "  `just heavy --status` shows it. Do not poll: start this command"
                " with run_in_background and end your turn."
            )
        time.sleep(0.5)
        slot_fd = queue.try_take(place, info)
    try:
        place.unlink()
    except OSError:
        pass
    os.close(wait_fd)
    return slot_fd, time.monotonic() - queued


def main(argv: list[str]) -> int:
    name = None
    args = list(argv)
    if args[:1] == ["--status"]:
        print(status_text(Queue(state_dir(), slot_count())))
        return 0
    if args[:1] == ["--name"] and len(args) > 2:
        name, args = args[1], args[2:]
    if args[:1] == ["--"]:
        args = args[1:]
    if not args:
        print("usage: just heavy <command...>   |   just heavy --status", file=sys.stderr)
        return 2
    if passes_through(os.environ):
        os.execvp(args[0], args)
    queue = Queue(state_dir(), slot_count())
    info = {
        "name": name or shorten(" ".join(args)),
        "pid": os.getpid(),
        "where": Path.cwd().name,
        "queued": time.time(),
        "user": os.environ.get("USER", ""),
    }
    slot_fd, waited = wait_for_slot(queue, info)
    if waited > 2:
        say(f"heavy: got a slot after {span(waited)}.")
    # The command is inside this slot: a recipe it calls runs at once (HEAVY_SLOT).
    env = {k: v for k, v in os.environ.items() if k != "HEAVY_SAY_FD"}
    env["HEAVY_SLOT"] = "1"
    started = time.monotonic()
    code, peak = run_command(args, env)
    took = time.monotonic() - started
    say(f"heavy: done in {span(took)}, exit {code}, peak memory {peak / 1000:.1f} GB.")
    record(
        queue.root,
        {
            "name": info["name"],
            "seconds": round(took),
            "peak_mb": peak,
            "exit": code,
            "at": time.strftime("%Y-%m-%d %H:%M"),
        },
    )
    os.close(slot_fd)
    return code


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
