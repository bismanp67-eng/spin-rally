extends RefCounted
# Referee for one rally. Feed it hits and physics events; it returns {winner, reason} or {let = true}.
var server := 0
var hitter := -1
var is_serve := true
var own_bounced := false
var landed := false
var net_touched := false
var hits := 0
var over := false

func start(srv: int) -> void:
	server = srv
	hitter = -1
	is_serve = true
	own_bounced = false
	landed = false
	net_touched = false
	hits = 0
	over = false

func _end(winner: int, reason: String) -> Dictionary:
	over = true
	return {winner = winner, reason = reason}

func on_hit(side: int) -> Dictionary:
	if over or side == hitter:
		return {}
	if hitter == -1:
		hitter = side
		hits = 1
		return {}
	if not landed:
		return _end(hitter, "volley")
	hitter = side
	is_serve = false
	landed = false
	net_touched = false
	hits += 1
	return {}

func on_event(ev: Dictionary) -> Dictionary:
	if over or hitter < 0:
		return {}
	var recv := 1 - hitter
	match ev.t:
		"net", "cord":
			net_touched = true
		"table":
			if landed:
				return _end(hitter, "double_bounce")
			if ev.side == hitter:
				if is_serve and not own_bounced:
					own_bounced = true
					return {}
				return _end(recv, "net" if net_touched else "own_side")
			if is_serve and not own_bounced:
				return _end(recv, "serve_fault")
			if is_serve and net_touched:
				over = true
				return {let = true}
			landed = true
		"floor", "side":
			if landed:
				return _end(hitter, "winner")
			return _end(recv, "net" if net_touched else "out")
	return {}
