extends RefCounted
# Procedural visuals: everything is built from primitives and colours found in the JSON data.
const P := preload("res://scripts/core/physics.gd")

static func col(hex: String) -> Color:
	return Color.html(hex)

static func mat(c: Color, rough: float = 0.7, metal: float = 0.0, emit: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

static func add(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return add(parent, b, pos, m)

static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 12
	c.rings = 1
	return add(parent, c, pos, m)

static func ball(parent: Node3D, r: float, pos: Vector3, m: Material, seg: int = 12) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return add(parent, s, pos, m)

static func table(def: Dictionary) -> Node3D:
	var n := Node3D.new()
	var glow: float = def.glow
	var top := mat(col(def.top), def.rough, def.metal, 0.0, def.alpha)
	var line := mat(col(def.line), 0.6, 0.0, glow)
	var frame := mat(col(def.frame), 0.6, def.metal, glow * 0.5)
	var w := P.HALF_W * 2.0
	var l := P.HALF_L * 2.0
	box(n, Vector3(w, 0.03, l), Vector3(0, P.TABLE_Y - 0.015, 0), top)
	var y := P.TABLE_Y + 0.001
	for sx in [-1.0, 1.0]:
		box(n, Vector3(0.02, 0.002, l), Vector3(sx * (P.HALF_W - 0.01), y, 0), line)
		box(n, Vector3(w, 0.002, 0.02), Vector3(0, y, sx * (P.HALF_L - 0.01)), line)
	box(n, Vector3(0.004, 0.002, l), Vector3(0, y, 0), line)
	box(n, Vector3(w - 0.1, 0.06, l - 0.1), Vector3(0, P.TABLE_Y - 0.06, 0), frame)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			box(n, Vector3(0.05, P.TABLE_Y - 0.09, 0.05), Vector3(sx * 0.6, (P.TABLE_Y - 0.09) * 0.5, sz * 1.05), frame)
		cyl(n, 0.012, 0.012, P.NET_H + 0.02, Vector3(sx * (P.HALF_W + P.NET_OVER), P.TABLE_Y + P.NET_H * 0.5, 0), frame)
	var nw := (P.HALF_W + P.NET_OVER) * 2.0
	box(n, Vector3(nw, P.NET_H, 0.004), Vector3(0, P.TABLE_Y + P.NET_H * 0.5, 0), mat(Color(0.08, 0.08, 0.1), 0.9, 0.0, 0.0, 0.6))
	box(n, Vector3(nw, 0.014, 0.008), Vector3(0, P.TABLE_Y + P.NET_H, 0), mat(Color(0.95, 0.95, 0.95), 0.8, 0.0, glow))
	return n

static func bat(def: Dictionary) -> Node3D:
	# Blade faces +/-Z, handle points down (-Y). Origin is the blade centre.
	var n := Node3D.new()
	var wood := mat(col(def.get("handle", "c89a5b")), 0.8)
	for i in 3:
		var c := cyl(n, 0.078, 0.078, 0.005, Vector3(0, 0, (i - 1) * 0.005), [mat(col(def.bh), 0.9), wood, mat(col(def.fh), 0.9)][i])
		c.rotation.x = PI / 2
		c.scale = Vector3(1, 1, 1.08)
	var shape: int = int(def.get("shape", 0))
	var hl := 0.06 if shape == 2 else 0.1
	cyl(n, 0.014, 0.019 if shape == 1 else 0.014, hl, Vector3(0, -0.085 - hl * 0.5, 0), wood).scale = Vector3(1, 1, 0.75)
	return n

static func character(look: Dictionary, bat_def: Dictionary, hand: float) -> Node3D:
	# Faces +Z. meta "arm" = shoulder pivot holding the bat.
	var n := Node3D.new()
	var skin := mat(col(look.skin), 0.8)
	var shirt := mat(col(look.shirt), 0.8)
	var shorts := mat(col(look.shorts), 0.8)
	var hair := mat(col(look.hair), 0.9)
	for sx in [-1.0, 1.0]:
		cyl(n, 0.055, 0.045, 0.5, Vector3(sx * 0.1, 0.33, 0), skin)
		box(n, Vector3(0.1, 0.07, 0.22), Vector3(sx * 0.1, 0.04, 0.04), mat(Color(0.95, 0.95, 0.95)))
	box(n, Vector3(0.36, 0.26, 0.22), Vector3(0, 0.7, 0), shorts)
	var body := CapsuleMesh.new()
	body.radius = 0.17
	body.height = 0.62
	add(n, body, Vector3(0, 1.1, 0), shirt)
	ball(n, 0.12, Vector3(0, 1.55, 0), skin)
	for sx in [-1.0, 1.0]:
		ball(n, 0.018, Vector3(sx * 0.045, 1.57, 0.105), mat(Color(0.05, 0.05, 0.05)), 6)
	match int(look.hs):
		0:
			ball(n, 0.125, Vector3(0, 1.58, -0.02), hair).scale = Vector3(1, 0.8, 1)
		1:
			cyl(n, 0.02, 0.12, 0.14, Vector3(0, 1.67, -0.01), hair)
		2:
			ball(n, 0.14, Vector3(0, 1.56, -0.05), hair).scale = Vector3(1, 1.15, 0.9)
		_:
			box(n, Vector3(0.05, 0.12, 0.22), Vector3(0, 1.67, -0.02), hair)
	match look.acc:
		"band":
			cyl(n, 0.123, 0.123, 0.03, Vector3(0, 1.6, 0), mat(Color(0.95, 0.95, 0.95)))
		"cap":
			cyl(n, 0.125, 0.125, 0.07, Vector3(0, 1.65, 0), shirt)
			box(n, Vector3(0.16, 0.012, 0.12), Vector3(0, 1.62, 0.14), shirt)
		"glasses":
			box(n, Vector3(0.2, 0.035, 0.02), Vector3(0, 1.57, 0.11), mat(Color(0.05, 0.05, 0.08), 0.2))
	# free arm
	cyl(n, 0.04, 0.035, 0.45, Vector3(-hand * 0.24, 1.12, 0.03), skin).rotation.z = -hand * 0.15
	# bat arm
	var arm := Node3D.new()
	arm.position = Vector3(hand * 0.22, 1.33, 0)
	n.add_child(arm)
	cyl(arm, 0.04, 0.035, 0.5, Vector3(0, -0.25, 0), skin)
	var b := bat(bat_def)
	b.position = Vector3(0, -0.6, 0.02)
	b.rotation.x = PI
	arm.add_child(b)
	arm.rotation = Vector3(-1.0, 0, hand * 0.3)
	n.set_meta("arm", arm)
	return n

static func machine() -> Node3D:
	var n := Node3D.new()
	var m := mat(Color(0.25, 0.3, 0.4), 0.4, 0.5)
	box(n, Vector3(0.4, 0.3, 0.4), Vector3(0, P.TABLE_Y + 0.25, 0), m)
	cyl(n, 0.03, 0.03, 0.9, Vector3(0, 0.45, 0), m)
	cyl(n, 0.05, 0.05, 0.3, Vector3(0, P.TABLE_Y + 0.3, 0.25), mat(Color(0.9, 0.5, 0.1), 0.4)).rotation.x = PI / 2
	return n

static func _multi(parent: Node3D, mesh: Mesh, m: Material, xforms: Array, colors: Array = []) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors.size() > 0
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

# quality: 0 low, 1 medium, 2 high
static func arena(def: Dictionary, quality: int) -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(def.id)
	var props: Array = def.props
	var open := props.has("skyline") or props.has("palms") or props.has("rain") or props.has("stars")
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = col(def.sky_top)
	sm.sky_horizon_color = col(def.sky_bot)
	sm.ground_bottom_color = col(def.floor).darkened(0.5)
	sm.ground_horizon_color = col(def.sky_bot)
	sm.sun_angle_max = 0.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = col(def.light).lerp(col(def.sky_top), 0.3)
	env.ambient_light_energy = def.ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if quality >= 2:
		env.glow_enabled = true
		env.glow_intensity = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	n.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = col(def.light)
	sun.light_energy = def.energy
	sun.rotation = Vector3(-1.05, 0.5, 0)
	sun.shadow_enabled = quality >= 2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 12.0
	n.add_child(sun)
	var floor_m := mat(col(def.floor), 0.85)
	var pl := PlaneMesh.new()
	pl.size = Vector2(40, 40)
	add(n, pl, Vector3.ZERO, floor_m)
	var wall := mat(col(def.wall), 0.9)
	if not open:
		for a in 4:
			var wbox := box(n, Vector3(22, 7, 0.3), Vector3(0, 3.5, -11).rotated(Vector3.UP, a * PI / 2), wall)
			wbox.rotation.y = a * PI / 2
		box(n, Vector3(22, 0.3, 22), Vector3(0, 7.1, 0), mat(col(def.wall).darkened(0.3), 0.9))
	var few := 0.5 if quality == 0 else 1.0
	for prop in props:
		match prop:
			"barriers":
				var bm := mat(col(def.wall).lerp(Color(0.1, 0.25, 0.6), 0.6), 0.7)
				for sx in [-1.0, 1.0]:
					box(n, Vector3(0.06, 0.7, 9), Vector3(sx * 3.4, 0.35, 0), bm)
					box(n, Vector3(6.8, 0.7, 0.06), Vector3(0, 0.35, sx * 5.2 - (0.0 if sx < 0 else 0.0)), bm).visible = sx < 0
			"crowd", "bleachers":
				var xf: Array = []
				var cs: Array = []
				var rows := 6 if prop == "crowd" else 3
				var step_m := mat(col(def.wall).lightened(0.1), 0.9)
				for sx in [-1.0, 1.0]:
					for r in rows:
						box(n, Vector3(1.0, 0.5 + r * 0.45, 12), Vector3(sx * (4.6 + r), (0.5 + r * 0.45) * 0.5, -1), step_m)
						for i in int(22 * few):
							if rng.randf() < (0.9 if prop == "crowd" else 0.35):
								xf.append(Transform3D(Basis().scaled(Vector3(1, rng.randf_range(0.9, 1.2), 1)), Vector3(sx * (4.6 + r), 0.85 + r * 0.45, -6.8 + i * 0.53 / few)))
								cs.append(Color.from_hsv(rng.randf(), 0.55, 0.85))
				var cap := CapsuleMesh.new()
				cap.radius = 0.16
				cap.height = 0.7
				cap.radial_segments = 6
				cap.rings = 2
				var cm := mat(Color.WHITE, 0.9)
				cm.vertex_color_use_as_albedo = true
				_multi(n, cap, cm, xf, cs)
			"spots", "lamp", "lanterns":
				var lm := mat(col(def.light), 0.5, 0.0, 3.0)
				var pts := [Vector3(0, 2.6, 0)] if prop == "lamp" else [Vector3(-3, 5.5, -3), Vector3(3, 5.5, -3), Vector3(-3, 5.5, 3), Vector3(3, 5.5, 3)]
				if prop == "lanterns":
					pts = [Vector3(-2.6, 2.2, -4), Vector3(2.6, 2.2, -4), Vector3(-2.6, 2.2, 1), Vector3(2.6, 2.2, 1)]
					lm = mat(Color(1.0, 0.55, 0.2), 0.5, 0.0, 2.5)
				for pt in pts:
					ball(n, 0.18, pt, lm, 8)
			"shelves":
				for i in 4:
					box(n, Vector3(3, 0.06, 0.5), Vector3(-4, 0.6 + i * 0.6, -6.5), mat(Color(0.35, 0.25, 0.15)))
					for j in 5:
						box(n, Vector3(0.35, 0.3, 0.35), Vector3(-5.2 + j * 0.6, 0.8 + i * 0.6, -6.5), mat(Color.from_hsv(rng.randf(), 0.5, 0.6)))
				box(n, Vector3(4.5, 2.6, 0.1), Vector3(3.5, 1.3, -10.7), mat(Color(0.75, 0.75, 0.78), 0.4, 0.6))
			"lines":
				var lnm := mat(Color(0.95, 0.95, 0.9), 0.8)
				for i in 5:
					box(n, Vector3(18, 0.004, 0.06), Vector3(0, 0.003, -8 + i * 4.0), lnm)
				box(n, Vector3(0.06, 0.004, 18), Vector3(0, 0.003, 0), mat(Color(0.8, 0.2, 0.2)))
			"tables":
				var tdef := {top = "1f4fa3", line = "ffffff", frame = "1b1b1b", rough = 0.6, metal = 0.0, alpha = 1.0, glow = 0.0}
				for sx in [-1.0, 1.0]:
					var t := table(tdef)
					t.position = Vector3(sx * 5.5, 0, -3.5)
					n.add_child(t)
			"skyline", "panels":
				var xf2: Array = []
				var cs2: Array = []
				for i in int(46 * few):
					var ang := rng.randf() * TAU
					var h := rng.randf_range(4, 22) if prop == "skyline" else rng.randf_range(1, 3)
					var dist := rng.randf_range(16, 24) if prop == "skyline" else 10.4
					var bpos := Vector3(cos(ang) * dist, h * 0.5 - (6.0 if prop == "skyline" else -1.0), sin(ang) * dist)
					xf2.append(Transform3D(Basis(Vector3.UP, -ang).scaled(Vector3(rng.randf_range(2, 4), h, rng.randf_range(2, 4)) if prop == "skyline" else Vector3(0.2, h, 1.2)), bpos))
					cs2.append(Color.from_hsv(rng.randf_range(0.55, 0.7), 0.3, rng.randf_range(0.25, 0.6)))
				var bm2 := mat(Color.WHITE, 0.6, 0.0)
				bm2.vertex_color_use_as_albedo = true
				if prop == "panels" or def.id == "night_city":
					bm2.emission_enabled = true
					bm2.emission = Color(0.3, 0.4, 0.8)
					bm2.emission_energy_multiplier = 0.6
				_multi(n, BoxMesh.new(), bm2, xf2, cs2)
			"rail":
				var rm := mat(Color(0.3, 0.3, 0.32), 0.4, 0.7)
				for a in 4:
					var rb := box(n, Vector3(16, 0.06, 0.06), Vector3(0, 1.0, -8).rotated(Vector3.UP, a * PI / 2), rm)
					rb.rotation.y = a * PI / 2
			"palms", "plants", "pillars":
				for i in 6:
					var px := (-1.0 if i % 2 == 0 else 1.0) * rng.randf_range(4.0, 6.5)
					var pz := -8.0 + i * 2.6
					if prop == "pillars":
						cyl(n, 0.25, 0.3, 5.0, Vector3(px, 2.5, pz), mat(Color(0.5, 0.15, 0.1)))
					else:
						var th := 3.5 if prop == "palms" else 0.5
						cyl(n, 0.1, 0.16, th, Vector3(px, th * 0.5, pz), mat(Color(0.45, 0.32, 0.2)))
						ball(n, 0.9 if prop == "palms" else 0.5, Vector3(px, th + 0.3, pz), mat(Color(0.15, 0.5, 0.2)), 8).scale = Vector3(1.4, 0.6, 1.4)
			"sea":
				var sp := PlaneMesh.new()
				sp.size = Vector2(80, 30)
				add(n, sp, Vector3(0, 0.02, -27), mat(Color(0.1, 0.5, 0.75), 0.15, 0.3))
			"neon":
				for i in 8:
					var ang2 := rng.randf() * TAU
					box(n, Vector3(0.12, rng.randf_range(2, 5), 0.12), Vector3(cos(ang2) * 13, rng.randf_range(1, 4), sin(ang2) * 13), mat(Color.from_hsv(rng.randf(), 0.9, 1.0), 0.5, 0.0, 3.0))
			"stars":
				var xf3: Array = []
				for i in int(160 * few):
					var dir := Vector3(rng.randfn(0, 1), absf(rng.randfn(0, 1)) * 0.8 + 0.05, rng.randfn(0, 1)).normalized()
					xf3.append(Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.5, 1.5)), dir * 60.0))
				var sph := SphereMesh.new()
				sph.radius = 0.12
				sph.height = 0.24
				sph.radial_segments = 4
				sph.rings = 2
				_multi(n, sph, mat(Color(1, 1, 0.9), 0.5, 0.0, 3.0), xf3)
			"rain":
				var rp := CPUParticles3D.new()
				rp.amount = int(260 * few)
				rp.lifetime = 0.9
				rp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
				rp.emission_box_extents = Vector3(7, 0.1, 7)
				rp.position = Vector3(0, 7, 0)
				rp.direction = Vector3(0.1, -1, 0)
				rp.spread = 2.0
				rp.initial_velocity_min = 9.0
				rp.initial_velocity_max = 11.0
				var rmesh := BoxMesh.new()
				rmesh.size = Vector3(0.008, 0.25, 0.008)
				rp.mesh = rmesh
				rp.material_override = mat(Color(0.75, 0.85, 0.95), 0.2, 0.0, 0.0, 0.5)
				n.add_child(rp)
				box(n, Vector3(5, 0.12, 6), Vector3(0, 4.2, 0), mat(Color(0.3, 0.2, 0.15), 0.9))
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						cyl(n, 0.08, 0.08, 4.2, Vector3(sx * 2.4, 2.1, sz * 2.9), mat(Color(0.3, 0.2, 0.15)))
			"arches":
				var am := mat(col(def.wall).lightened(0.15), 0.9)
				for i in 5:
					for sx in [-1.0, 1.0]:
						box(n, Vector3(0.5, 3.4, 0.5), Vector3(sx * 7, 1.7, -8 + i * 4.0), am)
					box(n, Vector3(0.5, 0.6, 16.5), Vector3(-7 if i % 2 == 0 else 7, 3.7, 0), am)
			"ring":
				var tm := TorusMesh.new()
				tm.inner_radius = 9.0
				tm.outer_radius = 9.6
				tm.rings = 24
				tm.ring_segments = 6
				add(n, tm, Vector3(0, 3.0, 0), mat(Color(0.6, 0.65, 0.75), 0.3, 0.8)).rotation.x = 0.35
				ball(n, 7.0, Vector3(-18, 9, -40), mat(Color(0.25, 0.45, 0.85), 0.9, 0.0, 0.25), 16)
	return n
