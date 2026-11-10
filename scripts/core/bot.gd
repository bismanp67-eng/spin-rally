extends RefCounted
# Bot brain. Works for either side; used by the game and the headless simulation.
const P := preload("res://scripts/core/physics.gd")
const REACH := 0.42
var side := 1
var sgn := -1.0
var lvl: Dictionary
var st: Dictionary
var bat: Dictionary
var hand := 1.0
var pool: Array = []
var rng: RandomNumberGenerator
var solver
var x := 0.0
var goal_x := 0.0
var react := 0.0
var done := true
var last_kind := ""

func setup(side_: int, lvl_: Dictionary, def: Dictionary, bat_: Dictionary, all_serves: Array, rng_: RandomNumberGenerator, solver_) -> void:
	side = side_
	sgn = 1.0 if side == 0 else -1.0
	lvl = lvl_
	st = def.st
	bat = bat_
	hand = -1.0 if def.hand == "L" else 1.0
	rng = rng_
	solver = solver_
	var ordered: Array = []
	for id in def.fav:
		for sv in all_serves:
			if sv.id == id:
				ordered.append(sv)
	for sv in all_serves:
		if not ordered.has(sv):
			ordered.append(sv)
	pool = ordered.slice(0, int(lvl.serves))

func ready_to_hit(bp: Vector3, bv: Vector3) -> bool:
	return bp.z * sgn > P.HALF_L + st.standoff or (bv.y < 0.0 and bp.y < P.TABLE_Y + 0.13)

# The opponent just struck the ball: decide where to move.
func on_incoming(p: Vector3, v: Vector3, w: Vector3, is_serve: bool) -> void:
	done = false
	react = lvl.reaction * (1.3 if is_serve else 1.0)
	var s: RefCounted = solver.s
	s.pos = p
	s.vel = v
	s.spin = w
	s.events.clear()
	var mine := false
	for i in 300:
		s.step()
		for ev in s.events:
			if ev.t == "table" and ev.side == side:
				mine = true
			elif ev.t == "floor":
				s.events.clear()
				return
		s.events.clear()
		if mine and ready_to_hit(s.pos, s.vel):
			goal_x = s.pos.x + rng.randfn(0.0, lvl.pos_err * (1.0 + v.length() / 12.0))
			return

# Call every physics tick. Returns {} or a stroke {vel, spin, kind} or {miss = true}.
func tick(dt: float, bp: Vector3, bv: Vector3, bw: Vector3, incoming: bool, opp_x: float) -> Dictionary:
	if react > 0.0:
		react -= dt
	else:
		x = move_toward(x, goal_x, lvl.speed * dt)
	if done or not incoming or not ready_to_hit(bp, bv):
		return {}
	done = true
	var off := absf(bp.x - x)
	goal_x = x * 0.3
	if off > REACH:
		return {miss = true}
	var d_in := Vector3(bv.x, 0.0, bv.z).normalized()
	var top_in := bw.dot(Vector3.UP.cross(d_in))
	var h := bp.y - P.TABLE_Y
	var sp_in := bv.length()
	var stretch := off / REACH
	var a := clampf(lvl.aggression * st.aggr, 0.0, 1.0)
	var bs: float = 0.85 + 0.3 * bat.speed
	var bsp: float = (0.8 + 0.4 * bat.spin) * lvl.spin * st.spin
	var bc: float = 1.3 - 0.6 * bat.control
	var pw: float = lvl.power * st.power * bs
	var vh := 8.0
	var top := 55.0
	var depth := 0.7
	var r := rng.randf()
	if h > 0.32 and r < 0.45 + a * 0.5:
		last_kind = "smash"
		vh = 15.0 * pw
		top = 25.0
		depth = 0.75
	elif top_in < -30.0 and r >= a * 0.8:
		last_kind = "push"
		vh = 4.6
		top = -70.0 * bsp
		depth = 0.6
	elif top_in < -30.0:
		last_kind = "loop"
		vh = 8.5 * pw
		top = 115.0 * bsp
		depth = 0.8
	elif r < st.chop:
		last_kind = "chop"
		vh = 7.0
		top = -95.0 * bsp
		depth = 0.75
	elif r < st.chop + a:
		last_kind = "drive"
		vh = 11.0 * pw
		top = 90.0 * bsp
		depth = 0.85
	elif r < st.chop + a + st.block * 0.5:
		last_kind = "block"
		vh = 6.5
		top = 15.0
		depth = 0.6
	else:
		last_kind = "rally"
		vh = 8.0 * pw
		top = 55.0 * bsp
	if h < 0.07 and bp.z * sgn < P.HALF_L:
		vh = minf(vh, 6.5)
	var wmax: float = P.HALF_W * (0.45 + 0.45 * lvl.aim)
	var tx := rng.randf_range(-wmax, wmax) * 0.7
	if rng.randf() < lvl.aim:
		var away := -signf(opp_x) if absf(opp_x) > 0.1 else (1.0 if rng.randf() < 0.5 else -1.0)
		tx = away * wmax * rng.randf_range(0.6, 1.0)
	var tz: float = -sgn * lerpf(0.5, 1.15, depth * (0.75 + 0.25 * lvl.aim))
	var sh: Dictionary = solver.strike({
		p = bp, target = Vector3(tx, P.TABLE_Y, tz), vh = vh, top = top,
		side = st.side * 70.0 * lvl.spin * rng.randf_range(-1.0, 1.0),
		v_in = bv, w_in = bw, read = minf(lvl.spin_read + st.get("read", 0.0), 0.99),
		err = lvl.place_err * bc * (0.6 + sp_in / 14.0 + stretch * 0.7 + vh / 22.0),
		gross = lvl.mistake * (0.5 + sp_in / 10.0 + stretch),
	}, rng)
	sh.kind = last_kind
	return sh

# Returns {p, vel, spin, serve}.
func serve() -> Dictionary:
	var sv: Dictionary = pool[rng.randi() % pool.size()]
	x = rng.randf_range(-0.35, 0.35)
	goal_x = x * 0.5
	done = true
	var depth := clampf(sv.depth + rng.randf_range(-0.2, 0.2), 0.0, 1.0)
	var tgt := Vector3(rng.randf_range(-0.75, 0.75) * P.HALF_W + rng.randfn(0.0, lvl.place_err * 0.6), P.TABLE_Y,
		-sgn * (lerpf(0.4, 1.2, depth) + rng.randfn(0.0, lvl.place_err * 0.6)))
	var p := Vector3(x, P.TABLE_Y + 0.25, sgn * (P.HALF_L + 0.12))
	var k: float = lvl.spin * st.spin * (0.8 + 0.4 * bat.spin)
	var r: Dictionary = solver.solve_serve(p, tgt, sv.speed * lerpf(0.8, 1.1, depth), sv.top * k, sv.side * k * hand, sv.cork * k)
	if rng.randf() < lvl.serve_fault:
		r.vel.y += rng.randf_range(0.7, 1.3) * (1.0 if rng.randf() < 0.5 else -1.0)
	return {p = p, vel = r.vel, spin = r.spin, serve = sv}
