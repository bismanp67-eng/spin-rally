# Progress
- [x] M1 CI builds a debug APK (artifact `SpinRally-apk`) with the menu
- [x] M2 Core match: physics, swipe controls, scoring, one bot
- [x] M3 6 difficulties, 12 serves with radial menu
- [x] M4 Content (25 bats, 12 tables, 10 arenas, 8 balls, 15 bots) and modes (quick, tournament, ladder, practice, serve practice, 20 challenges, stats)
- [x] M5 Polish: camera, replay, particles, vibration, synthesized sound/music/crowd, settings, tutorial
- [x] M6 Bot balance via headless sim (all adjacent levels 70-85%)

## How to verify
- Unit tests: `godot --headless -s tests/run_tests.gd`
- Balance: `godot --headless -s tests/sim.gd -- 300`
- Autoplay smoke test of every mode: `godot --headless --fixed-fps 30 -s tests/smoke.gd`

## Next (nothing blocking)
- Play-test on a real phone and tune swipe feel (thresholds in `scripts/game/match.gd`: `_update_swipe`, `_swipe_params`, `P_ERR`).
- See NOTES.md for known limits.
