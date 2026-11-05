# CLAUDE.md

Read **`AGENTS.md`** first and follow it. The short version:

1. **Read `Docs/JOURNAL.md` first.** It holds the vision, the hard decisions D1–D9 (never reverse them) and the open decisions. **Before you finish, append a dated Log entry**: what you changed, why, the results (`verify-all.sh` outcome, test counts, coverage) and follow-ups. Update the Next steps and Human to-dos sections if they changed.
2. `Scripts/verify-all.sh` (`make verify`) is the only definition of green. CI runs the same script.
3. Never disable or skip a test to get green, and never lower the coverage threshold. Fix the code, or fix the test and give the reason.
4. On a Mac, follow `Docs/MAC_AGENT_HANDOFF.md`. It covers prerequisites, the loop, signing, the manual checklists and the Definition of Done.
