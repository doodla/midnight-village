"""tracked_files lists what git tracks in a checkout. A stray copy of the repo (a builder's
worktree under .claude/worktrees/, which git ignores) and an untracked file are never
listed, so a repo-wide scan cannot read them."""

import subprocess
from pathlib import Path

import pytest
from repo_files import tracked_files

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


def test_a_stray_copy_under_worktrees_is_not_listed(checkout: Path) -> None:
    stray = checkout / ".claude" / "worktrees" / "agent-7" / "docs"
    stray.mkdir(parents=True)
    (stray / "guide.md").write_text("an older copy, ignored by git\n")

    assert tracked_files(checkout, suffixes=(".md",)) == [
        checkout / "docs" / "guide.md"
    ]


def test_an_untracked_file_that_is_not_ignored_is_not_listed(checkout: Path) -> None:
    (checkout / "docs" / "new.md").write_text("written, not yet added\n")

    assert tracked_files(checkout, suffixes=(".md",)) == [
        checkout / "docs" / "guide.md"
    ]


def test_a_tracked_file_deleted_from_disk_is_not_listed(checkout: Path) -> None:
    (checkout / "docs" / "gone.md").write_text("tracked, then removed\n")
    _git(checkout, "add", "docs/gone.md")
    (checkout / "docs" / "gone.md").unlink()

    assert tracked_files(checkout, suffixes=(".md",)) == [
        checkout / "docs" / "guide.md"
    ]


def test_the_folder_and_the_suffixes_narrow_the_listing(checkout: Path) -> None:
    (checkout / "src").mkdir()
    (checkout / "src" / "app.py").write_text("x = 1\n")
    _git(checkout, "add", "src/app.py")

    assert tracked_files(checkout / "docs") == [checkout / "docs" / "guide.md"]
    assert tracked_files(checkout, suffixes=(".py",)) == [checkout / "src" / "app.py"]


def test_the_real_checkout_lists_its_tracked_files_and_no_worktree_copy() -> None:
    listed = tracked_files(REPO)

    assert REPO / "justfile" in listed
    assert not [
        path
        for path in listed
        if ".claude" in path.relative_to(REPO).parts[:1]
        and "worktrees" in path.relative_to(REPO).parts
    ]
