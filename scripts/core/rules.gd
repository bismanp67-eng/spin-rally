extends RefCounted
# ITTF match scoring: games to 11 win by 2, serve changes every 2 points (every point from 10-10).
var best_of := 3
var target := 11
var points := [0, 0]
var games := [0, 0]
var first_server := 0
var history: Array = []

func setup(bo: int, first: int, tgt: int = 11) -> void:
	best_of = bo
	first_server = first
	target = tgt
	points = [0, 0]
	games = [0, 0]
	history = []

func server() -> int:
	var total: int = points[0] + points[1]
	var start: int = (first_server + games[0] + games[1]) % 2
	if points[0] >= target - 1 and points[1] >= target - 1:
		return (start + total) % 2
	return (start + total / 2) % 2

# Returns "", "game" or "match".
func add_point(side: int) -> String:
	points[side] += 1
	if points[side] >= target and points[side] - points[1 - side] >= 2:
		games[side] += 1
		history.append(points.duplicate())
		points = [0, 0]
		return "match" if games[side] > best_of / 2 else "game"
	return ""

# Side holding game point, or -1.
func game_point() -> int:
	for s in 2:
		if points[s] >= target - 1 and points[s] > points[1 - s]:
			return s
	return -1

func match_point() -> int:
	var s := game_point()
	return s if s >= 0 and games[s] == best_of / 2 else -1
