extends Node3D
# One play session: a match, a ball-machine drill, serve practice, a challenge or the tutorial.
# cfg = {steps = [{feed = "match"|"machine"|"serve", text, machine = {}, goal = {}, match = {}}], title}
const P := preload("res://scripts/core/physics.gd")
const Shot := preload("res://scripts/core/shot.gd")
const Rally := preload("res://scripts/core/rally.gd")
const Rules := preload("res://scripts/core/rules.gd")
const Bot := preload("res://scripts/core/bot.gd")
const World := preload("res://scripts/game/world.gd")
const UI := preload("res://scripts/ui/ui.gd")
signal finished(result: Dictionary)
enum {S_WAIT, S_TOSS, S_RALLY, S_OVER, S_REPLAY, S_DONE}
const P_ERR := 0.15  # player's base aim error (m) with perfect timing

var cfg := {}
var steps: Array = []
var step_i := 0
var step := {}
var feed := "match"
var ball := P.new()
var solver := Shot.new()
var ref := Rally.new()
var rules := Rules.new()
var bot: RefCounted = null
var rng := RandomNumberGenerator.new()
var state := S_WAIT
var state_t := 0.0
var now := 0.0
var paused := false
var server := 0
var pending := ""
var was_let := false
var replayed := false
var mybat := {}
var hand := 1.0
var table_def := {}
var arena_def := {}
var opp_name := ""
# goal tracking
var cur := {}
var progress := 0
var balls_used := 0
var returned := 0
# toss
var toss_p := Vector3.ZERO
var toss_v0 := 0.0
var toss_t := 0.0
var toss_T := 0.0
var toss_strike := {}
var toss_side := 0
var wait_delay := 1.2
var serve_swing := Vector3.ZERO
# input
var touch_id := -1
var touch_pos := Vector2.ZERO
var hist: Array = []
var swipe_t := -9.0
var swipe_v := Vector2.ZERO
var swipe_curve := 0.0
var swipe_used := false
var assist_x := 0.0
var assist_on := false
# view state (live or replay)
var bat_pos := Vector3(0, P.TABLE_Y + 0.15, P.HALF_L + 0.25)
var bat_swing := 0.0
var bat_fh := true
var opp_swing := 0.0
var opp_x := 0.0
var frames: Array = []
var replay_i := 0.0
var cam_x := 0.0
var spin_angle := 0.0
var hitstop := 0.0
var shake := 0.0
var tick_i := 0
var myrub := {}
var my_kind := ""
var opp_kind := "drive"
var arena_n: Node3D
var crowd_mat: ShaderMaterial
var excite := 0.0
var clock := 0.0
var prev_ox := 0.0
var opp_move := 0.0
var fps_t := 0.0
# nodes
var cam: Camera3D
var ball_n: MeshInstance3D
var shadow_n: MeshInstance3D
var bat_n: Node3D
var opp_n: Node3D
var me_n: Node3D
var machine_n: Node3D
var zone_n: MeshInstance3D
var puff: CPUParticles3D
var trail: Array = []
var trail_pos: Array = []
# hud
var hud: CanvasLayer
var score_l: Label
var sub_l: Label
var msg_l: Label
var info_l: Label
var goal_l: Label
var serve_b: Button
var pause_b: Button
var radial: Control
var pause_p: Control
var end_p: Control
var msg_t := 0.0
var tip_l: Label
var tip_t := 0.0
var sb: PanelContainer
var sb_cells: Array = []

func _ready() -> void:
	rng.randomize()
	steps = cfg.steps
	mybat = DB.my_bat()
	myrub = Shot.rubber(mybat)
	hand = -1.0 if DB.opt("lefty") else 1.0
	table_def = DB.find(DB.tables, DB.save.equip.table)
	arena_def = DB.find(DB.arenas, DB.save.equip.arena)
	ball.e_table = table_def.e
	ball.mu_table = table_def.mu
	solver.s.e_table = table_def.e
	solver.s.mu_table = table_def.mu
	DB.apply_quality(get_viewport())
	arena_n = World.arena(arena_def)
	add_child(arena_n)
	crowd_mat = arena_n.get_meta("crowd") if arena_n.has_meta("crowd") else null
	add_child(World.table(table_def))
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 46.0
	cam.near = 0.1
	cam.far = 150.0
	cam.position = Vector3(0, 2.4, 4.6)
	add_child(cam)
	var bdef: Dictionary = DB.find(DB.balls, DB.save.equip.ball)
	ball_n = World.game_ball(bdef, DB.opt("colorblind"))
	add_child(ball_n)
	shadow_n = World.blob(self, Vector2(0.13, 0.13), Vector3.ZERO, 0.75)
	if DB.opt("trail"):
		for i in 8:
			var t := World.ball(self, P.R * (1.45 - i * 0.14), Vector3(0, -5, 0), World.mat(World.col(bdef.trail), 0.6, 0.0, 0.6, 0.42 - i * 0.045), 10)
			t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			trail.append(t)
	bat_n = World.bat(mybat)
	bat_n.scale = Vector3.ONE * 1.5
	add_child(bat_n)
	me_n = World.character({skin = "e8b98f", shirt = "f25a4a", shorts = "1b1b2f", hair = "3b2a1a", hs = 0, acc = ""}, mybat, hand)
	me_n.rotation.y = PI
	me_n.visible = false
	add_child(me_n)
	machine_n = World.machine()
	machine_n.position = Vector3(0, 0, -P.HALF_L - 0.3)
	add_child(machine_n)
	var zm := PlaneMesh.new()
	zm.size = Vector2(1, 1)
	zone_n = World.add(self, zm, Vector3.ZERO, World.mat(Color(1.0, 0.85, 0.1), 0.8, 0.0, 0.8, 0.45), false)
	puff = CPUParticles3D.new()
	puff.one_shot = true
	puff.emitting = false
	puff.amount = 18
	puff.lifetime = 0.32
	puff.explosiveness = 1.0
	puff.spread = 180.0
	puff.initial_velocity_min = 0.6
	puff.initial_velocity_max = 2.2
	puff.gravity = Vector3(0, -4, 0)
	puff.scale_amount_min = 0.5
	puff.scale_amount_max = 1.2
	var pm := SphereMesh.new()
	pm.radius = 0.009
	pm.height = 0.018
	pm.radial_segments = 6
	pm.rings = 3
	puff.mesh = pm
	puff.material_override = World.mat(Color(1, 0.97, 0.8), 0.5, 0.0, 2.5)
	add_child(puff)
	_build_hud()
	Sfx.ambience(arena_def.crowd)
	start_step(0)

# ---------- flow ----------
func start_step(i: int) -> void:
	step_i = i
	step = steps[i]
	feed = step.feed
	progress = 0
	balls_used = 0
	returned = 0
	replayed = false
	if opp_n:
		opp_n.queue_free()
		opp_n = null
	bot = null
	machine_n.visible = feed == "machine"
	if feed == "match":
		var m: Dictionary = step.match
		var def: Dictionary = m.bot
		opp_name = def.name
		bot = Bot.new()
		bot.setup(1, DB.levels[int(m.level)], def, DB.find(DB.bats, def.bat), DB.serves, rng, solver)
		opp_n = World.character(def.look, DB.find(DB.bats, def.bat), -1.0 if def.hand == "L" else 1.0)
		opp_kind = "drive"
		add_child(opp_n)
		rules.setup(int(m.get("best_of", 3)), rng.randi() % 2, int(m.get("target", 11)))
		var st: Array = m.get("start", [0, 0])
		rules.points = [int(st[0]), int(st[1])]
	var g: Dictionary = step.get("goal", {})
	zone_n.visible = g.has("zone")
	if g.has("zone"):
		var z: Array = g.zone
		zone_n.scale = Vector3(z[1] - z[0], 1, z[3] - z[2])
		zone_n.position = Vector3((z[0] + z[1]) * 0.5, P.TABLE_Y + 0.003, -(z[2] + z[3]) * 0.5)
	info_l.text = step.get("text", "")
	next_point()

func next_point() -> void:
	state = S_WAIT
	state_t = 0.0
	was_let = false
	pending = ""
	cur = {}
	frames.clear()
	server = 0
	wait_delay = 1.2
	if feed == "match":
		server = rules.server()
	elif feed == "machine":
		server = 1
		wait_delay = step.machine.get("interval", 1.0)
	ref.start(server)
	Sfx.tension(0)
	if bot:
		bot.x = 0.0
		bot.goal_x = 0.0
	serve_b.visible = server == 0
	_update_hud()

func _hold_pos() -> Vector3:
	if server == 0:
		return Vector3(clampf(bat_pos.x, -0.6, 0.6) - hand * 0.18, P.TABLE_Y + 0.22, P.HALF_L + 0.12)
	if feed == "machine":
		return Vector3(0, P.TABLE_Y + 0.3, -P.HALF_L - 0.1)
	return Vector3(opp_x + 0.15, P.TABLE_Y + 0.22, -P.HALF_L - 0.12)

func begin_toss(side: int, p: Vector3, sv: Dictionary, strike: Dictionary) -> void:
	toss_side = side
	toss_p = p
	toss_v0 = sqrt(2.0 * P.G * sv.toss)
	toss_T = 2.0 * toss_v0 / P.G
	toss_t = 0.0
	toss_strike = strike
	serve_swing = Vector3(sv.swing[0], sv.swing[1], sv.swing[2])
	state = S_TOSS
	serve_b.visible = false
	if side == 1:
		sub_flash(sv.name, UI.DIM)

func _strike(side: int, vel: Vector3, spin: Vector3, kind: String = "") -> void:
	ball.vel = vel
	ball.spin = spin
	ball.prev_pos = ball.pos
	var d := Vector3(vel.x, 0, vel.z).normalized()
	var top := spin.dot(Vector3.UP.cross(d))
	var speed := vel.length()
	var power := clampf((speed - 8.0) / 14.0, 0.0, 1.0)
	Sfx.hit(speed, spin.length())
	Sfx.tension(ref.hits)
	puff.position = ball.pos
	puff.restart()
	if power > 0.12:
		hitstop = lerpf(0.04, 0.07, power)
	if speed > 16.0:
		shake = 0.015 + 0.04 * power
	if side == 0:
		if DB.opt("vibrate"):
			Input.vibrate_handheld(int(lerpf(10.0, 45.0, power)), lerpf(0.35, 1.0, power))
		bat_swing = 1.0
		cur = {speed = speed, top = top, side = absf(spin.y), landed = false}
		DB.save.stats.fastest = maxf(DB.save.stats.fastest, speed * 3.6)
		if bot:
			bot.on_incoming(ball.pos, vel, spin, state == S_TOSS)
	else:
		opp_swing = 1.0
		opp_kind = kind
		_predict_assist()
		var parts: Array = []
		if top > 80.0: parts.append("TOPSPIN")
		if top < -80.0: parts.append("BACKSPIN")
		if absf(spin.y) > 80.0: parts.append("SIDESPIN")
		if absf(spin.dot(d)) > 250.0: parts.append("CORKSCREW")
		sub_flash("NO SPIN" if parts.is_empty() else " + ".join(parts),
			Color(0.5, 0.85, 1.0) if top < -80.0 else (Color(1.0, 0.6, 0.4) if top > 80.0 else UI.DIM))

func _predict_assist() -> void:
	var s: RefCounted = solver.s
	s.reset(ball.pos, ball.vel, ball.spin)
	var mine := false
	assist_on = false
	for i in 600:
		s.step()
		for ev in s.events:
			if ev.t == "table" and ev.side == 0:
				mine = true
		s.events.clear()
		if mine and (s.pos.z > P.HALF_L + 0.15 or (s.vel.y < 0.0 and s.pos.y < P.TABLE_Y + 0.15)):
			assist_x = s.pos.x
			assist_on = true
			return

func _physics_process(dt: float) -> void:
	if paused or state == S_DONE:
		return
	now += dt
	_update_swipe()
	if hitstop > 0.0:
		# hit-stop: freeze the world for a few frames on hard contact
		hitstop -= dt
		ball.prev_pos = ball.pos
		return
	state_t += dt
	tick_i += 1
	bat_swing = maxf(0.0, bat_swing - dt * 4.0)
	opp_swing = maxf(0.0, opp_swing - dt * 4.0)
	var fresh := not swipe_used and now - swipe_t < 0.15
	match state:
		S_WAIT:
			ball.pos = _hold_pos()
			ball.prev_pos = ball.pos
			ball.vel = Vector3.ZERO
			if server == 0:
				if fresh and swipe_v.y < 0.0 and not radial.visible:
					swipe_used = true
					_player_serve()
			elif state_t > wait_delay:
				if feed == "machine":
					_machine_launch()
				else:
					var s: Dictionary = bot.serve()
					begin_toss(1, s.p, s.serve, s)
		S_TOSS:
			toss_t += dt
			ball.pos = toss_p + Vector3.UP * (toss_v0 * toss_t - 0.5 * P.G * toss_t * toss_t)
			ball.prev_pos = ball.pos
			if toss_t >= toss_T:
				ball.reset(toss_p, Vector3.ZERO, Vector3.ZERO)
				ref.on_hit(toss_side)
				_strike(toss_side, toss_strike.vel, toss_strike.spin, "serve")
				state = S_RALLY
		S_RALLY, S_OVER:
			ball.step(dt)
			for ev in ball.events:
				_on_ball_event(ev)
			ball.events.clear()
			if state == S_RALLY:
				if bot:
					var sh: Dictionary = bot.tick(dt, ball.pos, ball.vel, ball.spin, ref.hitter == 0 and ref.landed, bat_pos.x)
					if sh.has("vel"):
						ref.on_hit(1)
						_strike(1, sh.vel, sh.spin, sh.kind)
				if fresh and ref.hitter == 1:
					_player_try_hit()
			elif state_t > 1.5:
				_after_point()
		S_REPLAY:
			replay_i += 0.2
			if int(replay_i) >= frames.size():
				_end_replay()
	if bot:
		opp_x = bot.x
	if state != S_REPLAY and state != S_WAIT and tick_i % 2 == 0:
		frames.append([ball.pos, bat_pos, opp_x, opp_swing, bat_swing])
		if frames.size() > 420:
			frames.pop_front()

func _on_ball_event(ev: Dictionary) -> void:
	match ev.t:
		"table":
			if absf(ball.vel.y) > 0.3:
				Sfx.bounce(table_def.surface, absf(ball.vel.y), ball.spin.length())
			if ev.edge and state == S_RALLY:
				flash("EDGE!", 0.9, Color(1, 0.9, 0.3))
		"net", "cord":
			Sfx.play("net", 1.0, 0.8)
			if ev.t == "cord" and state == S_RALLY and not ref.is_serve:
				flash("NET CORD", 0.8, Color(1, 0.9, 0.3))
		"floor":
			if absf(ball.vel.y) > 0.3:
				Sfx.play("floor", 1.0, 0.5)
	if state != S_RALLY:
		return
	var res: Dictionary = ref.on_event(ev)
	if ev.t == "table" and ev.side == 1 and ref.hitter == 0 and not cur.is_empty():
		if not cur.landed and ref.landed:
			cur.landed = true
			cur.pos = ev.pos
		elif cur.landed and not cur.has("second"):
			cur.second = ev.pos
	if not res.is_empty():
		_end_rally(res)

func _end_rally(res: Dictionary) -> void:
	state = S_OVER
	state_t = 0.0
	serve_b.visible = false
	if res.has("let"):
		was_let = true
		flash("LET", 1.2, Color(1, 0.9, 0.3))
		return
	var w: int = res.winner
	var reason: String = res.reason
	var ace := w == 0 and ref.hits == 1 and server == 0 and feed == "match"
	var txt := ""
	if w == 0:
		txt = "ACE!" if ace else {"out": "OUT", "net": "NET", "serve_fault": "FAULT", "own_side": "FAULT", "volley": "VOLLEY"}.get(reason, "POINT!")
	else:
		txt = {"out": "OUT", "net": "NET", "serve_fault": "SERVE FAULT", "own_side": "FAULT", "volley": "VOLLEY FAULT"}.get(reason, "MISSED")
	var good := w == 0
	if feed != "match":
		good = cur.get("landed", false)
		if feed == "machine" and good:
			returned += 1
			txt = "GOOD"
		elif feed == "serve":
			txt = "IN" if good else txt
	flash(txt, 1.2, Color(0.5, 1.0, 0.6) if good else Color(1.0, 0.5, 0.45))
	if feed == "match":
		var st: Dictionary = DB.save.stats
		st["points_won" if w == 0 else "points_lost"] += 1
		st.longest_rally = maxi(int(st.longest_rally), ref.hits)
		if ace:
			st.aces += 1
		pending = rules.add_point(w)
		var hype: float = arena_def.crowd * clampf(0.35 + ref.hits * 0.1 + (0.4 if pending != "" else 0.0), 0.0, 1.2)
		Sfx.crowd("cheer" if w == 0 or pending != "" else "aww", hype)
		excite = clampf(hype * 1.2, 0.0, 1.0) if (w == 0 or pending != "") else 0.15
	Sfx.play("good" if good else "bad", 1.0, 0.5)
	_eval_goal(res)
	_update_hud()

func _eval_goal(res: Dictionary) -> void:
	var g: Dictionary = step.get("goal", {})
	if g.is_empty():
		return
	balls_used += 1
	var okk := false
	match g.type:
		"shots":
			okk = cur.get("landed", false)
			if okk and g.has("zone"):
				var z: Array = g.zone
				var p: Vector3 = cur.pos
				okk = p.x >= z[0] and p.x <= z[1] and -p.z >= z[2] and -p.z <= z[3]
			okk = okk and cur.speed >= g.get("min_speed", 0.0) and cur.top >= g.get("min_top", -999.0) \
				and cur.top <= g.get("max_top", 999.0) and cur.side >= g.get("min_side", 0.0)
			if okk and g.get("double", false):
				okk = cur.has("second")
		"rally":
			okk = ref.hits >= int(g.hits)
		"points":
			okk = res.winner == 0
		"aces":
			okk = res.winner == 0 and ref.hits == 1 and server == 0
		"win":
			return
	if okk:
		progress += 1
	elif g.get("streak", false):
		progress = 0
	if progress >= int(g.need):
		pending = "pass"
	elif g.has("balls") and balls_used >= int(g.balls):
		pending = "fail"

func _after_point() -> void:
	if was_let:
		next_point()
		return
	if (pending == "game" or pending == "match") and DB.opt("replay") and not replayed and frames.size() > 60:
		replayed = true
		state = S_REPLAY
		replay_i = maxf(0.0, frames.size() - 330.0)
		me_n.visible = true
		bat_n.visible = false
		flash("REPLAY", 8.0, Color(1, 1, 1, 0.8))
		sub_flash("tap to skip", UI.DIM)
		return
	replayed = false
	match pending:
		"match":
			_finish_match()
		"pass":
			if step_i + 1 < steps.size():
				flash("NICE!", 1.0, Color(0.5, 1.0, 0.6))
				start_step(step_i + 1)
			else:
				finish({passed = true}, "COMPLETE!", "")
		"fail":
			finish({passed = false}, "NOT THIS TIME", "%d / %d" % [progress, int(step.goal.need)])
		"game":
			var h: Array = rules.history[-1]
			flash("GAME  %d - %d" % [h[0], h[1]], 1.6)
			next_point()
		_:
			next_point()

func _end_replay() -> void:
	msg_t = 0.0
	msg_l.modulate.a = 0.0
	sub_l.text = ""
	me_n.visible = false
	bat_n.visible = true
	state = S_OVER
	state_t = 9.0

func _finish_match() -> void:
	var won: bool = rules.games[0] > rules.games[1]
	var st: Dictionary = DB.save.stats
	st.matches += 1
	if won:
		st.wins += 1
	var id: String = step.match.bot.id
	var rec: Array = st.vs.get(id, [0, 0])
	rec[0 if won else 1] += 1
	st.vs[id] = rec
	var scores: Array = []
	for h in rules.history:
		scores.append("%d-%d" % [h[0], h[1]])
	var g: Dictionary = step.get("goal", {})
	var res := {won = won, games = rules.games.duplicate()}
	if not g.is_empty():
		res.passed = won
	Sfx.crowd("cheer" if won else "aww", maxf(arena_def.crowd, 0.3))
	finish(res, "YOU WIN!" if won else "%s WINS" % opp_name.to_upper(), "  ".join(scores))

func finish(res: Dictionary, title: String, detail: String) -> void:
	state = S_DONE
	DB.write()
	serve_b.visible = false
	pause_b.visible = false
	var v: VBoxContainer = end_p.get_meta("box")
	for c in v.get_children():
		c.queue_free()
	v.add_child(UI.label(title, 56, UI.TEXT, true))
	if detail != "":
		v.add_child(UI.label(detail, 34, UI.DIM, true))
	v.add_child(UI.button("Continue", func(): _exit(res), UI.ACCENT))
	if res.has("passed") and not res.passed:
		res.retry = false
		v.add_child(UI.button("Retry", func():
			res.retry = true
			_exit(res)))
	end_p.visible = true

func _exit(res: Dictionary) -> void:
	Sfx.ambience(0.0)
	finished.emit(res)

# ---------- player ----------
func _swipe_params() -> Dictionary:
	var pw := clampf(swipe_v.length() * DB.opt("sens") / 2600.0, 0.08, 1.25)
	return {pw = pw, fwd = swipe_v.y <= 0.0, ang = clampf(atan2(swipe_v.x, absf(swipe_v.y) + 60.0), -1.1, 1.1)}

func _player_serve() -> void:
	var sv: Dictionary = DB.find(DB.serves, DB.save.last.serve)
	var sp := _swipe_params()
	var depth := clampf(lerpf(sv.depth, sp.pw, 0.75), 0.0, 1.0)
	if sp.pw > 1.12:
		depth = 1.3
	var tgt := Vector3(clampf(tan(sp.ang) * 0.9, -0.68, 0.68), P.TABLE_Y, -lerpf(0.4, 1.2, depth))
	var p := Vector3(clampf(bat_pos.x, -0.6, 0.6), P.TABLE_Y + 0.25, P.HALF_L + 0.12)
	var k: float = 0.8 + 0.4 * mybat.spin
	var r: Dictionary = solver.solve_serve(p, tgt, sv.speed * lerpf(0.8, 1.1, depth) * (0.9 + 0.2 * mybat.speed),
		sv.top * k, sv.side * k * hand + swipe_curve * 170.0, sv.cork * k * hand)
	bat_fh = not sv.bh
	my_kind = "serve"
	begin_toss(0, p, sv, r)

# Turn the swipe into a stroke: bat speed into the ball (a), brushing speed up the face (b), target.
func _player_try_hit() -> void:
	var bp := ball.pos
	if bp.z < 0.2 or bp.y < 0.35:
		return
	var assist: bool = DB.opt("assist")
	var off_m := absf(bat_pos.x - bp.x)
	if not assist and off_m > 0.45:
		return
	var volley := false
	if not ref.landed:
		if bp.z < 0.5 or bp.z > P.HALF_L or bp.y > P.TABLE_Y + 0.6:
			return
		if (bp.y - P.TABLE_Y - P.R) / maxf(-ball.vel.y, 0.1) < 0.14:
			return
		volley = true
	swipe_used = true
	var sp := _swipe_params()
	var pw: float = sp.pw
	var bc: float = 1.3 - 0.6 * mybat.control
	var d_in := Vector3(ball.vel.x, 0, ball.vel.z).normalized()
	var top_in := ball.spin.dot(Vector3.UP.cross(d_in))
	var read: float = 0.6 + 0.35 * mybat.control
	var h := bp.y - P.TABLE_Y
	var a := 0.0
	var b := 0.0
	var depth := lerpf(0.55, 1.15, minf(pw, 1.0))
	var kind := ""
	if sp.fwd:
		var t := clampf((pw - 0.65) / 0.35, 0.0, 1.0)
		if pw < 0.3:
			kind = "TOUCH"
			a = lerpf(0.4, 2.2, pw / 0.3)
			b = 1.0
			depth = lerpf(0.35, 0.7, pw / 0.3)
		elif pw < 0.65:
			kind = "DRIVE"
			a = lerpf(3.0, 6.0, (pw - 0.3) / 0.35)
			b = lerpf(2.5, 5.0, (pw - 0.3) / 0.35)
		elif h > 0.32:
			kind = "SMASH"
			a = lerpf(9.5, 14.5, t)
			b = 1.5
		else:
			kind = "LOOP"
			a = lerpf(4.0, 6.5, t)
			b = lerpf(8.0, 13.0, t)
		if top_in < -80.0:
			read = 0.92 if kind == "LOOP" else (0.75 if kind == "SMASH" else 0.45)
	else:
		if pw < 0.5:
			kind = "PUSH"
			a = lerpf(1.0, 2.2, pw / 0.5)
			b = -lerpf(2.5, 5.0, pw / 0.5)
			depth = lerpf(0.35, 0.9, pw / 0.5)
		else:
			kind = "CHOP"
			a = lerpf(2.5, 4.0, (pw - 0.5) / 0.5)
			b = -lerpf(6.0, 9.5, (pw - 0.5) / 0.5)
			depth = lerpf(0.7, 1.1, (pw - 0.5) / 0.5)
		read = 0.97 if top_in < -80.0 else (0.5 if top_in > 80.0 else read)
	if pw > 1.0:
		depth += (pw - 1.0) * 2.5
	var tq := clampf(absf(ball.vel.y) / 3.0, 0.0, 1.0)
	if tq < 0.2:
		tip(kind + "  ·  PERFECT", Color(0.5, 1.0, 0.6))
	elif tq > 0.55:
		tip(kind + ("  ·  EARLY" if ball.vel.y > 0.0 else "  ·  LATE"), Color(1.0, 0.75, 0.4))
	else:
		tip(kind, UI.TEXT)
	var tx := clampf(bp.x * 0.35 + tan(sp.ang) * 1.1, -P.HALF_W - 0.2, P.HALF_W + 0.2)
	bat_fh = (bp.x - bat_pos.x + 0.15 * hand) * hand >= 0.0 if not assist else bp.x * hand >= -0.15
	my_kind = kind.to_lower()
	var sh: Dictionary = solver.strike({
		p = bp, v_in = ball.vel, w_in = ball.spin, target = Vector3(tx, P.TABLE_Y, -depth),
		a = a, b_up = b, b_side = swipe_curve * 6.0, rub = myrub, read = read,
		off = clampf(maxf(0.0 if assist else off_m / 0.45, tq * 0.5), 0.0, 1.0),
		err = P_ERR * bc * (0.6 + ball.vel.length() / 14.0 + a / 12.0 + 1.2 * tq + (0.0 if assist else off_m * 0.7)),
	}, rng)
	var res: Dictionary = ref.on_hit(0)
	_strike(0, sh.vel, sh.spin, my_kind)
	if volley and not res.is_empty():
		_end_rally(res)

func _machine_launch() -> void:
	var m: Dictionary = step.machine
	var place: float = m.get("place", 0.0)
	if m.get("random", false):
		place = rng.randf_range(-1.0, 1.0)
	var p := _hold_pos()
	var r: Dictionary = solver.solve(p, Vector3(place * 0.6, P.TABLE_Y, lerpf(0.55, 1.15, m.get("depth", 0.6))),
		lerpf(4.0, 11.0, m.get("speed", 0.3)), m.get("top", 0.0) * 385.0, m.get("side", 0.0) * 280.0)
	ball.reset(p, Vector3.ZERO, Vector3.ZERO)
	ref.start(1)
	ref.on_hit(1)
	ref.is_serve = false
	state = S_RALLY
	_strike(1, r.vel, r.spin, "drive")

# Swing speed and direction come from the last ~100 ms of finger movement.
func _update_swipe() -> void:
	while hist.size() > 0 and now - hist[0][0] > 0.22:
		hist.pop_front()
	if touch_id < 0 or hist.size() < 3:
		return
	var last: Array = hist[-1]
	var ref_i := 0
	for i in hist.size():
		if last[0] - hist[i][0] <= 0.1:
			ref_i = i
			break
	var dtt: float = last[0] - hist[ref_i][0]
	if dtt < 0.02 or now - last[0] > 0.05:
		if now - last[0] > 0.08:
			swipe_used = false
		return
	var v: Vector2 = (last[1] - hist[ref_i][1]) / dtt
	var thr: float = 520.0 / DB.opt("sens")
	if v.length() < thr * 0.5:
		swipe_used = false
	if v.length() > thr:
		if now - swipe_t > 0.15 or v.length() > swipe_v.length():
			swipe_v = v
			var early: Vector2 = hist[ref_i][1] - hist[0][1]
			var late: Vector2 = last[1] - hist[ref_i][1]
			swipe_curve = 0.0
			if early.length() > 12.0 and late.length() > 12.0:
				swipe_curve = clampf(early.normalized().cross(late.normalized()) * 1.6, -1.0, 1.0)
		swipe_t = now

# Runs every rendered frame. The bat leads the finger slightly so it never feels late.
func _update_bat(dt: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var tx := bat_pos.x
	var tz := P.HALF_L + 0.3
	if touch_id >= 0:
		var fp := touch_pos
		if hist.size() >= 2 and now - hist[-1][0] < 0.05:
			var h0: Array = hist[maxi(hist.size() - 4, 0)]
			var hd: float = hist[-1][0] - h0[0]
			if hd > 0.004:
				fp += (hist[-1][1] - h0[1]) / hd * 0.03
		tx = (fp.x / vs.x - 0.5) * 2.3
		tz = P.HALF_L - 0.2 + clampf((fp.y / vs.y - 0.5) / 0.45, 0.0, 1.0) * 0.9
	var incoming := state == S_RALLY and ref.hitter == 1
	if incoming and DB.opt("assist") and assist_on:
		tx = assist_x + hand * 0.02
	var ty := P.TABLE_Y + 0.16
	if incoming and ball.pos.z > 0.4:
		ty = clampf(ball.pos.y, P.TABLE_Y - 0.2, P.TABLE_Y + 0.9)
	bat_pos = bat_pos.lerp(Vector3(clampf(tx, -1.25, 1.25), ty, tz), minf(1.0, dt * 40.0))
	if state == S_TOSS and toss_side == 0:
		# serve-specific wind-up: the bat travels along the serve's swing path into the ball
		var k := 1.0 - toss_t / toss_T
		bat_pos = toss_p - Vector3(serve_swing.x * hand, serve_swing.y, serve_swing.z) * k * 0.7 + Vector3(0, 0, 0.05)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			if paused or state == S_DONE or radial.visible:
				return
			if state == S_REPLAY:
				_end_replay()
				return
			if touch_id < 0 and not serve_b.get_global_rect().has_point(e.position) and not pause_b.get_global_rect().has_point(e.position):
				touch_id = e.index
				touch_pos = e.position
				hist.clear()
				hist.append([now, e.position])
		elif e.index == touch_id:
			touch_id = -1
			swipe_used = false
	elif e is InputEventScreenDrag and e.index == touch_id:
		touch_pos = e.position
		hist.append([now, e.position])

func _notification(what: int) -> void:
	if not is_inside_tree() or state == S_DONE:
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		set_paused(not paused)
	elif (what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT) and not paused:
		set_paused(true)

# ---------- visuals ----------
func _process(dt: float) -> void:
	if not paused and state != S_DONE:
		_update_bat(dt)
	# render between physics ticks so motion is smooth at any frame rate
	var bp := ball.pos
	if (state == S_RALLY or state == S_OVER) and hitstop <= 0.0:
		bp = ball.prev_pos.lerp(ball.pos, Engine.get_physics_interpolation_fraction())
	var bt := bat_pos
	var ox := opp_x
	var osw := opp_swing
	var psw := bat_swing
	var replay := state == S_REPLAY and frames.size() > 0
	if replay:
		var f: Array = frames[mini(int(replay_i), frames.size() - 1)]
		bp = f[0]
		bt = f[1]
		ox = f[2]
		osw = f[3]
		psw = f[4]
	ball_n.position = bp
	var wl := ball.spin.length()
	if wl > 1.0 and not paused:
		# true spin axis; rate scaled down so the logo stays readable instead of strobing
		ball_n.basis = (Basis(ball.spin / wl, wl * dt * 0.1) * ball_n.basis).orthonormalized()
	var over_table := absf(bp.x) < P.HALF_W and absf(bp.z) < P.HALF_L and bp.y > P.TABLE_Y
	shadow_n.position = Vector3(bp.x, (P.TABLE_Y if over_table else 0.0) + 0.005, bp.z)
	var sh_h := maxf(bp.y - shadow_n.position.y, 0.0)
	shadow_n.scale = Vector3.ONE * (1.0 + sh_h * 1.2)
	shadow_n.material_override.albedo_color.a = clampf(0.8 - sh_h * 0.5, 0.2, 0.8)
	if trail.size() > 0 and not paused:
		trail_pos.push_front(bp)
		if trail_pos.size() > 9:
			trail_pos.pop_back()
		var live := state == S_RALLY or state == S_OVER or replay
		var n_vis := clampi(int(ball.vel.length() / 2.2), 0, 8) if live else 0
		for i in trail.size():
			trail[i].visible = i < n_vis and i + 1 < trail_pos.size()
			if trail[i].visible:
				trail[i].position = trail_pos[i + 1]
	clock += dt
	var sw := sin(psw * PI)
	var open: float = {"push": 0.55, "chop": 0.7, "touch": 0.2, "loop": -0.55, "smash": 0.1}.get(my_kind, 0.0) if psw > 0.0 else 0.0
	var lift: float = {"loop": 0.24, "chop": -0.14, "push": -0.05, "smash": -0.12}.get(my_kind, 0.08)
	bat_n.position = bt + Vector3(0, sw * lift, -sw * 0.3)
	var fh_side := hand if bat_fh else -hand
	bat_n.rotation = Vector3(-0.35 + open - sw * 0.45, PI if bat_fh else 0.0, -fh_side * 0.9)
	if me_n.visible:
		me_n.position = Vector3(bt.x + hand * 0.32, 0, P.HALF_L + 0.8)
		World.pose(me_n, my_kind if my_kind != "" else "drive", clampf((bp.z + 0.6) / 1.6, 0.0, 1.0) if ref.hitter == 1 else 0.0, psw, 0.0, clock)
	if opp_n:
		opp_move = lerpf(opp_move, clampf((ox - prev_ox) / maxf(dt, 0.001) / 2.5, -1.0, 1.0), minf(1.0, dt * 8.0))
		prev_ox = ox
		opp_n.position = Vector3(ox - bot.hand * 0.3, 0, -(P.HALF_L + bot.st.standoff + 0.45))
		var serving := state == S_TOSS and toss_side == 1
		var tossk := toss_t / maxf(toss_T, 0.01)
		var prep := clampf((0.6 - bp.z) / 1.6, 0.0, 1.0) if (state == S_RALLY and ref.hitter == 0) else (tossk if serving else 0.0)
		World.pose(opp_n, "serve" if serving else opp_kind, prep, osw, opp_move, clock, sin(tossk * PI) if serving else 0.0)
	if crowd_mat:
		excite = lerpf(excite, 0.0, minf(1.0, dt * 0.9))
		crowd_mat.set_shader_parameter("excite", excite)
	cam_x = lerpf(cam_x, clampf(bp.x, -1.0, 1.0) * 0.16, minf(1.0, dt * 3.0))
	var cp := Vector3(cam_x, 1.72, 3.25)
	var look := Vector3(cam_x * 0.5, 0.98, -0.2)
	if replay:
		# cinematic slow orbit
		var ang := 0.55 + replay_i / maxf(frames.size(), 1.0) * 0.6
		cp = Vector3(sin(ang) * 4.9, 2.5, cos(ang) * 4.9 + 0.2)
		look = Vector3(0.0, 0.9, -0.1)
	elif DB.opt("fp_cam"):
		cp = Vector3(bt.x * 0.5, 1.32, 2.5)
		look = Vector3(bt.x * 0.2, 0.8, -0.8)
	cam.position = cam.position.lerp(cp, minf(1.0, dt * (4.0 if replay else 8.0)))
	cam.look_at(look)
	cam.h_offset = randf_range(-1.0, 1.0) * shake
	cam.v_offset = randf_range(-1.0, 1.0) * shake
	shake = lerpf(shake, 0.0, minf(1.0, dt * 10.0))
	cam.fov = lerpf(cam.fov, (54.0 if replay else 46.0) + shake * 70.0, minf(1.0, dt * 10.0))
	fps_t += dt
	if fps_t > 3.0:
		fps_t = 0.0
		DB.adapt_quality(get_viewport())
	if tip_t > 0.0:
		tip_t -= dt
		tip_l.modulate.a = clampf(tip_t * 3.0, 0.0, 1.0)
	if msg_t > 0.0:
		msg_t -= dt
		msg_l.modulate.a = clampf(msg_t * 3.0, 0.0, 1.0)

# ---------- HUD ----------
func flash(t: String, secs: float = 1.2, c: Color = UI.TEXT) -> void:
	msg_l.text = t
	msg_l.add_theme_color_override("font_color", c)
	msg_t = secs

func tip(t: String, c: Color) -> void:
	tip_l.text = t
	tip_l.add_theme_color_override("font_color", c)
	tip_t = 0.7

func sub_flash(t: String, c: Color) -> void:
	sub_l.text = t
	sub_l.add_theme_color_override("font_color", c)

func _update_hud() -> void:
	var g: Dictionary = step.get("goal", {})
	goal_l.text = ""
	sb.visible = feed == "match"
	score_l.visible = feed != "match"
	if feed == "match":
		var names := ["YOU", opp_name.split(" ")[0].to_upper()]
		for i in 2:
			var c: Array = sb_cells[i]
			c[0].modulate.a = 1.0 if server == i and state != S_DONE else 0.0
			c[1].text = names[i]
			c[2].text = str(rules.games[i])
			if c[3].text != str(rules.points[i]):
				c[3].text = str(rules.points[i])
				c[3].pivot_offset = c[3].size * 0.5
				c[3].scale = Vector2(1.5, 1.5)
				c[3].create_tween().tween_property(c[3], "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if rules.game_point() >= 0 and state == S_WAIT:
			goal_l.text = "MATCH POINT" if rules.match_point() >= 0 else "GAME POINT"
	elif g.is_empty():
		score_l.text = "Returned %d" % returned if feed == "machine" else "Serve practice"
	if not g.is_empty() and g.type != "win":
		score_l.text = "%d / %d" % [progress, int(g.need)]
		if g.has("balls"):
			goal_l.text = "Balls left: %d" % (int(g.balls) - balls_used)
	serve_b.text = "Serve:\n" + DB.find(DB.serves, DB.save.last.serve).name

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var top := UI.vbox(2)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = UI.safe_top(root)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	# broadcast scoreboard: serve dot, name, games, points
	sb = UI.panel(Color(0.02, 0.03, 0.06, 0.86), 18)
	sb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	sb.add_child(grid)
	for i in 2:
		var dot := Panel.new()
		dot.add_theme_stylebox_override("panel", UI.style(UI.ACCENT, 8))
		dot.custom_minimum_size = Vector2(16, 16)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nm := UI.label("", 28)
		nm.custom_minimum_size.x = 210
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.clip_text = true
		var gm := UI.label("0", 26, UI.DIM, true)
		gm.custom_minimum_size.x = 40
		var ptp := PanelContainer.new()
		ptp.add_theme_stylebox_override("panel", UI.style(UI.ACCENT if i == 0 else Color(0.2, 0.25, 0.36), 10))
		var pt := UI.label("0", 34, UI.TEXT, true)
		pt.custom_minimum_size.x = 56
		ptp.add_child(pt)
		for c in [dot, nm, gm, ptp]:
			grid.add_child(c)
		sb_cells.append([dot, nm, gm, pt])
	top.add_child(sb)
	score_l = UI.label("", 44, UI.TEXT, true)
	goal_l = UI.label("", 24, UI.DIM, true)
	info_l = UI.label("", 28, Color(1, 0.95, 0.6), true)
	sub_l = UI.label("", 26, UI.DIM, true)
	for l in [score_l, goal_l, info_l, sub_l]:
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 8)
		top.add_child(l)
	msg_l = UI.label("", 84, UI.TEXT, true)
	msg_l.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	msg_l.anchor_top = 0.36
	msg_l.anchor_bottom = 0.36
	msg_l.add_theme_color_override("font_outline_color", Color.BLACK)
	msg_l.add_theme_constant_override("outline_size", 14)
	msg_l.modulate.a = 0.0
	root.add_child(msg_l)
	tip_l = UI.label("", 40, UI.TEXT, true)
	tip_l.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	tip_l.anchor_top = 0.66
	tip_l.anchor_bottom = 0.66
	tip_l.add_theme_color_override("font_outline_color", Color.BLACK)
	tip_l.add_theme_constant_override("outline_size", 10)
	tip_l.modulate.a = 0.0
	root.add_child(tip_l)
	pause_b = UI.button("II", func(): set_paused(true), Color(0, 0, 0, 0.45), 30, 76)
	pause_b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_b.offset_left = -96
	pause_b.offset_right = -16
	pause_b.offset_top = UI.safe_top(root)
	pause_b.offset_bottom = UI.safe_top(root) + 76
	root.add_child(pause_b)
	serve_b = UI.button("Serve", func(): radial.visible = true, Color(0.1, 0.2, 0.4, 0.85), 24, 110)
	serve_b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT if hand < 0 else Control.PRESET_BOTTOM_LEFT)
	serve_b.offset_left = -236.0 if hand < 0 else 16.0
	serve_b.offset_right = -16.0 if hand < 0 else 236.0
	serve_b.offset_top = -150
	serve_b.offset_bottom = -40
	root.add_child(serve_b)
	# radial serve menu
	radial = ColorRect.new()
	radial.color = Color(0, 0, 0, 0.6)
	radial.set_anchors_preset(Control.PRESET_FULL_RECT)
	radial.visible = false
	root.add_child(radial)
	var hint := UI.label("Pick a serve, then swipe up.\nSwipe speed = length, angle = placement, curve = extra sidespin.", 24, UI.DIM, true)
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.offset_left = -150
	hint.offset_right = 150
	hint.offset_top = -70
	hint.offset_bottom = 70
	radial.add_child(hint)
	var n := DB.serves.size()
	for i in n:
		var sv: Dictionary = DB.serves[i]
		var b := UI.button(sv.name.replace(" ", "\n"), func():
			DB.save.last.serve = sv.id
			radial.visible = false
			_update_hud(), UI.ACCENT2.darkened(0.45), 20, 86)
		var a := TAU * i / n - PI / 2
		b.set_anchors_preset(Control.PRESET_CENTER)
		b.tooltip_text = sv.desc
		var c := Vector2(cos(a) * 265.0, sin(a) * 330.0)
		b.offset_left = c.x - 78
		b.offset_right = c.x + 78
		b.offset_top = c.y - 43
		b.offset_bottom = c.y + 43
		radial.add_child(b)
	# pause panel
	pause_p = ColorRect.new()
	pause_p.color = Color(0, 0, 0, 0.7)
	pause_p.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_p.visible = false
	root.add_child(pause_p)
	var pv := UI.vbox(16)
	pv.set_anchors_preset(Control.PRESET_CENTER)
	pv.offset_left = -280
	pv.offset_right = 280
	pv.offset_top = -420
	pv.offset_bottom = 420
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_p.add_child(pv)
	pv.add_child(UI.label("PAUSED", 56, UI.TEXT, true))
	if steps[0].feed == "machine" and steps[0].get("goal", {}).is_empty():
		var m: Dictionary = steps[0].machine
		for spec in [["speed", "Speed", 0.0, 1.0], ["top", "Backspin  <  spin  >  Topspin", -1.0, 1.0], ["side", "Sidespin", -1.0, 1.0],
				["place", "Placement (left - right)", -1.0, 1.0], ["depth", "Depth", 0.0, 1.0], ["interval", "Seconds between balls", 0.5, 3.0]]:
			pv.add_child(UI.label(spec[1], 22, UI.DIM))
			var key: String = spec[0]
			pv.add_child(UI.slider(m.get(key, 0.0), spec[2], spec[3], 0.05, func(v): m[key] = v))
		var cb := CheckButton.new()
		cb.text = "Random placement"
		cb.add_theme_font_size_override("font_size", 26)
		cb.button_pressed = m.get("random", false)
		cb.toggled.connect(func(v): m.random = v)
		pv.add_child(cb)
	pv.add_child(UI.button("Resume", func(): set_paused(false), UI.ACCENT))
	pv.add_child(UI.button("Quit to menu", func():
		DB.write()
		_exit({aborted = true})))
	end_p = ColorRect.new()
	end_p.color = Color(0, 0, 0, 0.72)
	end_p.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_p.visible = false
	root.add_child(end_p)
	var ev := UI.vbox(20)
	ev.set_anchors_preset(Control.PRESET_CENTER)
	ev.offset_left = -280
	ev.offset_right = 280
	ev.offset_top = -200
	ev.offset_bottom = 200
	ev.alignment = BoxContainer.ALIGNMENT_CENTER
	end_p.add_child(ev)
	end_p.set_meta("box", ev)

func set_paused(p: bool) -> void:
	if p and radial.visible:
		radial.visible = false
		return
	paused = p
	pause_p.visible = p
	touch_id = -1
