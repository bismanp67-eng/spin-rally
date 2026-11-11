extends SceneTree
# Screenshot tour for visual review:
#   xvfb-run -a -s "-screen 0 720x1480x24" godot --rendering-method mobile --rendering-driver vulkan --resolution 720x1480 --fixed-fps 30 -s tests/shots.gd -- OUT_DIR [arena] [table] [quality]
var main: Node
var frames := 0
var out := ""
var phase := 0
var local := 0
var took := {}
var pending := ""
var countdown := 0

func snap(n: String) -> void:
	# rendering is switched off between shots (software Vulkan is slow); turn it on for a few frames
	if took.has(n) or pending != "":
		return
	took[n] = true
	pending = n
	countdown = 3
	RenderingServer.render_loop_enabled = true

func _process(_dt: float) -> bool:
	frames += 1
	if pending != "":
		countdown -= 1
		if countdown <= 0:
			root.get_texture().get_image().save_png(out + "/" + pending + ".png")
			pending = ""
			RenderingServer.render_loop_enabled = false
		return false
	var args := OS.get_cmdline_user_args()
	if frames == 3:
		out = args[0]
		RenderingServer.render_loop_enabled = false
		var db: Node = root.get_node("DB")
		db.save.tutorial_done = true
		db.save.settings.auto_q = false
		db.save.settings.quality = int(args[3]) if args.size() > 3 else 2
		if args.size() > 1:
			db.save.equip.arena = args[1]
		if args.size() > 2:
			db.save.equip.table = args[2]
		main = load("res://main.tscn").instantiate()
		root.add_child(main)
	if frames < 10:
		return false
	var g = main.game
	local += 1
	if phase == 0:
		if local == 45:
			snap("1_menu")
		if local == 50:
			main.eq_tab = "bat"
			main.go(main.scr_equipment)
		if local == 85:
			snap("2_equipment")
		if local == 90:
			main.go(main.scr_settings)
		if local == 120:
			snap("3_settings")
		if local == 125:
			phase = 1
			local = 0
			main.play({steps = [{feed = "match", match = {bot = root.get_node("DB").bots[7], level = 3, best_of = 1, start = [8, 7]}}]}, main.nothing)
		return false
	if g == null:
		return true
	g.swipe_used = false
	g.autoplay = true
	if (g.state == 0 and g.server == 0 and local > 40) or (g.state == 2 and g.ref.hitter == 1 and g.ref.landed and g.ball.vel.y < 0.3):
		g.swipe_v = Vector2(randf_range(-300, 300), -randf_range(1300, 2100))
		g.swipe_t = g.now
	if local == 30:
		snap("4_scoreboard")
	if g.state == 2 and g.ref.hits >= 2 and absf(g.ball.pos.z) < 0.5:
		snap("5_rally")
	if g.state == 2 and g.ref.hits >= 3 and g.ball.pos.z < -0.9:
		snap("6_rally_far")
	if g.state == 4 and g.replay_i > g.frames.size() * 0.6:
		snap("7_replay")
	if g.state == 5:
		if not took.has("end_t"):
			took["end_t"] = local
		elif local - took["end_t"] == 6:
			snap("8_result")
			return true
	if local > 2600:
		return true
	return false
