extends RefCounted
# Shot solver: finds launch velocities that land the ball on a target, using the real physics.
const P := preload("res://scripts/core/physics.gd")
var s := P.new()
const READ_K := 0.35  # how strongly a poor spin read turns into a wrong bat angle

# Spin for a ball travelling along horizontal unit dir d. top>0 topspin, side about the vertical, cork along travel.
static func spin_vec(d: Vector3, top: float, side: float, cork: float = 0.0) -> Vector3:
	# real sidespin axes are tilted, which is what makes the ball kick sideways off the bounce
	return Vector3.UP.cross(d) * top + Vector3.UP * side + d * (cork - 0.4 * side)

# Fly until the ball reaches table height (serve: the second time). land = point reached.
func fly(p: Vector3, v: Vector3, w: Vector3, serve: bool = false) -> Dictionary:
	s.reset(p, v, w)
	var res := {ok = false, net = false, land = p, first_ok = not serve, t = 0.0}
	var from_side := 0 if p.z > 0.0 else 1
	var need_first := serve
	for i in 900:
		s.step()
		var hit_table := false
		for ev in s.events:
			if ev.t == "table":
				hit_table = true
				if need_first:
					need_first = false
					if ev.side != from_side:
						res.land = ev.pos
						return res
					res.first_ok = true
				else:
					res.land = ev.pos
					res.ok = ev.side != from_side and not res.net
					res.t = i * P.DT
					return res
			elif ev.t == "net" or ev.t == "cord":
				res.net = true
			elif ev.t == "side":
				res.land = ev.pos
				return res
		s.events.clear()
		if not hit_table and s.vel.y < 0.0 and s.pos.y < P.TABLE_Y + P.R:
			res.land = s.pos
			res.t = i * P.DT
			return res
	return res

# Normal stroke: horizontal speed vh, land at target. Slows the ball if it cannot clear the net.
func solve(p: Vector3, target: Vector3, vh: float, top: float, side: float, cork: float = 0.0) -> Dictionary:
	var aim := target
	var out := {vel = Vector3.ZERO, spin = Vector3.ZERO, ok = false}
	for attempt in 9:
		var d := Vector3(aim.x - p.x, 0.0, aim.z - p.z)
		var dist := d.length()
		d /= dist
		var w := spin_vec(d, top, side, cork)
		var t := dist / vh
		var vy := (P.TABLE_Y + P.R - p.y) / t + 0.5 * P.G * t
		var k := 0.8 * vh / P.G
		var r := {}
		var err := 0.0
		var prev_vy := vy
		var prev_err := 0.0
		var have_prev := false
		var net_vy := -INF
		for i in 8:
			r = fly(p, d * vh + Vector3.UP * vy, w)
			if r.net:
				net_vy = maxf(net_vy, vy)
				vy += 0.3
				have_prev = false
				continue
			err = (r.land - p).dot(d) - dist
			if absf(err) < 0.015:
				break
			if have_prev and absf(err - prev_err) > 0.0001:
				k = (err - prev_err) / (vy - prev_vy)
			prev_vy = vy
			prev_err = err
			have_prev = true
			vy -= clampf(err / maxf(k, 0.05), -2.5, 2.5)
			if vy <= net_vy + 0.02:
				r.net = true
				break
		out.vel = d * vh + Vector3.UP * vy
		out.spin = w
		out.ok = not r.net
		if r.net:
			vh *= 0.9
			continue
		var lat: Vector3 = r.land - target
		lat.y = 0.0
		if lat.length() < 0.03:
			out.ok = true
			return out
		aim -= lat * 0.9
	return out

# Serve: bounce on own side first, then land at target.
func solve_serve(p: Vector3, target: Vector3, vh: float, top: float, side: float, cork: float = 0.0) -> Dictionary:
	var out := {vel = Vector3.ZERO, spin = Vector3.ZERO, ok = false}
	var aim := target
	for m in [1.0, 0.85, 1.15, 0.7, 1.3, 0.55]:
		var v: float = vh * m
		var d := Vector3(aim.x - p.x, 0.0, aim.z - p.z)
		var dist := d.length()
		d /= dist
		var w := spin_vec(d, top, side, cork)
		var best_vy := 0.0
		var best := INF
		var best_land := Vector3.ZERO
		for i in 12:
			var vy := -3.2 + i * 0.4
			var r := fly(p, d * v + Vector3.UP * vy, w, true)
			if r.ok and absf((r.land - p).dot(d) - dist) < absf(best):
				best = (r.land - p).dot(d) - dist
				best_vy = vy
				best_land = r.land
		if best == INF:
			continue
		var stepv := 0.2
		for i in 4:
			for vy2 in [best_vy - stepv, best_vy + stepv]:
				var r2 := fly(p, d * v + Vector3.UP * vy2, w, true)
				if r2.ok and absf((r2.land - p).dot(d) - dist) < absf(best):
					best = (r2.land - p).dot(d) - dist
					best_vy = vy2
					best_land = r2.land
			stepv *= 0.5
		out.vel = d * v + Vector3.UP * best_vy
		out.spin = w
		out.ok = true
		var lat := best_land - target
		lat.y = 0.0
		lat -= d * lat.dot(d)
		if lat.length() < 0.04 or aim != target:
			return out
		aim = target - lat
		var d2 := Vector3(aim.x - p.x, 0.0, aim.z - p.z).normalized()
		out.vel = d2 * v + Vector3.UP * best_vy
		out.spin = spin_vec(d2, top, side, cork)
		return out
	# no legal serve found (over-hit): send it anyway, it will be a fault
	var df := Vector3(target.x - p.x, 0.0, target.z - p.z).normalized()
	out.vel = df * vh * 1.2 + Vector3.UP * 0.4
	out.spin = spin_vec(df, top, side, cork)
	return out

# Rubber properties from a bat's 0..1 stats.
static func rubber(bat: Dictionary) -> Dictionary:
	return {e = 0.66 + 0.22 * bat.speed, ct = 0.30 + 0.34 * bat.spin, mu = 0.35 + 0.75 * bat.spin}

# Bat-ball contact impulse. v, w: ball velocity and spin before contact. vb: bat velocity.
# n: unit normal of the bat face (pointing where the face looks). off: 0 sweet spot .. 1 edge.
# Returns [velocity, spin] after contact.
static func impact(v: Vector3, w: Vector3, vb: Vector3, n: Vector3, rub: Dictionary, off: float = 0.0) -> Array:
	var u := v - vb
	var un := minf(u.dot(n), -0.05)
	var e: float = maxf(rub.e - 0.006 * absf(un), 0.4) * (1.0 - 0.45 * off * off)
	var ut := u - n * u.dot(n)
	var slip := ut - w.cross(n) * P.R
	var dvt: Vector3 = -slip * rub.ct
	var lim: float = rub.mu * (1.0 + e) * absf(un)
	if dvt.length() > lim:
		dvt = dvt.normalized() * lim
	return [vb + ut + dvt - n * (e * un), w - n.cross(dvt) * (1.5 / P.R)]

# Contact at a point on the blade: off = 0 centre .. 1 rim, radial = unit vector from the blade centre
# to the contact point. Off-centre hits are weaker and the rim deflects the ball outward.
static func impact_at(v: Vector3, w: Vector3, vb: Vector3, n: Vector3, rub: Dictionary, off: float, radial: Vector3) -> Array:
	return impact(v, w, vb, (n + radial * (0.4 * off * off * off)).normalized(), rub, off)

# Find the bat face angle (and, if needed, a different swing speed) that lands the ball on target.
# a: bat speed along the face normal, b_up / b_side: brushing speed across the face (m/s).
# w_seen is the incoming spin as the hitter perceives it.
func solve_swing(p: Vector3, v_in: Vector3, w_seen: Vector3, target: Vector3, a: float, b_up: float, b_side: float, rub: Dictionary) -> Dictionary:
	var aim := target
	var out := {n = Vector3.FORWARD, vb = Vector3.ZERO, ok = false}
	var th := 0.15
	var step := 0.12
	for attempt in 12:
		var d := Vector3(aim.x - p.x, 0.0, aim.z - p.z)
		var dist := d.length()
		d /= dist
		var right := d.cross(Vector3.UP)
		# bracket the face angle between "short / into the net" (lo) and "long" (hi), then close in
		var lo := -9.0
		var hi := 9.0
		var elo := -1.0
		var ehi := 1.0
		var lo_net := false
		var fail := 0  # 1 = too fast to land, 2 = too slow to reach
		var r := {}
		var n := d
		var vb := d
		for i in 18:
			n = d * cos(th) + Vector3.UP * sin(th)
			vb = n * a + (Vector3.UP * cos(th) - d * sin(th)) * b_up + right * b_side
			var io := impact(v_in, w_seen, vb, n, rub)
			r = fly(p, io[0], io[1])
			var err: float = (r.land - p).dot(d) - dist
			if r.net or err < 0.0:
				lo = th
				lo_net = r.net
				elo = minf(err, -0.02)
			else:
				hi = th
				ehi = maxf(err, 0.02)
			if not r.net and absf(err) < 0.012:
				break
			if lo > -9.0 and hi < 9.0:
				if hi - lo < 0.0012:
					if lo_net:
						fail = 1
					else:
						th = hi
					break
				th = (lo + hi) * 0.5 if lo_net else lo + (hi - lo) * clampf(-elo / (ehi - elo), 0.12, 0.88)
			elif hi >= 9.0:
				th += step
				step *= 1.6
				if th > 1.15:
					fail = 2
					break
			else:
				th -= step
				step *= 1.6
				if th < -0.9:
					fail = 1
					break
		out.n = n
		out.vb = vb
		step = 0.03
		if fail == 1:
			a *= 0.86
			b_up *= 0.96
			th = clampf(th, -0.3, 0.6)
			step = 0.08
			continue
		if fail == 2:
			a = a * 1.2 + 0.6
			th = 0.3
			step = 0.1
			continue
		var lat: Vector3 = r.land - target
		lat.y = 0.0
		lat -= d * lat.dot(d)
		out.ok = r.ok
		if lat.length() < 0.025:
			return out
		aim -= lat * 0.95
	return out

# Full stroke with human error. o: {p, v_in, w_in, target, a, b_up, b_side, rub, read, err, gross, off}
# read 0..1 = how well incoming spin is judged, err = aim noise (m), gross = chance of a mishit,
# off = contact distance from the sweet spot (0..1). Returns {vel, spin, n, vb}.
func strike(o: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var tgt: Vector3 = o.target
	var e: float = o.get("err", 0.0)
	tgt.x += rng.randfn(0.0, e)
	tgt.z += rng.randfn(0.0, e * 1.3)
	var w_in: Vector3 = o.get("w_in", Vector3.ZERO)
	var miss: float = (1.0 - o.get("read", 1.0)) * rng.randf_range(0.35, 1.0) * READ_K
	var sw := solve_swing(o.p, o.v_in, w_in * (1.0 - miss), tgt, o.a, o.b_up, o.get("b_side", 0.0), o.rub)
	var n: Vector3 = sw.n
	if rng.randf() < o.get("gross", 0.0):
		var axis := n.cross(Vector3.UP).normalized()
		n = n.rotated(axis, rng.randf_range(0.07, 0.2) * (1.0 if rng.randf() < 0.5 else -1.0))
	var io := impact_at(o.v_in, w_in, sw.vb, n, o.rub, o.get("off", 0.0), o.get("radial", Vector3.ZERO))
	return {vel = io[0], spin = io[1], n = n, vb = sw.vb}
