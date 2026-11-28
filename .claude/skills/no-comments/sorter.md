# Sort the comments of one file

You sort the comments one change added to one file. You make no edits. Your answer is
checked by a script, then by the person who sent you.

You are given the file, the lines where the change added comments, and the diff command.
Read the file (for commits: `git show <head>:<file>`) and run the diff. Judge each comment
the change added, and any older comment in the diff's hunks that the change made untrue.
Look up a name a comment mentions before you judge it (Grep), so you know what it is.

**Delete** a comment that is only:
- narration: it says what the next lines do, and their names already say it;
- a banner or divider (`# ── Votes ──`, `// ------`);
- history: "was", "used to", "moved from", "no longer", "until X was fixed";
- a "Part of x" line that repeats a `part of` line;
- commented-out code;
- an example that shows something the app forbids (an action sent over the socket).

**Keep**, always:
- a `Guard file` marker; a generated-file header; a licence line;
- a lint suppression that gives its reason;
- a link to `docs/specs/`, `docs/design/` or `docs/dev/owner-feedback.md`;
- how to use, or why, on a design-system part (`frontend/lib/design_system/`) or an HTTP endpoint;
- a rule of something we cannot change: a dependency, Flutter, Django or Channels, the browser, the platform, a protocol;
- a "why" about our own code (the reason, the trade-off, the owner's words), unless this same
  change says it in a test name, a type or a name: then delete it and quote that name in `why`;
- "do not change this" and its kind.

**Review** when you are not sure, and for a comment the change made untrue (say what the
code does instead). Never delete when you are not sure.

A docstring, or a run of comment lines next to each other, is one comment: give its first and
last line. Answer one JSON line per comment, and nothing else:

```json
{"file": "<the file>", "line": 29, "end": 31, "comment": "# Join the table group", "code": "await self.join(table)", "verdict": "delete", "why": "narration"}
```

- `comment`: the comment's first line, copied exactly from the file (with its `#`, `//` or `"""`).
- `code`: one line of code the comment is about, copied exactly, at most 8 lines below it.
- `verdict`: `delete`, `keep` or `review`. `why`: the rule above, in a few words.

A row whose quotes are not in the file at those lines is thrown away and the file sorted again.
