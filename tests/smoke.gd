extends SceneTree
# Autoplay smoke test: godot --headless --fixed-fps 30 -s tests/smoke.gd
# Plays the tutorial, a match, serve practice and every challenge with a scripted "player".
var main: Node
var frames := 0
var queue: Array = []
var done_count := 0
var cur_name := "tutorial"
var t_in := 0


func _process(_dt: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	if frames == 3:
		main = load("res://main.tscn").instantiate()
		root.add_child(main)
		var DB: Node = root.get_node("DB")
		queue.append(["match", {steps = [main.match_step("tomasz", 0, 1)]}])
		queue.append(["serve", {steps = [{feed = "serve", goal = {type = "shots", need = 3}}]}])
		for c in DB.challenges:
			var st: Dictionary = c.duplicate(true)
			if st.has("match"):
				st.match.bot = DB.find(DB.bots, st.match.bot)
			queue.append([c.id, {steps = [st]}])
	var g = main.game
	if g == null:
		if queue.is_empty() or frames > 60000:
			print("SMOKE DONE sessions=%d frames=%d" % [done_count, frames])
			return true
		var q: Array = queue.pop_front()
		cur_name = q[0]
		t_in = 0
		main.play(q[1], main.nothing)
		return false
	t_in += 1
	g.swipe_used = false
	var serve_now: bool = g.state == 0 and g.server == 0
	var hit_now: bool = g.state == 2 and g.ref.hitter == 1 and g.ref.landed and (g.ball.pos.z > 1.2 or g.ball.vel.y < 0.0)
	if serve_now or hit_now:
		g.swipe_v = Vector2(randf_range(-500, 500), -randf_range(1000, 2300))
		g.swipe_t = g.now
	if g.state == 4:
		g._end_replay()
	if g.state == 5 or t_in > 5400:
		print("%s: step=%d state=%d progress=%d pts=%s games=%s" % [cur_name, g.step_i, g.state, g.progress, g.rules.points, g.rules.games])
		done_count += 1
		g._exit({})
	return false
