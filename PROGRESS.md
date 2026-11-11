# Progress
- [x] v1.0: M1-M6 (CI APK, core match, 6 difficulties, 12 serves, content, modes, polish, balance)
- [x] v2.0 Checkpoint 1: physics and feel (see CHANGELOG.md)
- [x] v2.0 Checkpoint 2: high-end visuals and quality presets
- [x] v2.0 Checkpoint 3: design system, menus, scoreboard, audio
- [x] v2.0 Checkpoint 4: screenshot review passes, balance re-run (BALANCE.md), docs

## How to verify
- Unit + physics tests: `godot --headless -s tests/run_tests.gd`
- Balance: `godot --headless -s tests/sim.gd -- 200`
- Autoplay smoke test of every mode: `godot --headless --fixed-fps 30 -s tests/smoke.gd`
- Screenshot tour (needs xvfb and a Vulkan driver): see the header of `tests/shots.gd`

## Next
- Play-test on a real phone: swipe thresholds and stroke bands are in `scripts/game/match.gd` (`_update_swipe`, `_player_try_hit`).
- See NOTES.md for known limits.
