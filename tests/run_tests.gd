extends SceneTree
# Unit tests: godot --headless -s tests/run_tests.gd
const Rules := preload("res://scripts/core/rules.gd")
const Rally := preload("res://scripts/core/rally.gd")
const Shot := preload("res://scripts/core/shot.gd")
const P := preload("res://scripts/core/physics.gd")
var fails := 0

func ok(c: bool, name: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", name)

func tb(side: int) -> Dictionary:
	return {t = "table", side = side}

func _init() -> void:
	# --- scoring ---
	var r := Rules.new()
	r.setup(3, 0)
	var seq := []
	for i in 6:
		seq.append(r.server())
		r.add_point(0)
	ok(seq == [0, 0, 1, 1, 0, 0], "serve switches every 2 points")
	r.setup(3, 0)
	for i in 10:
		r.add_point(0)
		r.add_point(1)
	ok(r.points == [10, 10], "10-10 reached without game end")
	var s1 := r.server()
	r.add_point(0)
	ok(r.server() != s1, "serve alternates every point at deuce")
	ok(r.game_point() == 0, "game point detected")
	ok(r.add_point(1) == "", "11-11 continues")
	r.add_point(1)
	ok(r.add_point(1) == "game", "win by two")
	ok(r.games == [0, 1] and r.points == [0, 0], "game recorded")
	ok(r.server() == 1, "first server alternates each game")
	for i in 10:
		r.add_point(1)
	ok(r.match_point() == 1, "match point detected")
	ok(r.add_point(1) == "match", "best of 3 ends at 2 games")
	r.setup(1, 1)
	for i in 10:
		r.add_point(0)
	ok(r.add_point(0) == "match", "best of 1")
	# --- rally / serve rules ---
	var y := Rally.new()
	y.start(0)
	y.on_hit(0)
	ok(y.on_event(tb(0)).is_empty() and y.on_event(tb(1)).is_empty(), "legal serve")
	ok(y.on_event(tb(1)).get("winner", -1) == 0, "double bounce = ace for server")
	y.start(0)
	y.on_hit(0)
	ok(y.on_event(tb(1)).get("winner", -1) == 1, "serve must bounce on own side first")
	y.start(0)
	y.on_hit(0)
	y.on_event(tb(0))
	y.on_event({t = "cord"})
	ok(y.on_event(tb(1)).has("let"), "net serve that lands is a let")
	y.start(0)
	y.on_hit(0)
	y.on_event(tb(0))
	y.on_event({t = "net"})
	ok(y.on_event(tb(0)).get("winner", -1) == 1, "serve into net is a fault")
	y.start(1)
	y.on_hit(1)
	y.on_event(tb(1))
	ok(y.on_hit(0).get("reason", "") == "volley", "volley is a fault")
	y.start(0)
	y.on_hit(0)
	y.on_event(tb(0))
	y.on_event(tb(1))
	y.on_hit(1)
	ok(y.on_event({t = "floor"}).get("winner", -1) == 0, "missing the table loses the point")
	y.start(0)
	y.on_hit(0)
	y.on_event(tb(0))
	y.on_event(tb(1))
	y.on_hit(1)
	y.on_event({t = "cord"})
	ok(y.on_event(tb(0)).is_empty(), "net cord in a rally plays on")
	ok(y.on_event({t = "floor"}).get("winner", -1) == 1, "unreturned ball wins the point")
	# --- solver ---
	var sh := Shot.new()
	var p0 := Vector3(0.2, 1.0, 1.5)
	for spec in [[9.0, 80.0, 0.0], [5.0, -80.0, 40.0], [13.0, 30.0, -60.0]]:
		var tg := Vector3(-0.4, P.TABLE_Y, -0.9)
		var so := sh.solve(p0, tg, spec[0], spec[1], spec[2])
		var fl := sh.fly(p0, so.vel, so.spin)
		ok(fl.ok and (fl.land - tg).length() < 0.08, "solver lands shot %s" % [spec])
	var ss := sh.solve_serve(Vector3(0.0, 1.01, 1.5), Vector3(0.3, P.TABLE_Y, -0.6), 5.5, -60.0, 80.0)
	var fs := sh.fly(Vector3(0.0, 1.01, 1.5), ss.vel, ss.spin, true)
	ok(ss.ok and fs.ok and (fs.land - Vector3(0.3, P.TABLE_Y + P.R, -0.6)).length() < 0.2, "serve solver lands")
	print("TESTS %s (%d failed)" % ["PASSED" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
