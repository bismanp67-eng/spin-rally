extends RefCounted
# Bot brain. Works for either side; used by the game and the headless simulation.
const P := preload("res://scripts/core/physics.gd")
const Bat := preload("res://scripts/core/bat.gd")
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
var rub := {}

func setup(side_: int, lvl_: Dictionary, def: Dictionary, bat_: Dictionary, all_serves: Array, rng_: RandomNumberGenerator, solver_) -> void:
	side = side_
	sgn = 1.0 if side == 0 else -1.0
	lvl = lvl_
	st = def.st
	bat = bat_
	hand = -1.0 if def.hand == "L" else 1.0
	rng = rng_
	solver = solver_
	rub = solver.rubber(bat_)
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
	s.reset(p, v, w)
	var mine := false
	for i in 600:
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
	# geometric bat: the arm puts the blade as close to the ball as it can reach, then swings through it
	var n0 := Vector3(0.0, 0.0, -sgn)
	var c0 := Vector3(clampf(bp.x, x - REACH, x + REACH) + signf(x - bp.x) * minf(off / REACH, 1.0) * 0.6 * Bat.BLADE_R, bp.y, bp.z) - n0 * 0.04
	var hit := Bat.sweep(bp - bv * dt, bv * dt, c0, n0 * 0.06, n0, Bat.BLADE_R)
	if hit.is_empty():
		return {miss = true}
	var d_in := Vector3(bv.x, 0.0, bv.z).normalized()
	var top_in := bw.dot(Vector3.UP.cross(d_in))
	var h := bp.y - P.TABLE_Y
	var sp_in := bv.length()
	var stretch := off / REACH
	var ag := clampf(lvl.aggression * st.aggr, 0.0, 1.0)
	var k: float = lvl.spin * st.spin
	var bc: float = 1.3 - 0.6 * bat.control
	var pw: float = lvl.power * st.power
	# stroke = bat speed into the ball (a) and brushing speed up the face (b)
	var a := 3.6 * pw
	var b := 3.0 * k
	var depth := 0.7
	var r := rng.randf()
	if h > 0.32 and r < 0.45 + ag * 0.5:
		last_kind = "smash"
		a = 13.0 * pw
		b = 1.5
		depth = 0.75
	elif top_in < -90.0 and r >= ag * 0.8:
		last_kind = "push"
		a = 1.6
		b = -4.0 * k
		depth = 0.6
	elif top_in < -90.0:
		last_kind = "loop"
		a = 4.2 * pw
		b = 10.5 * k
		depth = 0.8
	elif r < st.chop:
		last_kind = "chop"
		a = 3.2
		b = -8.0 * k
		depth = 0.75
	elif r < st.chop + ag:
		last_kind = "drive"
		a = 5.6 * pw
		b = 5.0 * k
		depth = 0.78
	elif r < st.chop + ag + st.block * 0.5:
		last_kind = "block"
		a = 0.8
		b = 0.5
		depth = 0.6
	else:
		last_kind = "rally"
	if h < 0.07 and bp.z * sgn < P.HALF_L:
		a = minf(a, 2.6)
	var wmax: float = P.HALF_W * (0.45 + 0.45 * lvl.aim)
	var tx := rng.randf_range(-wmax, wmax) * 0.7
	if rng.randf() < lvl.aim:
		var away := -signf(opp_x) if absf(opp_x) > 0.1 else (1.0 if rng.randf() < 0.5 else -1.0)
		tx = away * wmax * rng.randf_range(0.6, 1.0)
	var tz: float = -sgn * lerpf(0.5, 1.15, depth * (0.75 + 0.25 * lvl.aim))
	var sh: Dictionary = solver.strike({
		p = bp, v_in = bv, w_in = bw, target = Vector3(tx, P.TABLE_Y, tz), a = a, b_up = b,
		b_side = st.side * 4.0 * lvl.spin * rng.randf_range(-1.0, 1.0), rub = rub,
		read = minf(lvl.spin_read + st.get("read", 0.0), 0.99), off = hit.off, radial = hit.radial,
		err = lvl.place_err * bc * (0.6 + sp_in / 14.0 + stretch * 0.7 + a / 12.0),
		gross = lvl.mistake * (0.5 + sp_in / 10.0 + stretch),
	}, rng)
	sh.kind = last_kind
	return sh

# Returns the serve as a real swing: {p, n, vb, serve, v_toss}. The caller tosses the ball and applies the contact.
func serve() -> Dictionary:
	var sv: Dictionary = pool[rng.randi() % pool.size()]
	x = rng.randf_range(-0.35, 0.35)
	goal_x = x * 0.5
	done = true
	var depth := clampf(sv.depth + rng.randf_range(-0.2, 0.2), 0.0, 1.0)
	var tgt := Vector3(rng.randf_range(-0.75, 0.75) * P.HALF_W + rng.randfn(0.0, lvl.place_err * 0.6), P.TABLE_Y,
		-sgn * (lerpf(0.4, 1.2, depth) + rng.randfn(0.0, lvl.place_err * 0.6)))
	var p := Vector3(x, P.TABLE_Y + 0.25, sgn * (P.HALF_L + 0.12))
	var k: float = lvl.spin * st.spin
	var v_toss := sqrt(2.0 * P.G * sv.toss)
	var r: Dictionary = solver.solve_serve_swing(p, v_toss, tgt, sv.bat[0] * lerpf(0.8, 1.15, depth), sv.bat[1] * k, sv.bat[2] * k * hand, rub)
	var n: Vector3 = r.n
	if rng.randf() < lvl.serve_fault:
		n = n.rotated(n.cross(Vector3.UP).normalized(), rng.randf_range(0.12, 0.25) * (1.0 if rng.randf() < 0.5 else -1.0))
	return {p = p, n = n, vb = r.vb, serve = sv, v_toss = v_toss}
