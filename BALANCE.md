# Balance (bot vs bot, same character and bat, games to 11)

v2.1 (geometric bat, serves through bat contact), 120 games per pair:

```
Amateur beats Rookie: 78%  ok  (7.2 shots/pt, 66660 ms)
Club beats Amateur: 80%  ok  (5.7 shots/pt, 66734 ms)
Elite beats Pro: 80%  ok  (4.0 shots/pt, 62977 ms)
Legend beats Elite: 75%  ok  (3.5 shots/pt, 61440 ms)
Pro beats Club: 82%  ok  (4.8 shots/pt, 64837 ms)
```

Target: each level beats the one below 70-85% of the time. Re-run: `godot --headless -s tests/sim.gd -- 200`
