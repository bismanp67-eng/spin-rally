extends RefCounted
# Geometric bat: a disc (the blade) with a face normal, moving through space.
# Contact is found by sweeping the ball against the bat in the bat's own moving frame,
# so neither a fast ball nor a fast swing can pass through.
const P := preload("res://scripts/core/physics.gd")
const BLADE_R := 0.082   # real blade half-width (m)
const HALF_T := 0.006    # half thickness of blade plus rubbers

# Swept sphere (ball p0 -> p0 + d) against a moving disc (centre c0 -> c0 + cd, unit normal n, radius r).
# Returns {} for no contact, or {t = 0..1, off = 0 centre .. 1 rim, radial = unit vector from centre to
# the contact point, front = true if the ball met the side the normal points to}.
static func sweep(p0: Vector3, d: Vector3, c0: Vector3, cd: Vector3, n: Vector3, r: float) -> Dictionary:
	var rel := p0 - c0
	var rd := d - cd
	var s0 := rel.dot(n)
	var sd := rd.dot(n)
	var gap := P.R + HALF_T
	var t := 0.0
	if absf(s0) > gap:
		if absf(sd) < 0.0000001 or (s0 > 0.0) == (sd > 0.0):
			return {}
		t = (absf(s0) - gap) / absf(sd)
		if t > 1.0:
			return {}
	elif (s0 >= 0.0) == (sd >= 0.0) and absf(sd) > 0.0000001:
		return {}  # already touching but separating
	var at := rel + rd * t
	var lat := at - n * at.dot(n)
	var dist := lat.length()
	if dist > r + P.R * 0.5:
		return {}
	return {t = t, off = clampf(dist / r, 0.0, 1.0), radial = lat / dist if dist > 0.0001 else Vector3.ZERO, front = s0 >= 0.0}
