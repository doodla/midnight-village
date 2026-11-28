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
   whose quotes are not where it says, lists comments no row judged, never deletes an
   always-kept line (a `Guard file` marker, a generated header, a spec link, a licence) or a
   suppression, gives the same words one verdict, and prints the counts and the applied,
   proposed and review lists. A file under "Sort again": rerun its sorter once, saying what
   was wrong; what still fails goes to review.
4. **Check five applied deletions** against the code. One that is wrong: tighten its class in
   `tool/empty_comments.py`.
5. **The sorters propose; code applies only the provably empty** (`--apply`). You decide
   each proposed one, and delete a "why" only when a test or a name in this change says it.
   Run `just piece-check`, and commit the deletions on their own.
6. **Report in the hand-over**: applied / proposed / kept / review counts, the lists, and each
   "do not change this" comment kept. Such a comment becomes a check through the `correct`
   skill, or it stays.
