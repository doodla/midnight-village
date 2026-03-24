# How to Use Midnight Village's Dev Setup

You're the game designer. Claude is the dev team. Here's how it works.

## One Command

```
/orchestrate
build the night phase
```

That's it. Claude figures out what needs to happen and does it:

- **No plan exists?** Creates milestones, reviews them with a critic, presents for your approval.
- **Plan approved?** Picks tasks, implements them, reviews the code with parallel agents, commits.
- **Milestone done?** Reports what was built, asks if you're ready to playtest.
- **Resuming after /clear or crash?** Recovers from files + git. Safe to restart anytime.

## What You'll Be Asked About

- **Scope:** "Should we build X or Y first?"
- **Game design:** "Is this fun? Does this feel right?"
- **Plan approval:** "Here are the milestones. Good to go?"
- **Milestone complete:** "Night phase is done. Ready to playtest?"

## What You Won't Be Asked About

- Which Django pattern to use
- How to structure the state machine
- Code style, architecture, testing approach
- Review cycle management
- Bug fixes during implementation

## Giving Direction

Be as vague or specific as you want:

```
build the night phase
the voting feels wrong, make it more dramatic
let's do lobby next but skip QR codes for now
I found a bug — seer can see two players instead of one
this is great, ship it
```

## What Happens Behind the Scenes

1. `/orchestrate` runs in the main conversation and coordinates everything
2. Specialized agents handle the heavy lifting — each in its own context window
3. A `challenger` agent checks for common AI failure modes at key decision points
4. **Hooks mechanically enforce quality** — commits are blocked unless lint + tests pass. This isn't optional; it's physically impossible to commit broken code.
5. State persists in `.plan/` — survives crashes, `/clear`, context resets

## Tips

- **`/clear` is safe.** State recovers from files + git.
- **Don't micro-manage.** If Claude asks too many questions, say "just do it."
- **Quality is mechanical.** Linting, type checking, tests, and multi-agent review happen every time. Enforced by hooks, not by the model's memory.

## Under the Hood

See `docs/claude-architecture.md` for the full technical breakdown — what each agent does, why the hooks exist, and what catches each failure mode.
