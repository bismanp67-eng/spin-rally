extends SceneTree
# One rally screenshot per arena on High:
#   xvfb-run -a -s "-screen 0 720x1480x24" godot --rendering-method mobile --rendering-driver vulkan --resolution 720x1480 --fixed-fps 30 -s tests/arenas.gd -- OUT_DIR
var main: Node
var frames := 0
var idx := -1
var local := 0
var countdown := 0

func _process(_dt: float) -> bool:
	frames += 1
	var db: Node = root.get_node("DB")
	if frames == 3:
		RenderingServer.render_loop_enabled = false
		db.save.tutorial_done = true
		db.save.settings.auto_q = false
		db.save.settings.quality = 2
		db.save.settings.replay = false
		main = load("res://main.tscn").instantiate()
		root.add_child(main)
	if frames < 10:
		return false
	var g = main.game
	if g == null:
		idx += 1
		if idx >= db.arenas.size():
			return true
		db.save.equip.arena = db.arenas[idx].id
		db.save.equip.table = db.tables[idx].id
		local = 0
		countdown = 0
		main.play({steps = [{feed = "match", match = {bot = db.bots[idx], level = 3, best_of = 1}}]}, main.nothing)
		return false
	local += 1
	g.swipe_used = false
	g.autoplay = true
	if (g.state == 0 and g.server == 0 and local > 30) or (g.state == 2 and g.ref.hitter == 1 and g.ref.landed and g.ball.vel.y < 0.3):
		g.swipe_v = Vector2(randf_range(-300, 300), -randf_range(1300, 2000))
		g.swipe_t = g.now
	if countdown > 0:
		countdown -= 1
		if countdown == 0:
			root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/%02d_%s.png" % [idx, db.arenas[idx].id])
			RenderingServer.render_loop_enabled = false
			g._exit({})
	elif (local > 60 and g.state == 2 and absf(g.ball.pos.z) < 0.7 and g.ball.pos.y > 0.8) or local > 900:
		RenderingServer.render_loop_enabled = true
		countdown = 3
	return false
