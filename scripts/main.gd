extends Node
# App shell: all menu screens, built in code, plus launching play sessions.
const UI := preload("res://scripts/ui/ui.gd")
const Match := preload("res://scripts/game/match.gd")
const World := preload("res://scripts/game/world.gd")
const SWATCHES := ["e23b3b", "111111", "1f6feb", "2ea043", "f2c94c", "bb6bd9", "ff7a00", "ffffff", "c89a5b", "6b4423"]
const SHAPES := ["Straight", "Flared", "Penhold"]
var layer: CanvasLayer
var title_l: Label
var back_b: Button
var box: VBoxContainer
var stack: Array = []
var game: Node = null
var tour := {}
var eq_tab := "bat"
var bg3d: Node3D
var bg_cam: Camera3D
var preview_item: Node3D
var orbit := 0.6
var anim := true

const BLUR := "shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 c = textureLod(screen, SCREEN_UV, 3.2).rgb;
	float v = smoothstep(0.0, 1.0, UV.y);
	COLOR = vec4(mix(c, vec3(0.03, 0.045, 0.085), 0.34 + 0.26 * v), 1.0);
}"

func _ready() -> void:
	Engine.max_fps = int(DB.opt("fps"))
	get_tree().root.theme = UI.theme()
	DB.apply_quality(get_viewport())
	layer = CanvasLayer.new()
	add_child(layer)
	# frosted glass: the live 3D scene behind the menu, blurred and tinted
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if World.Q >= 1:
		var sm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = BLUR
		sm.shader = sh
		bg.material = sm
	else:
		bg.color = Color(UI.BG.r, UI.BG.g, UI.BG.b, 0.72)
	layer.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, UI.S3)
	m.add_theme_constant_override("margin_top", int(UI.safe_top(bg)) + UI.S2)
	layer.add_child(m)
	var v := UI.vbox(UI.S2)
	m.add_child(v)
	var head := UI.hbox(12)
	v.add_child(head)
	back_b = UI.button("‹", back, UI.PANEL, 44, 80)
	back_b.custom_minimum_size.x = 88
	head.add_child(back_b)
	title_l = UI.label("", 46)
	title_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(UI.expand(title_l))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	box = UI.vbox(14)
	sc.add_child(UI.expand(box))
	_build_bg()
	go(scr_home)
	if not DB.save.tutorial_done:
		start_tutorial()

# Live 3D backdrop: the current arena and table with a slowly orbiting camera.
func _build_bg() -> void:
	bg3d = Node3D.new()
	add_child(bg3d)
	bg3d.add_child(World.arena(DB.find(DB.arenas, DB.save.equip.arena)))
	bg3d.add_child(World.table(DB.find(DB.tables, DB.save.equip.table)))
	var b := World.bat(DB.my_bat())
	b.position = Vector3(0.3, 0.775, 0.9)
	b.rotation = Vector3(PI / 2, 0.5, 0)
	bg3d.add_child(b)
	var ball := World.game_ball(DB.find(DB.balls, DB.save.equip.ball), false, 1.0)
	ball.position = Vector3(0.12, 0.78, 0.82)
	bg3d.add_child(ball)
	bg_cam = Camera3D.new()
	bg_cam.keep_aspect = Camera3D.KEEP_WIDTH
	bg_cam.fov = 44.0
	bg3d.add_child(bg_cam)

func _process(dt: float) -> void:
	orbit += dt * 0.12
	if bg_cam and is_instance_valid(bg_cam):
		bg_cam.position = Vector3(sin(orbit) * 4.3, 1.9 + sin(orbit * 0.7) * 0.25, cos(orbit) * 4.3)
		bg_cam.look_at(Vector3(0, 0.95, 0))
	if preview_item and is_instance_valid(preview_item):
		preview_item.rotation.y += dt * 0.9

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and game == null:
		Sfx.play("back")
		back()

func go(screen: Callable) -> void:
	stack.append(screen)
	anim = true
	render()

func back() -> void:
	if stack.size() > 1:
		stack.pop_back()
		anim = true
		render()
	else:
		DB.write()
		get_tree().quit()

func render() -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	preview_item = null
	back_b.visible = stack.size() > 1
	stack[-1].call()
	if anim:
		# screen transition: content fades and rises in, staggered
		anim = false
		Sfx.play("whoosh", 1.0, 0.5)
		var i := 0
		for c in box.get_children():
			UI.enter(c, i)
			i += 1
		title_l.modulate.a = 0.0
		title_l.create_tween().tween_property(title_l, "modulate:a", 1.0, 0.25)

func play(cfg: Dictionary, on_done: Callable) -> void:
	layer.visible = false
	if bg3d:
		bg3d.queue_free()
		bg3d = null
		bg_cam = null
	game = Match.new()
	game.cfg = cfg.duplicate(true)
	add_child(game)
	Sfx.set_mode("match")
	game.finished.connect(func(res: Dictionary):
		game.queue_free()
		game = null
		if res.get("retry", false):
			play(cfg, on_done)
			return
		Sfx.set_mode("menu")
		layer.visible = true
		DB.apply_quality(get_viewport())
		_build_bg()
		on_done.call(res)
		DB.write()
		anim = true
		render())

# A small rotating 3D preview of a piece of equipment, rendered in its own world.
func preview(kind: String, def: Dictionary) -> void:
	var c := SubViewportContainer.new()
	c.stretch = true
	c.custom_minimum_size = Vector2(0, 330)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X if World.Q >= 2 else Viewport.MSAA_2X
	c.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.95)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	sun.light_energy = 1.4
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var item: Node3D
	match kind:
		"bat":
			item = World.bat(def)
			item.position.y = 0.045
			cam.position = Vector3(0, 0.12, 0.62)
		"ball":
			item = World.game_ball(def, false, 1.0)
			cam.position = Vector3(0, 0.03, 0.2)
		_:
			item = World.table(def)
			cam.position = Vector3(0, 2.3, 5.6)
	var pivot := Node3D.new()
	pivot.add_child(item)
	vp.add_child(pivot)
	cam.look_at_from_position(cam.position, Vector3(0, 0.5 if kind == "table" else 0.0, 0))
	preview_item = pivot
	var p := UI.panel(Color(0.05, 0.07, 0.12, 0.55))
	p.add_child(c)
	add(p)

func nothing(_res: Dictionary) -> void:
	pass

# ---------- small builders ----------
func add(c: Control) -> Control:
	box.add_child(c)
	return c

func choices(options: Array, selected: int, cb: Callable, cols: int = 3) -> void:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	for i in options.size():
		g.add_child(UI.expand(UI.button(str(options[i]), func():
			cb.call(i)
			render(), UI.ACCENT if i == selected else UI.PANEL, 26, 72)))
	add(g)

func stepper(text: String, sub: String, cb: Callable) -> void:
	var h := UI.hbox(10)
	var l := UI.button("<", func():
		cb.call(-1)
		render(), UI.PANEL, 34, 110)
	l.custom_minimum_size.x = 80
	h.add_child(l)
	var p := UI.panel()
	var pv := UI.vbox(4)
	pv.add_child(UI.label(text, 32, UI.TEXT, true))
	pv.add_child(UI.label(sub, 22, UI.DIM, true))
	p.add_child(pv)
	h.add_child(UI.expand(p))
	var r := UI.button(">", func():
		cb.call(1)
		render(), UI.PANEL, 34, 110)
	r.custom_minimum_size.x = 80
	h.add_child(r)
	add(h)

func match_step(bot_id: String, level: int, best_of: int) -> Dictionary:
	return {feed = "match", match = {bot = DB.find(DB.bots, bot_id), level = level, best_of = best_of}}

# ---------- screens ----------
func scr_home() -> void:
	title_l.text = "SPIN RALLY"
	title_l.text = "SPIN RALLY"
	add(UI.label("OFFLINE TABLE TENNIS  ·  EVERYTHING UNLOCKED", 20, UI.ACCENT))
	add(UI.button("Quick Match", func(): go(scr_quick), UI.ACCENT, 36, 110))
	for e in [["Tournament", scr_tournament], ["Ladder", scr_ladder], ["Challenges", scr_challenges]]:
		var scr: Callable = e[1]
		add(UI.button(e[0], func(): go(scr)))
	var h := UI.hbox(12)
	h.add_child(UI.expand(UI.button("Practice", func(): play({steps = [{feed = "machine", text = "Ball machine: pause to adjust it.",
		machine = {speed = 0.3, top = 0.0, side = 0.0, place = 0.0, depth = 0.6, interval = 1.2, random = false}}]}, nothing))))
	h.add_child(UI.expand(UI.button("Serve Practice", func(): play({steps = [{feed = "serve", text = "Serve practice: pick a serve, swipe up."}]}, nothing))))
	add(h)
	for e in [["Equipment", scr_equipment], ["Stats", scr_stats], ["Settings", scr_settings]]:
		var scr2: Callable = e[1]
		add(UI.button(e[0], func(): go(scr2)))
	add(UI.button("How to Play", start_tutorial))

func start_tutorial() -> void:
	var mk := func(text: String, mach: Dictionary, goal: Dictionary) -> Dictionary:
		return {feed = "machine", text = text, machine = mach, goal = goal}
	var easy := {speed = 0.15, interval = 1.4}
	play({steps = [
		mk.call("Drag: the bat follows your finger.\nSwipe UP as the ball arrives. Return 2.", easy, {type = "shots", need = 2}),
		mk.call("A faster swipe hits harder and deeper.\nHit 2 strong returns.", easy, {type = "shots", need = 2, min_speed = 8.5}),
		mk.call("Swipe at an angle to aim.\nLand 2 in the yellow zone.", easy, {type = "shots", need = 2, zone = [-0.77, -0.05, 0.3, 1.38]}),
		mk.call("Swipe DOWN (toward you) to chop with backspin.\nPush backspin balls back, or loop them hard. Chop 2.", {speed = 0.15, top = -0.5, interval = 1.4}, {type = "shots", need = 2, max_top = -60}),
		{feed = "serve", text = "Your serve! Tap the Serve button to choose,\nthen swipe up. Land 2 serves.", goal = {type = "shots", need = 2}},
	]}, func(_r):
		DB.save.tutorial_done = true)

func scr_quick() -> void:
	title_l.text = "Quick Match"
	var last: Dictionary = DB.save.last
	var bi := 0
	for i in DB.bots.size():
		if DB.bots[i].id == last.bot:
			bi = i
	var b: Dictionary = DB.bots[bi]
	add(UI.label("Opponent", 24, UI.DIM))
	stepper(b.name, "%s  ·  %s-handed" % [b.style, "Left" if b.hand == "L" else "Right"], func(d): last.bot = DB.bots[posmod(bi + d, DB.bots.size())].id)
	add(UI.label(b.bio, 24, UI.DIM, true))
	add(UI.label("Difficulty", 24, UI.DIM))
	var names: Array = []
	for l in DB.levels:
		names.append(l.name)
	choices(names, int(last.level), func(i): last.level = i)
	add(UI.label("Match length (best of)", 24, UI.DIM))
	choices([1, 3, 5, 7], [1, 3, 5, 7].find(int(last.best_of)), func(i): last.best_of = [1, 3, 5, 7][i], 4)
	add(UI.button("PLAY", func(): play({steps = [match_step(last.bot, int(last.level), int(last.best_of))]}, nothing), UI.ACCENT, 38, 120))

func scr_ladder() -> void:
	title_l.text = "Ladder"
	add(UI.label("Beat every player, in any order. Best of 3 at their own level.", 24, UI.DIM))
	for b in DB.bots:
		var id: String = b.id
		var done: bool = DB.save.ladder.get(id, false)
		add(UI.button("%s%s  ·  %s  ·  %s" % ["DONE  ·  " if done else "", b.name, b.style, DB.levels[int(b.level)].name], func():
			play({steps = [match_step(id, int(b.level), 3)]}, func(res):
				if res.get("won", false):
					DB.save.ladder[id] = true), UI.GOOD if done else UI.PANEL, 24, 78))

func scr_challenges() -> void:
	title_l.text = "Trick Shots"
	for c in DB.challenges:
		var id: String = c.id
		var done: bool = DB.save.challenges.get(id, false)
		add(UI.button("%s%s\n%s" % ["DONE  ·  " if done else "", c.name, c.text], func():
			var st: Dictionary = c.duplicate(true)
			if st.has("match"):
				st.match.bot = DB.find(DB.bots, st.match.bot)
			play({steps = [st]}, func(res):
				if res.get("passed", false):
					DB.save.challenges[id] = true), UI.GOOD if done else UI.PANEL, 22, 104))

func scr_tournament() -> void:
	title_l.text = "Tournament"
	var last: Dictionary = DB.save.last
	if tour.is_empty():
		add(UI.label("Knockout bracket, best of 3. Opponents get tougher each round.", 24, UI.DIM))
		add(UI.label("Bracket size", 24, UI.DIM))
		choices([8, 16], [8, 16].find(int(last.bracket)), func(i): last.bracket = [8, 16][i], 2)
		add(UI.label("Difficulty", 24, UI.DIM))
		var names: Array = []
		for l in DB.levels:
			names.append(l.name)
		choices(names, int(last.level), func(i): last.level = i)
		add(UI.button("START", func():
			var ids: Array = []
			for b in DB.bots:
				ids.append(b.id)
			ids.shuffle()
			ids = ids.slice(0, int(last.bracket) - 1)
			ids.insert(randi() % (ids.size() + 1), "you")
			tour = {alive = ids, round = 0, level = int(last.level), log = [], over = ""}
			render(), UI.ACCENT, 36, 110))
		return
	var alive: Array = tour.alive
	var rname: String = {2: "Final", 4: "Semi-finals", 8: "Quarter-finals", 16: "Round of 16"}.get(alive.size(), "Champion")
	add(UI.label(rname if tour.over == "" else tour.over, 36, UI.TEXT, true))
	var opp := ""
	for i in range(0, alive.size() - 1, 2):
		var a: String = alive[i]
		var b: String = alive[i + 1]
		if a == "you" or b == "you":
			opp = b if a == "you" else a
		add(UI.label("%s   vs   %s" % [_tname(a), _tname(b)], 26, UI.TEXT if (a == "you" or b == "you") else UI.DIM, true))
	for line in tour.log:
		add(UI.label(line, 20, UI.DIM, true))
	if tour.over != "" or opp == "":
		add(UI.button("New tournament", func():
			tour = {}
			render(), UI.ACCENT))
		return
	var lvl := clampi(int(tour.level) + int(tour.round) - 1 + (1 if int(DB.find(DB.bots, opp).level) >= 4 else 0), 0, 5)
	add(UI.label("Your opponent plays at %s level." % DB.levels[lvl].name, 22, UI.DIM, true))
	add(UI.button("PLAY MATCH", func(): play({steps = [match_step(opp, lvl, 3)]}, func(res):
		if res.get("aborted", false):
			return
		_advance_tour(res.get("won", false))), UI.ACCENT, 36, 110))
	add(UI.button("Abandon tournament", func():
		tour = {}
		render()))

func _tname(id: String) -> String:
	return "YOU" if id == "you" else DB.find(DB.bots, id).name

func _advance_tour(won: bool) -> void:
	var alive: Array = tour.alive
	var nxt: Array = []
	tour.log = []
	for i in range(0, alive.size(), 2):
		var a: String = alive[i]
		var b: String = alive[i + 1]
		var w := a
		if a == "you" or b == "you":
			w = "you" if won else (b if a == "you" else a)
		else:
			var ra: float = DB.find(DB.bots, a).level
			var rb: float = DB.find(DB.bots, b).level
			w = a if randf() < 1.0 / (1.0 + pow(10.0, (rb - ra) / 2.0)) else b
			tour.log.append("%s beat %s" % [_tname(w), _tname(b if w == a else a)])
		nxt.append(w)
	if not won:
		tour.over = "Knocked out. Better luck next time!"
	elif nxt.size() == 1:
		tour.over = "CHAMPION! You won the tournament!"
		DB.save.stats.tournaments += 1
	tour.alive = nxt
	tour.round = int(tour.round) + 1

func scr_equipment() -> void:
	title_l.text = "Equipment"
	var tabs := ["bat", "table", "arena", "ball"]
	choices(["Bat", "Table", "Arena", "Ball"], tabs.find(eq_tab), func(i): eq_tab = tabs[i], 4)
	var eq: Dictionary = DB.save.equip
	var list: Array = {"bat": DB.bats, "table": DB.tables, "arena": DB.arenas, "ball": DB.balls}[eq_tab]
	if eq_tab != "arena":
		preview(eq_tab, DB.my_bat() if eq_tab == "bat" else DB.find(list, eq[eq_tab]))
	if eq_tab == "bat":
		var b := DB.my_bat()
		var p := UI.panel()
		var pv := UI.vbox(8)
		p.add_child(pv)
		pv.add_child(UI.label(b.name, 32))
		pv.add_child(UI.bar("Speed", b.speed, UI.ACCENT))
		pv.add_child(UI.bar("Spin", b.spin, UI.ACCENT2))
		pv.add_child(UI.bar("Control", b.control, Color(0.3, 0.8, 0.4)))
		pv.add_child(UI.label("Customize: forehand, backhand, handle", 22, UI.DIM))
		for key in ["fh", "bh", "handle"]:
			var row := UI.hbox(6)
			for hex in SWATCHES:
				var sb := UI.button("", func():
					eq[key] = hex
					render(), Color.html(hex), 10, 48)
				if b[key] == hex:
					sb.add_theme_stylebox_override("normal", UI.style(Color.html(hex), 18, Color.WHITE))
				row.add_child(UI.expand(sb))
			pv.add_child(row)
		pv.add_child(UI.button("Handle: " + SHAPES[int(eq.shape)], func():
			eq.shape = (int(eq.shape) + 1) % 3
			render(), UI.BG, 24, 64))
		add(p)
	for e in list:
		var id: String = e.id
		var txt: String = e.name
		if eq_tab == "bat":
			txt += "\nSPD %d  ·  SPN %d  ·  CTL %d" % [e.speed * 100, e.spin * 100, e.control * 100]
		var h := UI.hbox(8)
		var sw := ColorRect.new()
		sw.color = Color.html(e.get("fh", e.get("top", e.get("floor", e.get("color", "ffffff")))))
		sw.custom_minimum_size = Vector2(26, 0)
		h.add_child(sw)
		h.add_child(UI.expand(UI.button(txt, func():
			eq[eq_tab] = id
			if eq_tab == "bat":
				eq.fh = ""
				eq.bh = ""
				eq.handle = ""
			render(), UI.ACCENT if eq[eq_tab] == id else UI.PANEL, 24, 86 if eq_tab == "bat" else 70)))
		add(h)

func scr_stats() -> void:
	title_l.text = "Stats"
	var s: Dictionary = DB.save.stats
	var done_l := 0
	for k in DB.save.ladder:
		done_l += 1
	var done_c := 0
	for k in DB.save.challenges:
		done_c += 1
	var rows := [["Matches played", int(s.matches)], ["Matches won", "%d (%d%%)" % [int(s.wins), 100 * int(s.wins) / maxi(int(s.matches), 1)]],
		["Points won / lost", "%d / %d" % [int(s.points_won), int(s.points_lost)]], ["Longest rally", "%d shots" % int(s.longest_rally)],
		["Fastest shot", "%d km/h" % int(s.fastest)], ["Aces", int(s.aces)], ["Tournaments won", int(s.tournaments)],
		["Ladder", "%d / %d" % [done_l, DB.bots.size()]], ["Trick shots", "%d / %d" % [done_c, DB.challenges.size()]]]
	for r in rows:
		var h := UI.hbox()
		h.add_child(UI.expand(UI.label(r[0], 28, UI.DIM)))
		var vl := UI.label(str(r[1]), 28)
		if r[1] is int:
			UI.count_up(vl, float(r[1]), "%d")
		vl.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(vl)
		add(h)
	add(UI.label("Head to head (won - lost)", 24, UI.DIM))
	for b in DB.bots:
		if s.vs.has(b.id):
			add(UI.label("%s:  %d - %d" % [b.name, int(s.vs[b.id][0]), int(s.vs[b.id][1])], 24))

func scr_settings() -> void:
	title_l.text = "Settings"
	var st: Dictionary = DB.save.settings
	add(UI.label("Graphics quality", 24, UI.DIM))
	choices(["Low", "Medium", "High", "Ultra"], int(st.quality), func(i):
		st.quality = i
		st.auto_q = false, 4)
	add(UI.button("Auto-detect quality:  %s" % ("ON" if st.auto_q else "OFF"), func():
		st.auto_q = not st.auto_q
		if st.auto_q:
			st.quality = DB.detect_quality()
		render(), UI.GOOD if st.auto_q else UI.PANEL, 26, 72))
	add(UI.label("FPS cap", 24, UI.DIM))
	choices([30, 60, 120], [30, 60, 120].find(int(st.fps)), func(i):
		st.fps = [30, 60, 120][i]
		Engine.max_fps = int(st.fps))
	add(UI.label("Assist (Off = pure physics: you must really meet the ball)", 24, UI.DIM))
	choices(["Off", "Light", "Strong"], int(st.assist_lv), func(i): st.assist_lv = i)
	for t in [["lefty", "Left-handed mode"], ["colorblind", "Colorblind-friendly ball"],
			["fp_cam", "First-person camera"], ["trail", "Ball trail"], ["replay", "Slow-motion replays"], ["vibrate", "Vibration"]]:
		var key: String = t[0]
		add(UI.button("%s:  %s" % [t[1], "ON" if st[key] else "OFF"], func():
			st[key] = not st[key]
			render(), UI.GOOD if st[key] else UI.PANEL, 26, 72))
	for t in [["sens", "Control sensitivity", 0.5, 2.0], ["sfx", "Sound volume", 0.0, 1.0], ["music", "Music volume", 0.0, 1.0], ["crowd", "Crowd volume", 0.0, 1.0]]:
		var key2: String = t[0]
		add(UI.label(t[1], 24, UI.DIM))
		add(UI.slider(st[key2], t[2], t[3], 0.05, func(v):
			st[key2] = v
			Sfx.apply_volumes()))
	add(UI.button("Replay tutorial", start_tutorial))
