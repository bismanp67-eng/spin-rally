extends RefCounted
# Ball physics: gravity, drag, Magnus, spin-aware bounces, net, edges.
# Table centre is the origin. +z is side 0 (player), -z is side 1 (opponent).
const G := 9.81
const R := 0.02
const TABLE_Y := 0.76
const HALF_L := 1.37
const HALF_W := 0.7625
const NET_H := 0.1525
const NET_OVER := 0.1525
const KD := 0.11
const KM := 0.0075
const DT := 1.0 / 120.0

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var spin := Vector3.ZERO
var e_table := 0.9
var mu_table := 0.25
var events: Array = []  # {t = "table"|"net"|"cord"|"floor", side, pos, edge}

func step(dt: float = DT) -> void:
	var sp := vel.length()
	vel += (Vector3(0.0, -G, 0.0) - vel * (KD * sp) + spin.cross(vel) * KM) * dt
	var prev := pos
	pos += vel * dt
	spin *= 1.0 - 0.03 * dt
	# net
	if (prev.z > 0.0) != (pos.z > 0.0):
		var f := prev.z / (prev.z - pos.z)
		var y := lerpf(prev.y, pos.y, f)
		var x := lerpf(prev.x, pos.x, f)
		var top := TABLE_Y + NET_H
		if absf(x) < HALF_W + NET_OVER and y < top + R * 0.8 and y > TABLE_Y - 0.01:
			if y > top - R * 0.6:
				# net cord: clips the tape and dribbles over
				vel = Vector3(vel.x * 0.6, absf(vel.y) * 0.3 + 0.7, vel.z * 0.4)
				spin *= 0.5
				pos = Vector3(x, top + R, signf(vel.z) * 0.006)
				events.append({t = "cord", pos = pos})
			else:
				vel = Vector3(vel.x * 0.4, vel.y * 0.5, -vel.z * 0.2)
				spin *= 0.3
				pos = Vector3(x, y, signf(prev.z) * (R + 0.002))
				events.append({t = "net", pos = pos})
			return
	if vel.y < 0.0:
		var ty := TABLE_Y + R
		if pos.y < ty and prev.y >= ty - 0.0001:
			var ax := absf(pos.x)
			var az := absf(pos.z)
			if ax <= HALF_W + R and az <= HALF_L + R:
				var edge := ax > HALF_W or az > HALF_L
				_bounce(ty, e_table * (0.7 if edge else 1.0), mu_table)
				if edge:
					if ax > HALF_W: vel.x += signf(pos.x) * 0.9
					if az > HALF_L: vel.z += signf(pos.z) * 0.9
				events.append({t = "table", side = 0 if pos.z > 0.0 else 1, pos = pos, edge = edge})
				return
		if pos.y < R:
			_bounce(R, 0.7, 0.4)
			events.append({t = "floor", pos = pos})

func _bounce(y0: float, e: float, mu: float) -> void:
	pos.y = y0
	var vn := -vel.y
	var c := Vector2(vel.x + R * spin.z, vel.z - R * spin.x)
	var cl := c.length()
	if cl > 0.00001:
		var dv := minf(mu * (1.0 + e) * vn, 0.4 * cl)
		var ch := c / cl
		vel.x -= ch.x * dv
		vel.z -= ch.y * dv
		spin.x += 1.5 * dv / R * ch.y
		spin.z -= 1.5 * dv / R * ch.x
	vel.y = vn * e
