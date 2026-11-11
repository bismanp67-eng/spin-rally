extends SceneTree
# Autoplay of the tutorial: godot --headless --fixed-fps 30 -s tests/tutorial.gd
var main: Node
var frames := 0
var last_step := -1
var started := false

func _process(_dt: float) -> bool:
	frames += 1
	if frames == 3:
		root.get_node("DB").save.tutorial_done = true
		main = load("res://main.tscn").instantiate()
		root.add_child(main)
	if frames < 10:
		return false
	if not started:
		started = true
		main.start_tutorial()
		return false
	var g = main.game
	if g == null:
		print("TUTORIAL FINISHED at frame %d" % frames)
		return true
	if g.step_i != last_step:
		last_step = g.step_i
		print("step %d at frame %d" % [last_step, frames])
	g.swipe_used = false
	g.autoplay = true
	var serve_now: bool = g.state == 0 and g.server == 0
	var hit_now: bool = g.state == 2 and g.ref.hitter == 1 and g.ref.landed and (g.ball.pos.z > 1.2 or g.ball.vel.y < 0.0)
	if serve_now or hit_now:
		var down: bool = g.step_i == 3
		g.swipe_v = Vector2(randf_range(-900, 100) if g.step_i == 2 else randf_range(-300, 300), randf_range(900, 1500) if down else -randf_range(1200, 2200))
		g.swipe_t = g.now
	if g.state == 5:
		g._exit({})
	if frames > 20000:
		print("TUTORIAL STUCK at step %d state %d" % [g.step_i, g.state])
		return true
	return false
