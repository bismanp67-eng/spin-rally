extends SceneTree
# Balance simulation: godot --headless -s tests/sim.gd -- [games_per_pair] [only_pair 1..5]
# Each level plays the level below with the same neutral character and bat.
const Sim := preload("res://scripts/core/simmatch.gd")
const DBS := preload("res://scripts/core/db.gd")

func _init() -> void:
	var n := 60
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	var levels := DBS.load_json("levels")
	var def: Dictionary = DBS.find(DBS.load_json("bots"), "tomasz")
	var bat: Dictionary = DBS.find(DBS.load_json("bats"), "allround_classic")
	var serves := DBS.load_json("serves")
	var all_ok := true
	var only := int(args[1]) if args.size() > 1 else 0
	for i in range(1, levels.size()):
		if only > 0 and i != only:
			continue
		var sim := Sim.new()
		var wins := 0
		var t0 := Time.get_ticks_msec()
		for g in n:
			var hi_side := g % 2
			var lv := [levels[i - 1], levels[i - 1]]
			lv[hi_side] = levels[i]
			sim.setup([def, def], lv, [bat, bat], serves, 1000 * i + g)
			if sim.play_match(1) == hi_side:
				wins += 1
		var pct := 100.0 * wins / n
		var good := pct >= 70.0 and pct <= 85.0
		all_ok = all_ok and good
		print("%s beats %s: %.0f%%  %s  (%.1f shots/pt, %d ms)" % [levels[i].name, levels[i - 1].name, pct,
			"ok" if good else "OUT OF RANGE", float(sim.shots) / maxi(sim.points, 1), Time.get_ticks_msec() - t0])
	print("BALANCE ", "OK" if all_ok else "NEEDS TUNING")
	quit()
