# AGENTS.md — rules for any AI agent working on DashCast

## Rule #1 — the journal
1. **Read `Docs/JOURNAL.md` first**: the vision, the hard decisions **D1–D10 (never reverse them without the owner; D10 = the classic UI is frozen, visual changes need owner-approved screenshots)**, the open decisions (O1…) and the human to-dos.
2. **Before you finish, append a dated Log entry** at the top of the journal's Log, in Bogotá time. Say what you changed, why, the results (the `Scripts/verify-all.sh` outcome, test counts, coverage) and any follow-ups. If the "Next steps" or "Human to-dos" sections changed, update them too.

## Rule #2 — one command decides "done"
```bash
Scripts/verify-all.sh        # or: make verify
```
It runs the following phases: prerequisites, `xcodegen generate`, build, unit tests, network-stubbed tests, StoreKit tests, the CarPlay smoke test, UI tests (XCUITest) and the coverage gate. It exits with 0 only if every phase passes. CI (`.github/workflows/ci.yml`) runs the build plus the unit and UI tests with plain `xcodebuild`; `verify-all.sh` is a superset meant for a Mac, so run it locally before calling work done. Reports are written to `build/reports/`: `summary.txt`, `junit/`, `coverage.txt`, `screenshots/`, `logs/` and `results/*.xcresult`.

## Rule #3 — fix-and-rerun loop
- Read `build/reports/summary.txt`, then the failing phase's `logs/<phase>.log`. Open `results/<phase>.xcresult` in Xcode to see failure screenshots.
- To iterate faster, re-run only the failing phase, for example `Scripts/verify-all.sh --only ui`. Finish with a **full** run.
- **Never disable, skip, delete or weaken a test to get green** (journal D9). Fix the code. If the test itself is wrong, fix the test and give the reason in the commit message and the journal entry. `XCTSkip` and phases that run 0 tests fail the run on purpose.
- Never lower `COVERAGE_MIN` to pass. Add tests instead.
- Keep UI tests deterministic. Don't use `sleep`; use `waitForExistence` or the `waitFor…` helpers in `DashCastUITests/Support/DashCastUITestCase.swift`. Pass the launch arguments `-uiTesting -stubNetwork [-seedDemoData]`. Find elements by accessibility identifier.
- Don't use live network in tests. Use `StubNetwork` (in the app, under `https://stub.dashcast.test`) or a `URLProtocol` stub injected through `URLSession`.

## Project facts
- SwiftUI on iOS 17+, built with Xcode 26. `DashCast.xcodeproj` is **generated** from `project.yml`, so don't commit it.
- Targets: `DashCast` (app), `DashCastTests` (unit tests; hosted by the app), `DashCastUITests` (XCUITest).
- Signing: team `96YG38576A`. Tests always run on the simulator with `CODE_SIGNING_ALLOWED=NO`, and `verify-all.sh` does this for you.
- StoreKit: `DashCast/Resources/DashCastStore.storekit` is used by the scheme's Run action and by `SKTestSession` in the tests.
- Branching: `main` is the integration branch (the classic UI and all merged work live there since 2026-11-07). Work on a short topic branch and open a PR into `main`; merge only with green CI.
- Full Mac instructions: `Docs/MAC_AGENT_HANDOFF.md`.
