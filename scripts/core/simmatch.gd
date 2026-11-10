extends RefCounted
# Headless bot-vs-bot play, used by the balance simulation.
const P := preload("res://scripts/core/physics.gd")
const Shot := preload("res://scripts/core/shot.gd")
const Rally := preload("res://scripts/core/rally.gd")
const Rules := preload("res://scripts/core/rules.gd")
const Bot := preload("res://scripts/core/bot.gd")
var ball := P.new()
var solver := Shot.new()
var ref := Rally.new()
var bots: Array = []
var rng := RandomNumberGenerator.new()
var shots := 0
var points := 0

func setup(defs: Array, lvls: Array, bats: Array, serves: Array, seed_: int) -> void:
	rng.seed = seed_
	bots = []
	for i in 2:
		var b := Bot.new()
		b.setup(i, lvls[i], defs[i], bats[i], serves, rng, solver)
		bots.append(b)

# Plays one point; returns the winning side.
func play_point(server: int) -> int:
	points += 1
	while true:
		ref.start(server)
		for b in bots:
			b.x = 0.0
			b.goal_x = 0.0
		var sv: Dictionary = bots[server].serve()
		ball.pos = sv.p
		ball.vel = sv.vel
		ball.spin = sv.spin
		ball.events.clear()
		ref.on_hit(server)
		bots[1 - server].on_incoming(ball.pos, ball.vel, ball.spin, true)
		var res := {}
		for i in 3600:
			ball.step()
			for ev in ball.events:
				res = ref.on_event(ev)
				if not res.is_empty():
					break
			ball.events.clear()
			if not res.is_empty():
				break
			for b in bots:
				var o: RefCounted = bots[1 - b.side]
				var sh: Dictionary = b.tick(P.DT, ball.pos, ball.vel, ball.spin, ref.hitter == o.side and ref.landed, o.x)
				if sh.has("vel"):
					shots += 1
					ball.vel = sh.vel
					ball.spin = sh.spin
					ref.on_hit(b.side)
					o.on_incoming(ball.pos, ball.vel, ball.spin, false)
		if res.has("winner"):
			return res.winner
		if not res.has("let"):
			return 1 - server
	return 0

# Plays a match; returns the winning side.
func play_match(best_of: int) -> int:
	var rules := Rules.new()
	rules.setup(best_of, rng.randi() % 2)
	while true:
		var w := play_point(rules.server())
		if rules.add_point(w) == "match":
			return w
	return 0
