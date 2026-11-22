"""checkout_files lists what a scan of a checkout reads: the files git tracks, plus new
files nobody has added yet, minus anything git ignores (a builder's copy of the repo under
.claude/worktrees/) and __pycache__. A file deleted from disk is never listed."""

import subprocess
from pathlib import Path

import pytest
from repo_files import checkout_files

pytestmark = pytest.mark.unit

REPO = Path(__file__).resolve().parents[2]


def _git(root: Path, *args: str) -> None:
    subprocess.run(  # noqa: S603 (git, on a test checkout made here)
        ["git", "-C", str(root), *args],  # noqa: S607
        check=True,
        capture_output=True,
    )


@pytest.fixture
def checkout(tmp_path: Path) -> Path:
    """A git checkout with one tracked doc, a .gitignore for worktrees, and no commits."""
    root = tmp_path / "checkout"
    (root / "docs").mkdir(parents=True)
    (root / "docs" / "guide.md").write_text("tracked\n")
    (root / ".gitignore").write_text(".claude/worktrees/\n")
    _git(root, "init", "-q")
    _git(root, "add", ".gitignore", "docs/guide.md")
    return root


def test_an_untracked_file_that_is_not_ignored_is_listed(checkout: Path) -> None:
    (checkout / "docs" / "new.md").write_text("written, not yet added\n")

    assert checkout_files(checkout, suffixes=(".md",)) == [
        checkout / "docs" / "guide.md",
        checkout / "docs" / "new.md",
    ]


def test_a_stray_copy_under_worktrees_is_not_listed(checkout: Path) -> None:
    stray = checkout / ".claude" / "worktrees" / "agent-7" / "docs"
    stray.mkdir(parents=True)
    (stray / "guide.md").write_text("an older copy, ignored by git\n")

    assert checkout_files(checkout, suffixes=(".md",)) == [
        checkout / "docs" / "guide.md"
    ]


def test_a_tracked_file_deleted_from_disk_is_not_listed(checkout: Path) -> None:
    (checkout / "docs" / "gone.md").write_text("tracked, then removed\n")
    _git(checkout, "add", "docs/gone.md")
    (checkout / "docs" / "gone.md").unlink()

    assert checkout_files(checkout, suffixes=(".md",)) == [
        checkout / "docs" / "guide.md"
    ]


def test_pycache_is_never_listed(checkout: Path) -> None:
    cache = checkout / "docs" / "__pycache__"
    cache.mkdir()
    (cache / "helper.py").write_text("x = 1\n")

    assert checkout_files(checkout) == [
        checkout / ".gitignore",
        checkout / "docs" / "guide.md",
    ]


def test_the_folder_and_the_suffixes_narrow_the_listing(checkout: Path) -> None:
    (checkout / "src").mkdir()
    (checkout / "src" / "app.py").write_text("x = 1\n")
    _git(checkout, "add", "src/app.py")

    assert checkout_files(checkout / "docs") == [checkout / "docs" / "guide.md"]
    assert checkout_files(checkout, suffixes=(".py",)) == [checkout / "src" / "app.py"]


def test_the_real_checkout_lists_its_files_and_no_worktree_copy_or_cache() -> None:
    listed = checkout_files(REPO)

    assert REPO / "justfile" in listed
    assert not any("worktrees" in path.relative_to(REPO).parts for path in listed)
    assert not any("__pycache__" in path.parts for path in listed)
