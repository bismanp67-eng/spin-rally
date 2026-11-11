extends RefCounted
# Table tennis ball simulation in SI units. Custom integrator, no engine rigid bodies.
# Table centre is the origin. +z is side 0 (player), -z is side 1 (opponent).
# Forces: gravity, quadratic drag (rho 1.2, Cd 0.45), Magnus lift with a spin-ratio lift coefficient.
# Collisions: swept sphere against the table slab, net, posts and floor, with true contact normals,
# restitution and Coulomb friction (slip or roll), so spin changes the bounce and the bounce changes spin.
const G := 9.81
const R := 0.02
const MASS := 0.0027
const TABLE_Y := 0.76
const HALF_L := 1.37
const HALF_W := 0.7625
const NET_H := 0.1525
const NET_OVER := 0.1525
const SLAB := 0.03
const KD := 0.1257  # 0.5 * rho * Cd * A / m
const KL := 0.2793  # 0.5 * rho * A / m
const DT := 1.0 / 240.0
enum {K_FLOOR, K_TABLE, K_NET, K_POST}
const T_MIN := Vector3(-HALF_W, TABLE_Y - SLAB, -HALF_L)
const T_MAX := Vector3(HALF_W, TABLE_Y, HALF_L)
const N_MIN := Vector3(-HALF_W - NET_OVER, TABLE_Y, -0.002)
const N_MAX := Vector3(HALF_W + NET_OVER, TABLE_Y + NET_H, 0.002)
const P_SIZE := Vector3(0.012, 0.0, 0.012)

var pos := Vector3.ZERO
var prev_pos := Vector3.ZERO
var vel := Vector3.ZERO
var spin := Vector3.ZERO  # angular velocity, rad/s
var e_table := 0.9
var mu_table := 0.25
var events: Array = []  # {t = "table"|"side"|"net"|"cord"|"floor", side, pos, edge}
var tick := 0
var last_contact := -999
var h_t := 2.0
var h_n := Vector3.UP
var h_q := Vector3.ZERO
var h_kind := 0

func reset(p: Vector3, v: Vector3, w: Vector3) -> void:
	pos = p
	prev_pos = p
	vel = v
	spin = w
	events.clear()
	last_contact = -999

func step(dt: float = DT) -> void:
	tick += 1
	var sp := vel.length()
	var acc := Vector3(0.0, -G, 0.0) - vel * (KD * sp)
	var wl := spin.length()
	if wl > 1.0 and sp > 0.05:
		# lift coefficient CL = 1 / (2 + v / (r w)), direction w x v
		acc += spin.cross(vel) * (KL * R * sp / (2.0 * R * wl + sp))
	vel += acc * dt
	spin *= 1.0 - 0.06 * dt
	prev_pos = pos
	var p := pos
	var d := vel * dt
	var left := 1.0
	for iter in 3:
		h_t = 2.0
		if d.y < 0.0 and p.y + d.y < R:
			h_t = clampf((R - p.y) / d.y, 0.0, 1.0)
			h_n = Vector3.UP
			h_kind = K_FLOOR
		if minf(p.y, p.y + d.y) < TABLE_Y + NET_H + R + 0.012:
			_box(p, d, T_MIN, T_MAX, K_TABLE)
			if minf(absf(p.z), absf(p.z + d.z)) < 0.04 or (p.z > 0.0) != (p.z + d.z > 0.0):
				_box(p, d, N_MIN, N_MAX, K_NET)
				for sx in [-1.0, 1.0]:
					var c := Vector3(sx * (HALF_W + NET_OVER), TABLE_Y - 0.05, 0.0)
					_box(p, d, c - P_SIZE, c + P_SIZE + Vector3(0.0, NET_H + 0.06, 0.0), K_POST)
		if h_t > 1.0:
			p += d
			break
		p += d * h_t + h_n * 0.0002
		pos = p
		_resolve()
		left *= 1.0 - h_t
		d = vel * dt * left
	pos = p

# Swept sphere against an axis-aligned box. Records the earliest hit in h_*.
func _box(p0: Vector3, d: Vector3, bmin: Vector3, bmax: Vector3, kind: int) -> void:
	var t0 := 0.0
	var t1 := 1.0
	for a in 3:
		var lo := bmin[a] - R
		var hi := bmax[a] + R
		var o := p0[a]
		var dd := d[a]
		if absf(dd) < 0.0000001:
			if o < lo or o > hi:
				return
		else:
			var ta := (lo - o) / dd
			var tb := (hi - o) / dd
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				return
	if t0 >= h_t:
		return
	var t := t0
	var c := p0 + d * t
	var q := c.clamp(bmin, bmax)
	var rr := R * R
	if c.distance_squared_to(q) > rr * 1.001:
		# rounded edge/corner region: march to the true first touch
		var found := false
		var lo2 := t0
		for i in range(1, 9):
			var tt := lerpf(t0, t1, i / 8.0)
			c = p0 + d * tt
			if c.distance_squared_to(c.clamp(bmin, bmax)) <= rr:
				var hi2 := tt
				for k in 5:
					var mid := (lo2 + hi2) * 0.5
					var cm := p0 + d * mid
					if cm.distance_squared_to(cm.clamp(bmin, bmax)) <= rr:
						hi2 = mid
					else:
						lo2 = mid
				t = hi2
				found = true
				break
			lo2 = tt
		if not found or t >= h_t:
			return
		c = p0 + d * t
		q = c.clamp(bmin, bmax)
	var n := c - q
	var nl := n.length()
	if nl < 0.000001:
		n = -d.normalized()
	else:
		n /= nl
	if d.dot(n) >= 0.0:
		return
	h_t = t
	h_n = n
	h_q = q
	h_kind = kind

func _resolve() -> void:
	var vn := -vel.dot(h_n)
	var fresh := vn > 0.3 or tick - last_contact > 30
	last_contact = tick
	var side := 0 if pos.z > 0.0 else 1
	match h_kind:
		K_TABLE:
			var top := h_n.y > 0.5
			var edge := top and h_n.y < 0.9995
			_bounce(h_n, clampf(e_table - 0.01 * vn, 0.5, 0.95) * (0.8 if edge else 1.0) if vn > 0.2 else 0.0, mu_table)
			if fresh:
				events.append({t = "table" if top else "side", side = side, pos = pos, edge = edge})
		K_NET:
			var cord := h_q.y > TABLE_Y + NET_H - 0.002 and h_n.y > 0.25
			_bounce(h_n, 0.45 if cord else 0.2, 0.3)
			if not cord:
				vel *= 0.55
				spin *= 0.5
			if fresh:
				events.append({t = "cord" if cord else "net", side = side, pos = pos})
		K_POST:
			_bounce(h_n, 0.6, 0.3)
			if fresh:
				events.append({t = "net", side = side, pos = pos})
		K_FLOOR:
			_bounce(h_n, 0.75 if vn > 0.3 else 0.0, 0.4)
			if fresh:
				events.append({t = "floor", side = side, pos = pos})

# Contact impulse on a hollow sphere (I = 2/3 m r^2): restitution along n, Coulomb friction that
# either slides (mu-limited) or grips into rolling. Updates both velocity and spin.
func _bounce(n: Vector3, e: float, mu: float) -> void:
	var vn := vel.dot(n)
	if vn >= 0.0:
		return
	var jn := -(1.0 + e) * vn
	var s := vel - n * vn - spin.cross(n) * R
	var sl := s.length()
	if sl > 0.00001:
		var dv := minf(mu * jn, 0.4 * sl)
		var ch := s / sl
		vel -= ch * dv
		spin += n.cross(ch) * (1.5 * dv / R)
	vel += n * jn
