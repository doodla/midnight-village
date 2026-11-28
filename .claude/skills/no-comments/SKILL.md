---
name: no-comments
description: At hand-over, sort the comments a change adds, edits or makes untrue (delete the safe ones, keep the ones that carry knowledge, list the rest for the builder) with one cheap haiku sorter per file. The change only, never the whole repo.
---

# No comments

Scope: the comments on the lines your change adds or edits, and the comments it makes
untrue. Never the rest of the repo; never generated files. Do not stop for approval.

1. **List the files**: `python3 tool/comment_rows.py --files`. It reads your working tree
   against the main it was built on (`--range A..B` for commits, `-- <paths>` to narrow) and
   prints each file with the lines where the change added a comment, generated files left out.
2. **Fan out, one file each, in one message.** Per file, an Agent call with
   `subagent_type: "worker"`, `model: "haiku"`, and the prompt: "Read
   `.claude/skills/no-comments/sorter.md` and follow it. File: <path>. Comments added at
   lines: <lines>. Diff: `git diff <base> -- <path>`." The sorter's rules live in that file
   only; do not restate them.
3. **Check the answers.** Save each answer in your scratchpad, then run
   `python3 tool/comment_rows.py <answer files>` with the same range and paths. It drops a row
   whose quoted comment or code is not at its line, lists comments no row judged, turns a
   deletion of an always-kept line (a `Guard file` marker, a generated header, a spec link, a
   licence) into a keep and of a lint suppression into a review, and prints the counts, five
   deletions and the review list. A file under "Sort again": rerun its sorter once, saying what
   was wrong; what still fails goes to review.
4. **Check the five deletions yourself** against the code printed beside them. If one is not
   narration, a banner, history, a "Part of" line, dead code or a wrong example, make it a keep
   and sort that file again.
5. **Apply only the safe deletions.** `--apply` deletes the whole-line `#` and `//` rows;
   delete the docstrings and comments after code it lists by hand. A "why" about our code goes
   only when the same change says it in a test, a type or a name. Run `just piece-check`, and
   commit the deletions on their own.
6. **Report in the hand-over**: deleted / kept / review counts, the review list, and each
   "do not change this" comment kept. Such a comment becomes a check through the `correct`
   skill, or it stays.
