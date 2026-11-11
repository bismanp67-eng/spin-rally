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
	# --- physics ---
	var b := P.new()
	b.reset(Vector3(0.2, P.TABLE_Y + P.R + 0.30, 0.6), Vector3.ZERO, Vector3.ZERO)
	var apex := 0.0
	var bounced := false
	for i in 400:
		b.step()
		if b.events.size() > 0:
			bounced = true
		if bounced:
			apex = maxf(apex, b.pos.y - P.TABLE_Y - P.R)
			if b.vel.y < 0.0:
				break
	ok(apex > 0.22 and apex < 0.24, "30 cm drop rebounds to 22-24 cm (got %.3f)" % apex)
	var sh := Shot.new()
	var p0 := Vector3(0.0, P.TABLE_Y + 0.3, 1.5)
	var v0 := Vector3(0.0, 2.2, -9.0)
	var flat := sh.fly(p0, v0, Vector3.ZERO)
	var loop := sh.fly(p0, v0, Shot.spin_vec(Vector3(0, 0, -1), 500.0, 0.0))
	ok(loop.land.z > flat.land.z + 0.3, "topspin loop dips sooner than no-spin (%.2f vs %.2f)" % [loop.land.z, flat.land.z])
	# a swing that is correct for a no-spin ball, used against spin without adjusting ("flat bat")
	var rub := Shot.rubber({speed = 0.55, spin = 0.55})
	var bp := Vector3(0.0, P.TABLE_Y + 0.2, 1.3)
	var bv := Vector3(0.0, -0.4, 4.5)
	var tg := Vector3(0.0, P.TABLE_Y, -0.8)
	var sw := sh.solve_swing(bp, bv, Vector3.ZERO, tg, 4.0, 1.0, 0.0, rub)
	var io: Array = Shot.impact(bv, Vector3.ZERO, sw.vb, sw.n, rub)
	var clean := sh.fly(bp, io[0], io[1])
	ok(sw.ok and clean.ok and (clean.land - tg).length() < 0.1, "swing solver lands a no-spin ball")
	io = Shot.impact(bv, Shot.spin_vec(Vector3(0, 0, 1), -420.0, 0.0), sw.vb, sw.n, rub)
	var back := sh.fly(bp, io[0], io[1])
	ok(not back.ok and (back.net or back.land.z > 0.0), "backspin returned with a flat bat goes into the net")
	io = Shot.impact(bv, Shot.spin_vec(Vector3(0, 0, 1), 420.0, 0.0), sw.vb, sw.n, rub)
	var topr := sh.fly(bp, io[0], io[1])
	ok(not topr.ok and topr.land.z < -P.HALF_L, "topspin returned with a flat bat flies long")
	io = Shot.impact(bv, Vector3(0, 400.0, 0), sw.vb, sw.n, rub)
	var sider := sh.fly(bp, io[0], io[1])
	ok(absf(sider.land.x - clean.land.x) > 0.25, "sidespin pushes a flat return off line (%.2f m)" % absf(sider.land.x - clean.land.x))
	# sidespin serve: curves in the air and kicks sideways off the table
	b.reset(Vector3(0.0, P.TABLE_Y + 0.25, 1.45), Vector3(0.0, -1.2, -5.5), Shot.spin_vec(Vector3(0, 0, -1), 0.0, 350.0))
	var x_bounce := 0.0
	var vx_before := 0.0
	var vx_after := 0.0
	for i in 600:
		var vx := b.vel.x
		b.step()
		if b.events.size() > 0:
			x_bounce = b.pos.x
			vx_before = vx
			vx_after = b.vel.x
			break
	ok(absf(x_bounce) > 0.01 and absf(vx_after - vx_before) > 0.3, "sidespin serve curves (%.3f m) and kicks sideways (%.2f m/s)" % [x_bounce, vx_after - vx_before])
	# no tunnelling at 35 m/s
	var rngt := RandomNumberGenerator.new()
	rngt.seed = 7
	var tunnels := 0
	for i in 300:
		var from := Vector3(rngt.randf_range(-1.0, 1.0), rngt.randf_range(0.8, 2.0), rngt.randf_range(-2.0, 2.0))
		var to := Vector3(rngt.randf_range(-0.8, 0.8), P.TABLE_Y - 0.4 if i % 3 > 0 else P.TABLE_Y + rngt.randf_range(0.0, 0.14), rngt.randf_range(-1.4, 1.4) if i % 3 > 0 else -from.z)
		b.reset(from, (to - from).normalized() * 35.0, Vector3.ZERO)
		for j in 30:
			b.step()
			var inside_table: bool = absf(b.pos.x) < P.HALF_W and absf(b.pos.z) < P.HALF_L and b.pos.y < P.TABLE_Y + P.R - 0.001 and b.pos.y > P.TABLE_Y - P.SLAB - P.R + 0.001
			var inside_net: bool = absf(b.pos.z) < P.R - 0.003 and absf(b.pos.x) < P.HALF_W and b.pos.y < P.TABLE_Y + P.NET_H and b.pos.y > P.TABLE_Y + P.R
			if inside_table or inside_net or b.pos.y < P.R - 0.001:
				tunnels += 1
				break
	ok(tunnels == 0, "no tunnelling at 35 m/s (%d penetrations)" % tunnels)
	b.reset(Vector3(0.0, P.TABLE_Y + 0.08, 1.0), Vector3(0, 0, -35.0), Vector3.ZERO)
	var net_hit := false
	for j in 20:
		b.step()
		for ev in b.events:
			net_hit = net_hit or ev.t == "net"
	ok(net_hit and b.pos.z > 0.0, "35 m/s ball is stopped by the net")
	# --- solver ---
	var p1 := Vector3(0.2, 1.0, 1.5)
	for spec in [[9.0, 300.0, 0.0], [5.0, -280.0, 140.0], [13.0, 100.0, -200.0]]:
		var tg2 := Vector3(-0.4, P.TABLE_Y, -0.9)
		var so := sh.solve(p1, tg2, spec[0], spec[1], spec[2])
		var fl := sh.fly(p1, so.vel, so.spin)
		ok(fl.ok and (fl.land - tg2).length() < 0.08, "solver lands shot %s" % [spec])
	var ss := sh.solve_serve(Vector3(0.0, 1.01, 1.5), Vector3(0.3, P.TABLE_Y, -0.6), 5.5, -200.0, 280.0)
	var fs := sh.fly(Vector3(0.0, 1.01, 1.5), ss.vel, ss.spin, true)
	ok(ss.ok and fs.ok and (fs.land - Vector3(0.3, P.TABLE_Y + P.R, -0.6)).length() < 0.2, "serve solver lands")
	print("TESTS %s (%d failed)" % ["PASSED" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)
