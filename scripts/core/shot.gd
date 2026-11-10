extends RefCounted
# Shot solver: finds launch velocities that land the ball on a target, using the real physics.
const P := preload("res://scripts/core/physics.gd")
var s := P.new()

# Spin for a ball travelling along horizontal unit dir d. top>0 topspin, side about the vertical, cork along travel.
static func spin_vec(d: Vector3, top: float, side: float, cork: float = 0.0) -> Vector3:
	return Vector3.UP.cross(d) * top + Vector3.UP * side + d * cork

# Fly until the ball reaches table height (serve: the second time). land = point reached.
func fly(p: Vector3, v: Vector3, w: Vector3, serve: bool = false) -> Dictionary:
	s.pos = p
	s.vel = v
	s.spin = w
	s.events.clear()
	var res := {ok = false, net = false, land = p, first_ok = not serve, t = 0.0}
	var from_side := 0 if p.z > 0.0 else 1
	var need_first := serve
	for i in 420:
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

# Full stroke with human error. o: {p, target, vh, top, side, cork, v_in, w_in, read, err, gross}
# read 0..1 = how well incoming spin is compensated, err = aim noise (m), gross = chance of a bad miss.
func strike(o: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var p: Vector3 = o.p
	var tgt: Vector3 = o.target
	var e: float = o.get("err", 0.0)
	tgt.x += rng.randfn(0.0, e)
	tgt.z += rng.randfn(0.0, e * 1.3)
	var r := solve(p, tgt, o.vh, o.top, o.get("side", 0.0), o.get("cork", 0.0))
	var v: Vector3 = r.vel
	var w_in: Vector3 = o.get("w_in", Vector3.ZERO)
	var v_in: Vector3 = o.get("v_in", Vector3.ZERO)
	var d_in := Vector3(v_in.x, 0.0, v_in.z)
	if d_in.length() > 0.1 and w_in.length() > 1.0:
		d_in = d_in.normalized()
		var miss: float = (1.0 - o.get("read", 1.0)) * rng.randf_range(0.35, 1.0)
		var top_in := w_in.dot(Vector3.UP.cross(d_in))
		v.y += top_in * 0.011 * miss
		v = v.rotated(Vector3.UP, -w_in.y * 0.0022 * miss * signf(v.z))
	if rng.randf() < o.get("gross", 0.0):
		v.y += rng.randf_range(0.5, 1.4) * (1.0 if rng.randf() < 0.5 else -1.0)
	return {vel = v, spin = r.spin}
