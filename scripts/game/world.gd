extends RefCounted
# Procedural visuals. Geometry is built from smooth high-segment primitives; materials are PBR with
# procedurally generated detail textures (paint grain, wood grain, pimpled rubber, net mesh).
const P := preload("res://scripts/core/physics.gd")
static var Q := 2  # quality: 0 low, 1 medium, 2 high, 3 ultra
static var _tex := {}

static func col(hex: String) -> Color:
	return Color.html(hex)

# ---------- textures ----------
static func tex(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var size: int = [256, 512, 1024, 2048][Q]
	if Q == 2 and kind in ["paint_n", "wood", "pimples_n"]:
		size = 2048  # the table, bats and ball are seen closest: full resolution on High too
	var t: Texture2D
	if kind == "net":
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.05, 0.05, 0.07, 0.16))
		for i in 4:
			img.fill_rect(Rect2i(i * 16, 0, 3, 64), Color(0.04, 0.04, 0.06, 0.95))
			img.fill_rect(Rect2i(0, i * 16, 64, 3), Color(0.04, 0.04, 0.06, 0.95))
		img.generate_mipmaps()
		t = ImageTexture.create_from_image(img)
	elif kind == "strip":
		var g2 := Gradient.new()
		g2.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g2.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 0.4), Color(0, 0, 0, 0)])
		var gs := GradientTexture2D.new()
		gs.gradient = g2
		gs.fill_from = Vector2(0.5, 0.0)
		gs.fill_to = Vector2(0.5, 1.0)
		gs.width = 8
		gs.height = 128
		t = gs
	elif kind == "blob":
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		t = gt
	else:
		var n := FastNoiseLite.new()
		var nt := NoiseTexture2D.new()
		nt.seamless = true
		nt.generate_mipmaps = true
		var ramp := Gradient.new()
		match kind:
			"grain", "grain_n", "paint", "paint_n":
				n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
				n.frequency = 0.035
				n.fractal_octaves = 4
				ramp.colors = PackedColorArray([Color(0.8, 0.8, 0.8), Color(1, 1, 1)])
			"wood":
				n.noise_type = FastNoiseLite.TYPE_PERLIN
				n.frequency = 0.012
				n.fractal_octaves = 4
				n.fractal_lacunarity = 2.6
				ramp.offsets = PackedFloat32Array([0.0, 0.35, 0.5, 0.65, 1.0])
				ramp.colors = PackedColorArray([Color(0.62, 0.62, 0.62), Color(0.95, 0.95, 0.95), Color(0.72, 0.72, 0.72), Color(1, 1, 1), Color(0.7, 0.7, 0.7)])
			"pimples_n":
				n.noise_type = FastNoiseLite.TYPE_CELLULAR
				n.frequency = 0.11
				n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
				n.fractal_type = FastNoiseLite.FRACTAL_NONE
		if kind.ends_with("_n"):
			nt.as_normal_map = true
			nt.bump_strength = 5.0 if kind == "pimples_n" else 1.6
		else:
			nt.color_ramp = ramp
		nt.width = size
		nt.height = size
		nt.noise = n
		t = nt
	_tex[kind] = t
	return t

# ---------- materials ----------
static func mat(c: Color, rough: float = 0.7, metal: float = 0.0, emit: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = rough
	m.metallic = metal
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

# PBR material with a tiling detail texture and matching normal map (triplanar, so any mesh works).
static func pbr(c: Color, rough: float, metal: float, detail: String, scale: Vector3, normal: String = "", nscale: float = 0.5) -> StandardMaterial3D:
	var m := mat(c, rough, metal)
	if Q == 0:
		return m
	m.uv1_triplanar = true
	m.uv1_scale = scale
	if detail != "":
		m.albedo_texture = tex(detail)
	if normal != "":
		m.normal_enabled = true
		m.normal_texture = tex(normal)
		m.normal_scale = nscale
	return m

static func wood(c: Color, rough: float = 0.6) -> StandardMaterial3D:
	return pbr(c, rough, 0.0, "wood", Vector3(1.2, 9.0, 1.2), "grain_n", 0.35)

static func metal(c: Color, rough: float = 0.32) -> StandardMaterial3D:
	return pbr(c, rough, 0.9, "", Vector3.ONE * 6.0, "grain_n", 0.15)

# ---------- primitives ----------
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

static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, m: Material, seg: int = 24) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg if Q > 0 else 12
	c.rings = 1
	return add(parent, c, pos, m)

static func ball(parent: Node3D, r: float, pos: Vector3, m: Material, seg: int = 24) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg if Q > 0 else maxi(seg / 2, 8)
	s.rings = s.radial_segments / 2
	return add(parent, s, pos, m)

static func capsule(parent: Node3D, r: float, h: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 20 if Q > 0 else 10
	c.rings = 6 if Q > 0 else 3
	return add(parent, c, pos, m)

# Soft dark blob used as contact shadow / ambient occlusion under objects.
static func blob(parent: Node3D, size: Vector2, pos: Vector3, alpha: float) -> MeshInstance3D:
	var q := PlaneMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex("blob")
	m.albedo_color = Color(1, 1, 1, alpha)
	return add(parent, q, pos, m, false)

# Faked ambient occlusion where two surfaces meet: a dark gradient that fades away from the crease.
# The strip lies on the floor, dark edge at `pos`, fading toward local +Z (turned by rot_y).
static func ao_strip(parent: Node3D, length: float, depth: float, pos: Vector3, rot_y: float, alpha: float = 0.55, upright: bool = false) -> void:
	var q := PlaneMesh.new()
	q.size = Vector2(length, depth)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex("strip")
	m.albedo_color = Color(1, 1, 1, alpha)
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = rot_y
	parent.add_child(holder)
	var mi := add(holder, q, Vector3(0, 0, depth * 0.5), m, false)
	if upright:
		mi.position = Vector3(0, depth * 0.5, 0.0)
		mi.rotation.x = PI / 2

# ---------- equipment ----------
static func game_ball(def: Dictionary, colorblind: bool, scale: float = 1.6) -> MeshInstance3D:
	var base: Color = Color(1.0, 0.92, 0.0) if colorblind else col(def.color)
	var ink: Color = Color(0.03, 0.03, 0.03) if colorblind else col(def.trail).darkened(0.45)
	if base.get_luminance() > 0.8 and not colorblind and def.trail == def.color:
		ink = Color(0.1, 0.15, 0.45)
	var img := Image.create(256, 128, false, Image.FORMAT_RGB8)
	img.fill(base)
	img.fill_rect(Rect2i(0, 62, 256, 3), base.darkened(0.18))  # seam
	for u in [20, 148]:
		img.fill_rect(Rect2i(u, 44, 60, 40), ink)  # logo block, twice around
		img.fill_rect(Rect2i(u + 5, 49, 50, 30), base)
		for k in 3:
			img.fill_rect(Rect2i(u + 10 + k * 15, 58, 9, 12), ink)
	img.fill_rect(Rect2i(96, 20, 12, 12), ink)
	img.fill_rect(Rect2i(224, 96, 12, 12), ink)
	if Q >= 2:
		img.resize(2048, 1024, Image.INTERPOLATE_NEAREST)
	img.generate_mipmaps()
	var m := mat(Color.WHITE, 0.38, 0.0)
	m.albedo_texture = ImageTexture.create_from_image(img)
	if colorblind:
		m.emission_enabled = true
		m.emission = base
		m.emission_energy_multiplier = 0.35
	var s := SphereMesh.new()
	s.radius = P.R * scale
	s.height = P.R * scale * 2.0
	s.radial_segments = 48 if Q > 0 else 20
	s.rings = 24 if Q > 0 else 10
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = m
	return mi

static func table(def: Dictionary) -> Node3D:
	var n := Node3D.new()
	var glow: float = def.glow
	var top := pbr(col(def.top), def.rough, def.metal, "paint", Vector3.ONE * 3.0, "paint_n", 0.25)
	if def.alpha < 1.0:
		top = mat(col(def.top), def.rough, def.metal, 0.0, def.alpha)
	var line := mat(col(def.line), 0.5, 0.0, glow)
	var frame := metal(col(def.frame), 0.4) if def.metal < 0.5 else metal(col(def.frame), 0.25)
	if glow > 0.0:
		frame = mat(col(def.frame), 0.4, 0.3, glow * 0.6)
	var w := P.HALF_W * 2.0
	var l := P.HALF_L * 2.0
	box(n, Vector3(w, 0.025, l), Vector3(0, P.TABLE_Y - 0.0125, 0), top)
	box(n, Vector3(w + 0.004, 0.02, l + 0.004), Vector3(0, P.TABLE_Y - 0.022, 0), mat(col(def.top).darkened(0.55), 0.6))
	var y := P.TABLE_Y + 0.0008
	for sx in [-1.0, 1.0]:
		box(n, Vector3(0.02, 0.0016, l), Vector3(sx * (P.HALF_W - 0.01), y, 0), line)
		box(n, Vector3(w, 0.0016, 0.02), Vector3(0, y, sx * (P.HALF_L - 0.01)), line)
	box(n, Vector3(0.004, 0.0016, l), Vector3(0, y, 0), line)
	# undercarriage: apron rails, legs with feet, cross braces
	for sx in [-1.0, 1.0]:
		box(n, Vector3(0.03, 0.06, l - 0.16), Vector3(sx * (P.HALF_W - 0.06), P.TABLE_Y - 0.062, 0), frame)
		for sz in [-1.0, 1.0]:
			box(n, Vector3(w - 0.12, 0.06, 0.03), Vector3(0, P.TABLE_Y - 0.062, sz * (P.HALF_L - 0.08)), frame)
			box(n, Vector3(0.045, P.TABLE_Y - 0.1, 0.045), Vector3(sx * 0.6, (P.TABLE_Y - 0.1) * 0.5 + 0.01, sz * 1.02), frame)
			cyl(n, 0.035, 0.04, 0.02, Vector3(sx * 0.6, 0.01, sz * 1.02), mat(Color(0.05, 0.05, 0.05), 0.9))
	for sz in [-1.0, 1.0]:
		box(n, Vector3(1.2, 0.03, 0.03), Vector3(0, 0.28, sz * 1.02), frame)
	# net: posts with clamps, cord, white tape and translucent mesh
	var post := metal(col(def.frame).lerp(Color(0.6, 0.62, 0.66), 0.7), 0.28)
	var nw := (P.HALF_W + P.NET_OVER) * 2.0
	for sx in [-1.0, 1.0]:
		var px: float = sx * (P.HALF_W + P.NET_OVER)
		cyl(n, 0.009, 0.009, P.NET_H + 0.02, Vector3(px, P.TABLE_Y + P.NET_H * 0.5, 0), post, 16)
		ball(n, 0.011, Vector3(px, P.TABLE_Y + P.NET_H + 0.012, 0), post, 12)
		box(n, Vector3(P.NET_OVER + 0.04, 0.022, 0.03), Vector3(sx * (P.HALF_W + P.NET_OVER * 0.5 - 0.02), P.TABLE_Y - 0.036, 0), post)
		box(n, Vector3(0.03, 0.05, 0.03), Vector3(px, P.TABLE_Y - 0.012, 0), post)
	var netm := mat(Color.WHITE, 0.9, 0.0, 0.0, 0.99)
	netm.albedo_texture = tex("net")
	netm.uv1_scale = Vector3(nw / 0.05 / 3.0, P.NET_H / 0.05 / 2.0, 1.0)
	netm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(nw, P.NET_H - 0.012)
	add(n, quad, Vector3(0, P.TABLE_Y + P.NET_H * 0.5 - 0.006, 0), netm, false)
	box(n, Vector3(nw, 0.015, 0.006), Vector3(0, P.TABLE_Y + P.NET_H - 0.0075, 0), mat(Color(0.96, 0.96, 0.96), 0.7, 0.0, glow))
	blob(n, Vector2(2.6, 4.0), Vector3(0, 0.006, 0), 0.55)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			blob(n, Vector2(0.32, 0.32), Vector3(sx * 0.6, 0.008, sz * 1.02), 0.7)
	# occlusion where the net meets the table
	for sz in [-1.0, 1.0]:
		ao_strip(n, P.HALF_W * 2.0, 0.07, Vector3(0, P.TABLE_Y + 0.0012, 0), 0.0 if sz > 0 else PI, 0.35)
	return n

static func bat(def: Dictionary) -> Node3D:
	# Blade faces +/-Z (forehand rubber on +Z), handle points down (-Y). Origin is the blade centre.
	var n := Node3D.new()
	var blade := wood(Color(0.86, 0.68, 0.42), 0.55)
	var hwood := wood(col(def.get("handle", "c89a5b")), 0.5)
	var sponge := mat(Color(0.95, 0.72, 0.25), 0.9)
	# layers: rubber, sponge, 5-ply blade, sponge, rubber - each slightly inset so the edge reads as bevelled
	var layers := [[0.0052, 0.0020, def.bh, 0.0765], [0.0034, 0.0016, "", 0.0772], [0.0, 0.0052, "w", 0.078], [-0.0034, 0.0016, "", 0.0772], [-0.0052, 0.0020, def.fh, 0.0765]]
	for L in layers:
		var m: Material = blade if L[2] == "w" else sponge
		if L[2] != "w" and L[2] != "":
			m = pbr(col(L[2]), 0.82, 0.0, "", Vector3.ONE * 26.0, "pimples_n", 0.9)
		var c := cyl(n, L[3], L[3], L[1], Vector3(0, 0.004, -L[0]), m, 56)
		c.rotation.x = PI / 2
		c.scale = Vector3(1, 1, 1.07)
	var shape: int = int(def.get("shape", 0))
	var hl := 0.062 if shape == 2 else 0.1
	# throat wedge blending the blade into the handle
	var th := cyl(n, 0.03, 0.017, 0.04, Vector3(0, -0.085, 0), blade, 20)
	th.scale = Vector3(1, 1, 0.19)
	for sz in [-1.0, 1.0]:
		var grip := cyl(n, 0.0145, 0.0185 if shape == 1 else (0.0165 if shape == 2 else 0.0145), hl, Vector3(0, -0.1 - hl * 0.5, sz * 0.0048), hwood, 20)
		grip.scale = Vector3(1, 1, 0.5)
	var cap := ball(n, 0.0185 if shape == 1 else 0.0148, Vector3(0, -0.1 - hl, 0), hwood, 16)
	cap.scale = Vector3(1, 0.45, 0.72)
	box(n, Vector3(0.012, 0.02, 0.0005), Vector3(0, -0.125, 0.0125), mat(Color(0.85, 0.85, 0.9), 0.3, 0.8))
	return n

# ---------- characters ----------
# Jointed figure facing +Z. Use pose() every frame to animate it.
static func character(look: Dictionary, bat_def: Dictionary, hand: float) -> Node3D:
	var n := Node3D.new()
	var skin := mat(col(look.skin), 0.65)
	var shirt := pbr(col(look.shirt), 0.85, 0.0, "grain", Vector3.ONE * 9.0, "grain_n", 0.5)
	var shorts := mat(col(look.shorts), 0.85)
	var hair := mat(col(look.hair), 0.75)
	var shoe := mat(Color(0.94, 0.94, 0.96), 0.5)
	var parts := {}
	var hips := Node3D.new()
	hips.position = Vector3(0, 0.86, 0)
	n.add_child(hips)
	parts.hips = hips
	for sx in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.1, 0.0, 0)
		hips.add_child(hip)
		capsule(hip, 0.068, 0.46, Vector3(0, -0.2, 0), shorts if true else skin)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.42, 0)
		hip.add_child(knee)
		capsule(knee, 0.05, 0.44, Vector3(0, -0.2, 0), skin)
		var foot := capsule(knee, 0.048, 0.24, Vector3(0, -0.42, 0.06), shoe)
		foot.rotation.x = PI / 2
		parts["hip%d" % int(sx)] = hip
		parts["knee%d" % int(sx)] = knee
	var torso := Node3D.new()
	hips.add_child(torso)
	parts.torso = torso
	capsule(torso, 0.155, 0.3, Vector3(0, 0.03, 0), shorts).scale = Vector3(1.05, 1, 0.8)
	capsule(torso, 0.165, 0.56, Vector3(0, 0.3, 0), shirt).scale = Vector3(1.08, 1, 0.78)
	box(torso, Vector3(0.2, 0.012, 0.004), Vector3(0, 0.38, 0.13), mat(col(look.shirt).lightened(0.45), 0.8))
	cyl(torso, 0.05, 0.055, 0.08, Vector3(0, 0.6, 0), skin, 16)
	var head := Node3D.new()
	head.position = Vector3(0, 0.74, 0)
	torso.add_child(head)
	parts.head = head
	ball(head, 0.115, Vector3.ZERO, skin, 32).scale = Vector3(0.94, 1.08, 1.0)
	for sx in [-1.0, 1.0]:
		ball(head, 0.016, Vector3(sx * 0.042, 0.015, 0.1), mat(Color(0.06, 0.05, 0.05), 0.3), 10)
		ball(head, 0.022, Vector3(sx * 0.108, 0.0, 0.0), skin, 10)
	match int(look.hs):
		0:
			ball(head, 0.12, Vector3(0, 0.04, -0.04), hair, 28).scale = Vector3(0.98, 0.92, 1.0)
		1:
			ball(head, 0.118, Vector3(0, 0.045, -0.04), hair, 28).scale = Vector3(0.98, 0.9, 1.0)
			ball(head, 0.06, Vector3(0, 0.15, -0.04), hair, 16)
		2:
			ball(head, 0.128, Vector3(0, 0.02, -0.035), hair, 28).scale = Vector3(1.0, 1.12, 0.95)
			capsule(head, 0.05, 0.3, Vector3(0, -0.12, -0.12), hair)
		_:
			ball(head, 0.118, Vector3(0, 0.04, -0.02), hair, 28).scale = Vector3(0.7, 0.95, 1.05)
	match look.acc:
		"band":
			cyl(head, 0.117, 0.117, 0.028, Vector3(0, 0.045, 0), mat(Color(0.95, 0.95, 0.95), 0.8), 28).scale = Vector3(0.95, 1, 1.01)
		"cap":
			ball(head, 0.122, Vector3(0, 0.04, 0), mat(col(look.shirt).darkened(0.2), 0.8), 28).scale = Vector3(0.98, 0.8, 1.02)
			cyl(head, 0.09, 0.09, 0.012, Vector3(0, 0.05, 0.12), mat(col(look.shirt).darkened(0.2), 0.8), 20)
		"glasses":
			for sx in [-1.0, 1.0]:
				cyl(head, 0.03, 0.03, 0.008, Vector3(sx * 0.044, 0.015, 0.105), mat(Color(0.05, 0.05, 0.08), 0.15, 0.4), 16).rotation.x = PI / 2
			box(head, Vector3(0.03, 0.006, 0.006), Vector3(0, 0.02, 0.108), mat(Color(0.05, 0.05, 0.08), 0.2))
	# arms: shoulder -> upper arm -> elbow -> forearm -> hand (+ bat in the playing hand)
	for sx in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(sx * 0.2, 0.5, 0)
		torso.add_child(sh)
		ball(sh, 0.062, Vector3.ZERO, shirt, 16)
		capsule(sh, 0.045, 0.3, Vector3(0, -0.14, 0), skin)
		var el := Node3D.new()
		el.position = Vector3(0, -0.28, 0)
		sh.add_child(el)
		capsule(el, 0.038, 0.28, Vector3(0, -0.13, 0), skin)
		ball(el, 0.045, Vector3(0, -0.27, 0), skin, 12)
		if sx == hand:
			var b := bat(bat_def)
			b.position = Vector3(0, -0.4, 0.0)
			b.rotation = Vector3(PI, 0, 0)
			el.add_child(b)
			parts.sh = sh
			parts.el = el
		else:
			parts.sh2 = sh
			parts.el2 = el
	blob(n, Vector2(0.9, 0.9), Vector3(0, 0.005, 0), 0.6)
	n.set_meta("p", parts)
	n.set_meta("hand", hand)
	return n

# kind -> [backswing, follow-through], each [shoulder pitch, shoulder roll, elbow bend, torso twist]
const POSES := {
	"ready": [[-0.55, 0.25, 1.35, 0.0], [-0.55, 0.25, 1.35, 0.0]],
	"drive": [[0.25, 0.75, 1.0, 0.55], [-1.75, -0.45, 1.5, -0.5]],
	"rally": [[0.1, 0.65, 1.1, 0.4], [-1.5, -0.35, 1.5, -0.4]],
	"loop": [[0.75, 0.55, 0.35, 0.7], [-2.35, -0.3, 1.25, -0.6]],
	"smash": [[-2.7, 0.6, 1.2, 0.6], [-0.5, -0.6, 0.5, -0.7]],
	"push": [[-0.95, 0.2, 1.7, 0.1], [-0.85, 0.05, 0.6, -0.1]],
	"touch": [[-0.8, 0.2, 1.5, 0.05], [-1.0, 0.05, 0.9, -0.1]],
	"block": [[-0.8, 0.2, 1.5, 0.0], [-1.0, 0.1, 1.2, -0.05]],
	"chop": [[-2.0, 0.45, 1.6, 0.4], [-0.35, 0.0, 0.3, -0.25]],
	"serve": [[-0.3, 0.9, 1.5, 0.5], [-1.2, -0.5, 1.2, -0.35]],
}

# prep 0..1 = backswing readiness, swing 1..0 = time since contact (1 at contact), move = sideways speed,
# t = clock, toss 0..1 raises the free arm for a serve.
static func pose(ch: Node3D, kind: String, prep: float, swing: float, move: float, t: float, toss: float = 0.0) -> void:
	var p: Dictionary = ch.get_meta("p")
	var hand: float = ch.get_meta("hand")
	var ps: Array = POSES.get(kind, POSES.drive)
	var rd: Array = POSES.ready[0]
	var cur: Array = [0.0, 0.0, 0.0, 0.0]
	var f := 1.0 - swing  # 0 at contact -> 1 when finished
	for i in 4:
		var back: float = lerpf(rd[i], ps[0][i], smoothstep(0.0, 1.0, prep))
		if swing > 0.0:
			# whip from backswing through contact into the follow-through, then settle
			var through: float = lerpf(ps[0][i], ps[1][i], smoothstep(0.0, 0.45, f))
			cur[i] = lerpf(through, rd[i], smoothstep(0.6, 1.0, f))
		else:
			cur[i] = back
	var bob := sin(t * 5.0) * 0.012 + absf(move) * 0.01
	var crouch := 0.32 + bob * 2.0 + prep * 0.1
	p.hips.position.y = 0.86 - 0.06 - prep * 0.03 + bob
	p.torso.rotation = Vector3(0.3 + prep * 0.08, cur[3] * hand, -clampf(move, -1.0, 1.0) * 0.12)
	p.head.rotation = Vector3(-0.25, -cur[3] * hand * 0.7, 0)
	p.sh.rotation = Vector3(cur[0], 0.0, cur[1] * hand)
	p.el.rotation = Vector3(-cur[2], 0.0, 0.0)
	p.sh2.rotation = Vector3(lerpf(-0.45, -2.6, toss), 0.0, -hand * lerpf(0.3, 0.1, toss))
	p.el2.rotation = Vector3(lerpf(-1.2, -0.2, toss), 0.0, 0.0)
	for sx in [-1.0, 1.0]:
		var stride := sin(t * 11.0 + (0.0 if sx < 0.0 else PI)) * clampf(absf(move), 0.0, 1.0) * 0.25
		p["hip%d" % int(sx)].rotation = Vector3(-crouch + stride * 0.3, 0.0, sx * 0.16 - move * 0.1 + stride * signf(move) * 0.5)
		p["knee%d" % int(sx)].rotation = Vector3(crouch * 1.7, 0.0, 0.0)

static func machine() -> Node3D:
	var n := Node3D.new()
	var m := metal(Color(0.22, 0.26, 0.34), 0.35)
	box(n, Vector3(0.4, 0.3, 0.4), Vector3(0, P.TABLE_Y + 0.25, 0), m)
	cyl(n, 0.03, 0.03, 0.9, Vector3(0, 0.45, 0), m)
	cyl(n, 0.2, 0.25, 0.04, Vector3(0, 0.02, 0), m)
	cyl(n, 0.05, 0.055, 0.3, Vector3(0, P.TABLE_Y + 0.3, 0.25), mat(Color(0.95, 0.5, 0.1), 0.35, 0.3)).rotation.x = PI / 2
	cyl(n, 0.16, 0.2, 0.18, Vector3(0, P.TABLE_Y + 0.5, -0.05), mat(Color(0.9, 0.9, 0.95), 0.15, 0.0, 0.0, 0.35))
	return n

static func _multi(parent: Node3D, mesh: Mesh, m: Material, xforms: Array, colors: Array = []) -> MultiMeshInstance3D:
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
	return mi

const CROWD_SHADER := "shader_type spatial;
render_mode specular_disabled;
uniform float excite = 0.0;
varying vec3 tint;
void vertex() {
	float ph = float(INSTANCE_ID) * 1.713;
	float amp = 0.015 + excite * (0.06 + 0.1 * fract(ph * 0.37));
	VERTEX.y += abs(sin(TIME * (1.6 + excite * 6.0) + ph)) * amp + excite * 0.05 * step(0.6, fract(ph * 0.61));
	VERTEX.x += sin(TIME * 0.9 + ph) * 0.012;
	tint = COLOR.rgb;
}
void fragment() {
	ALBEDO = tint * 0.42;
	ROUGHNESS = 1.0;
}"

static func _light(parent: Node3D, pos: Vector3, c: Color, energy: float, rng_: float, spot: bool = false) -> void:
	if Q == 0:
		return
	var l: Light3D
	if spot:
		var s := SpotLight3D.new()
		s.spot_range = rng_
		s.spot_angle = 38.0
		s.spot_attenuation = 0.8
		l = s
	else:
		var o := OmniLight3D.new()
		o.omni_range = rng_
		l = o
	l.light_color = c
	l.light_energy = energy
	l.position = pos
	parent.add_child(l)
	if spot:
		l.look_at_from_position(pos, Vector3(0, 0.76, 0))

# Environment, lights, floor and data-driven props. meta "crowd" = crowd ShaderMaterial (or null).
static func arena(def: Dictionary) -> Node3D:
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
	sm.sun_angle_max = 8.0 if open and not props.has("stars") else 0.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = col(def.light).lerp(col(def.sky_top), 0.35)
	env.ambient_light_energy = def.ambient
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.tonemap_exposure = 1.15
	if Q >= 1 and def.get("fog", 0.0) > 0.0:
		env.fog_enabled = true
		env.fog_light_color = col(def.sky_bot).lerp(col(def.wall), 0.5)
		env.fog_density = def.fog
		env.fog_sky_affect = 0.2
	if Q >= 2:
		env.glow_enabled = true
		env.glow_intensity = 0.55
		env.glow_bloom = 0.08
		env.glow_hdr_threshold = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	n.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = col(def.light)
	sun.light_energy = def.energy
	var sa: Array = def.get("sun", [-1.05, 0.5])
	sun.rotation = Vector3(sa[0], sa[1], 0)
	sun.shadow_enabled = Q >= 2
	sun.shadow_blur = 2.2 if Q == 2 else 2.8
	sun.shadow_opacity = 0.62
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if Q == 3 else DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 14.0
	n.add_child(sun)
	var gloss: float = maxf(def.get("gloss", 0.8), 0.5)
	var floor_m := pbr(col(def.floor), gloss, 0.0, "grain", Vector3.ONE * 0.35, "grain_n", 0.12)
	if props.has("lines") or def.id == "dojo":
		floor_m = pbr(col(def.floor), gloss, 0.0, "wood", Vector3(1.1, 1.1, 0.16), "grain_n", 0.2)
	var pl := PlaneMesh.new()
	pl.size = Vector2(60, 60)
	add(n, pl, Vector3.ZERO, floor_m)
	var wall := pbr(col(def.wall).lightened(0.12), 0.9, 0.0, "grain", Vector3.ONE * 0.3, "grain_n", 0.2)
	if not open:
		for a in 4:
			var wbox := box(n, Vector3(24, 8, 0.3), Vector3(0, 4.0, -12).rotated(Vector3.UP, a * PI / 2), wall)
			wbox.rotation.y = a * PI / 2
			wbox.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# occlusion in the wall/floor crease and up the wall
			ao_strip(n, 24.0, 2.2, Vector3(0, 0.004, -11.84).rotated(Vector3.UP, a * PI / 2), a * PI / 2, 0.6)
			ao_strip(n, 24.0, 1.6, Vector3(0, 0.0, -11.83).rotated(Vector3.UP, a * PI / 2), a * PI / 2, 0.45, true)
			var band := box(n, Vector3(24, 0.5, 0.32), Vector3(0, 2.6, -11.99).rotated(Vector3.UP, a * PI / 2), mat(col(def.light).lerp(col(def.wall), 0.55), 0.6, 0.0, 0.25))
			band.rotation.y = a * PI / 2
		box(n, Vector3(24, 0.3, 24), Vector3(0, 8.1, 0), mat(col(def.wall).darkened(0.2), 0.95)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if Q >= 2:
		var probe := ReflectionProbe.new()
		probe.position = Vector3(0, 1.6, 0)
		probe.size = Vector3(22, 8, 22)
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.intensity = 0.7
		n.add_child(probe)
	var few: float = [0.4, 0.7, 1.0, 1.3][Q]
	var crowd_mat: ShaderMaterial = null
	var lc := col(def.light)
	for prop in props:
		match prop:
			"barriers":
				var bm := mat(col(def.wall).lerp(Color(0.08, 0.2, 0.55), 0.7), 0.55)
				var trim := mat(Color(0.95, 0.95, 0.95), 0.6)
				for sx in [-1.0, 1.0]:
					for i in 7:
						box(n, Vector3(0.05, 0.72, 1.36), Vector3(sx * 3.5, 0.37, -4.2 + i * 1.4), bm)
						box(n, Vector3(0.052, 0.05, 1.36), Vector3(sx * 3.5, 0.73, -4.2 + i * 1.4), trim)
				for sx in [-1.0, 1.0]:
					ao_strip(n, 9.8, 0.5, Vector3(sx * 3.47, 0.004, 0), PI / 2 * sx, 0.6)
					ao_strip(n, 9.8, 0.5, Vector3(sx * 3.53, 0.004, 0), -PI / 2 * sx, 0.6)
				ao_strip(n, 7.0, 0.5, Vector3(0, 0.004, -5.17), 0.0, 0.6)
				for i in 5:
					box(n, Vector3(1.36, 0.72, 0.05), Vector3(-2.8 + i * 1.4, 0.37, -5.2), bm)
					box(n, Vector3(1.36, 0.05, 0.052), Vector3(-2.8 + i * 1.4, 0.73, -5.2), trim)
			"crowd", "bleachers":
				var xf: Array = []
				var cs: Array = []
				var rows := 7 if prop == "crowd" else 3
				var step_m := mat(col(def.wall).lightened(0.06), 0.95)
				for sx in [-1.0, 1.0]:
					ao_strip(n, 14.0, 1.0, Vector3(sx * 4.2, 0.004, -1), PI / 2 * sx, 0.6)
					for r in rows:
						box(n, Vector3(1.0, 0.5 + r * 0.45, 14), Vector3(sx * (4.7 + r), (0.5 + r * 0.45) * 0.5, -1), step_m)
						for i in int(26 * few):
							if rng.randf() < (0.93 if prop == "crowd" else 0.4):
								xf.append(Transform3D(Basis().scaled(Vector3(1, rng.randf_range(0.9, 1.2), 1)), Vector3(sx * (4.7 + r), 0.86 + r * 0.45, -7.8 + i * 0.53 / few)))
								cs.append(Color.from_hsv(rng.randf(), 0.5, 0.9))
				if prop == "crowd":
					for r in 5:
						box(n, Vector3(16, 0.5 + r * 0.45, 1.0), Vector3(0, (0.5 + r * 0.45) * 0.5, -7.2 - r), step_m)
						for i in int(30 * few):
							if rng.randf() < 0.93:
								xf.append(Transform3D(Basis().scaled(Vector3(1, rng.randf_range(0.9, 1.2), 1)), Vector3(-7.8 + i * 0.53 / few, 0.86 + r * 0.45, -7.2 - r)))
								cs.append(Color.from_hsv(rng.randf(), 0.5, 0.9))
				var cap := CapsuleMesh.new()
				cap.radius = 0.17
				cap.height = 0.74
				cap.radial_segments = 10 if Q > 0 else 6
				cap.rings = 3
				crowd_mat = ShaderMaterial.new()
				var shd := Shader.new()
				shd.code = CROWD_SHADER
				crowd_mat.shader = shd
				_multi(n, cap, crowd_mat, xf, cs)
			"spots":
				for pt in [Vector3(-3.2, 6.2, -3.5), Vector3(3.2, 6.2, -3.5), Vector3(-3.2, 6.2, 3.5), Vector3(3.2, 6.2, 3.5)]:
					ball(n, 0.2, pt, mat(lc, 0.4, 0.0, 5.0), 12)
					cyl(n, 0.22, 0.26, 0.3, pt + Vector3(0, 0.12, 0), mat(Color(0.08, 0.08, 0.1), 0.5, 0.6), 14)
					_light(n, pt, lc, 2.6, 13.0, true)
			"lamp":
				cyl(n, 0.01, 0.01, 5.0, Vector3(0, 5.4, 0), mat(Color(0.05, 0.05, 0.05)), 6)
				cyl(n, 0.1, 0.42, 0.25, Vector3(0, 2.95, 0), metal(Color(0.2, 0.3, 0.25), 0.4), 24)
				ball(n, 0.09, Vector3(0, 2.84, 0), mat(Color(1.0, 0.85, 0.6), 0.4, 0.0, 6.0), 12)
				_light(n, Vector3(0, 2.75, 0), Color(1.0, 0.82, 0.58), 5.5, 9.0)
			"lanterns":
				for pt in [Vector3(-2.6, 2.3, -4), Vector3(2.6, 2.3, -4), Vector3(-2.6, 2.3, 1.5), Vector3(2.6, 2.3, 1.5)]:
					cyl(n, 0.16, 0.16, 0.34, pt, mat(Color(1.0, 0.5, 0.18), 0.5, 0.0, 2.6), 16)
					cyl(n, 0.18, 0.18, 0.03, pt + Vector3(0, 0.18, 0), mat(Color(0.1, 0.05, 0.03)), 16)
					_light(n, pt, Color(1.0, 0.6, 0.3), 2.2, 7.0)
			"shelves":
				for i in 4:
					box(n, Vector3(3, 0.05, 0.5), Vector3(-4, 0.6 + i * 0.6, -6.5), wood(Color(0.4, 0.28, 0.17)))
					for j in 5:
						box(n, Vector3(0.35, 0.3, 0.35), Vector3(-5.2 + j * 0.6, 0.78 + i * 0.6, -6.5), mat(Color.from_hsv(rng.randf(), 0.45, 0.55), 0.8))
				for sx in [-1.0, 1.0]:
					box(n, Vector3(0.06, 2.5, 0.5), Vector3(-4 + sx * 1.5, 1.25, -6.5), metal(Color(0.3, 0.3, 0.32)))
				box(n, Vector3(4.6, 2.7, 0.08), Vector3(3.5, 1.35, -11.7), metal(Color(0.7, 0.7, 0.74), 0.45))
				for i in 6:
					box(n, Vector3(4.6, 0.03, 0.1), Vector3(3.5, 0.25 + i * 0.45, -11.66), metal(Color(0.5, 0.5, 0.54), 0.5))
			"lines":
				var lnm := mat(Color(0.95, 0.95, 0.9), 0.5)
				for i in 5:
					box(n, Vector3(20, 0.003, 0.06), Vector3(0, 0.002, -8 + i * 4.0), lnm)
				for sx in [-1.0, 1.0]:
					box(n, Vector3(0.1, 3.0, 1.8), Vector3(sx * 11.7, 3.2, -4), mat(Color(0.95, 0.95, 0.95), 0.6))
					cyl(n, 0.23, 0.23, 0.02, Vector3(sx * 11.2, 3.05, -4), mat(Color(0.9, 0.35, 0.1), 0.6), 20)
			"tables":
				var tdef := {top = "1f4fa3", line = "ffffff", frame = "1b1b1b", rough = 0.6, metal = 0.0, alpha = 1.0, glow = 0.0}
				for sx in [-1.0, 1.0]:
					var t := table(tdef)
					t.position = Vector3(sx * 6.0, 0, -4.5)
					n.add_child(t)
			"skyline", "panels":
				var xf2: Array = []
				var cs2: Array = []
				for i in int(50 * few):
					var ang := rng.randf() * TAU
					var h := rng.randf_range(5, 26) if prop == "skyline" else rng.randf_range(1, 3)
					var dist := rng.randf_range(18, 30) if prop == "skyline" else 11.6
					var bpos := Vector3(cos(ang) * dist, h * 0.5 - (7.0 if prop == "skyline" else -1.0), sin(ang) * dist)
					xf2.append(Transform3D(Basis(Vector3.UP, -ang).scaled(Vector3(rng.randf_range(2, 4.5), h, rng.randf_range(2, 4.5)) if prop == "skyline" else Vector3(0.2, h, 1.2)), bpos))
					cs2.append(Color.from_hsv(rng.randf_range(0.55, 0.7), 0.3, rng.randf_range(0.2, 0.5)))
				var bm2 := mat(Color.WHITE, 0.5, 0.2)
				bm2.vertex_color_use_as_albedo = true
				if prop == "panels" or def.id == "night_city":
					bm2.emission_enabled = true
					bm2.emission = Color(0.3, 0.42, 0.9)
					bm2.emission_energy_multiplier = 0.7
				_multi(n, BoxMesh.new(), bm2, xf2, cs2)
			"rail":
				var rm := metal(Color(0.32, 0.32, 0.35), 0.35)
				for a in 4:
					for hy in [0.55, 1.05]:
						var rb := box(n, Vector3(18, 0.05, 0.05), Vector3(0, hy, -9).rotated(Vector3.UP, a * PI / 2), rm)
						rb.rotation.y = a * PI / 2
					for i in 9:
						cyl(n, 0.025, 0.025, 1.05, Vector3(-9 + i * 2.25, 0.52, -9).rotated(Vector3.UP, a * PI / 2), rm, 8)
				box(n, Vector3(2.2, 1.4, 2.2), Vector3(-6, 0.7, -6), metal(Color(0.55, 0.57, 0.6), 0.5))
			"palms", "plants", "pillars":
				for i in 6:
					var px := (-1.0 if i % 2 == 0 else 1.0) * rng.randf_range(4.2, 6.5)
					var pz := -9.0 + i * 2.8
					if prop == "pillars":
						cyl(n, 0.26, 0.3, 5.6, Vector3(px, 2.8, pz), wood(Color(0.55, 0.14, 0.1), 0.5), 24)
						box(n, Vector3(0.8, 0.2, 0.8), Vector3(px, 0.1, pz), mat(Color(0.3, 0.3, 0.3), 0.9))
					elif prop == "palms":
						for k in 6:
							cyl(n, 0.11 - k * 0.008, 0.125 - k * 0.008, 0.7, Vector3(px + k * k * 0.02, 0.35 + k * 0.66, pz), wood(Color(0.5, 0.36, 0.22)), 12).rotation.z = -k * 0.04
						for k in 7:
							var leaf := capsule(n, 0.12, 1.9, Vector3(px + 0.72, 4.15, pz), mat(Color(0.12, 0.45, 0.18), 0.7))
							leaf.scale = Vector3(1.0, 1.0, 0.12)
							leaf.rotation = Vector3(0.0, k * TAU / 7.0, 1.15)
							leaf.position += Vector3(cos(-k * TAU / 7.0), -0.25, sin(-k * TAU / 7.0)) * 0.8
					else:
						cyl(n, 0.28, 0.2, 0.45, Vector3(px, 0.22, pz), mat(Color(0.55, 0.3, 0.2), 0.9), 16)
						for k in 4:
							ball(n, 0.36, Vector3(px + rng.randf_range(-0.2, 0.2), 0.75 + k * 0.22, pz + rng.randf_range(-0.2, 0.2)), mat(Color(0.12, 0.42 + k * 0.04, 0.18), 0.8), 12)
			"sea":
				var sp := PlaneMesh.new()
				sp.size = Vector2(120, 40)
				add(n, sp, Vector3(0, 0.02, -34), mat(Color(0.06, 0.42, 0.62), 0.08, 0.2))
				add(n, sp, Vector3(0, 0.03, -14.2), mat(Color(0.9, 0.95, 0.95), 0.4, 0.0, 0.0, 0.5)).scale = Vector3(1, 1, 0.012)
			"neon":
				for i in 8:
					var ang2 := rng.randf() * TAU
					var nc := Color.from_hsv(rng.randf(), 0.9, 1.0)
					var np := Vector3(cos(ang2) * 12, rng.randf_range(1.5, 4), sin(ang2) * 12)
					box(n, Vector3(0.1, rng.randf_range(2, 5), 0.1), np, mat(nc, 0.5, 0.0, 4.0))
					if i < 4:
						_light(n, np.lerp(Vector3(0, 2, 0), 0.5), nc, 2.5, 10.0)
			"stars":
				var xf3: Array = []
				for i in int(180 * few):
					var dir := Vector3(rng.randfn(0, 1), absf(rng.randfn(0, 1)) * 0.8 + 0.05, rng.randfn(0, 1)).normalized()
					xf3.append(Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.4, 1.4)), dir * 70.0))
				var sph := SphereMesh.new()
				sph.radius = 0.12
				sph.height = 0.24
				sph.radial_segments = 6
				sph.rings = 3
				_multi(n, sph, mat(Color(1, 1, 0.92), 0.5, 0.0, 4.0), xf3)
			"rain":
				var rp := CPUParticles3D.new()
				rp.amount = int(300 * few)
				rp.lifetime = 0.9
				rp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
				rp.emission_box_extents = Vector3(8, 0.1, 8)
				rp.position = Vector3(0, 7, 0)
				rp.direction = Vector3(0.1, -1, 0)
				rp.spread = 2.0
				rp.initial_velocity_min = 9.0
				rp.initial_velocity_max = 11.0
				var rmesh := BoxMesh.new()
				rmesh.size = Vector3(0.006, 0.28, 0.006)
				rp.mesh = rmesh
				rp.material_override = mat(Color(0.75, 0.85, 0.95), 0.2, 0.0, 0.0, 0.45)
				n.add_child(rp)
				box(n, Vector3(5.4, 0.12, 6.6), Vector3(0, 4.3, 0), wood(Color(0.32, 0.2, 0.13), 0.7))
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						cyl(n, 0.09, 0.1, 4.3, Vector3(sx * 2.5, 2.15, sz * 3.1), wood(Color(0.32, 0.2, 0.13), 0.7), 16)
				_light(n, Vector3(0, 3.9, 0), Color(1.0, 0.85, 0.6), 3.0, 8.0)
			"arches":
				var am := pbr(col(def.wall).lightened(0.15), 0.9, 0.0, "grain", Vector3.ONE * 0.8, "grain_n", 0.6)
				for i in 5:
					for sx in [-1.0, 1.0]:
						box(n, Vector3(0.55, 3.4, 0.55), Vector3(sx * 7, 1.7, -8 + i * 4.0), am)
				for sx in [-1.0, 1.0]:
					box(n, Vector3(0.6, 0.7, 17), Vector3(sx * 7, 3.75, 0), am)
			"ring":
				var tm := TorusMesh.new()
				tm.inner_radius = 9.0
				tm.outer_radius = 9.7
				tm.rings = 64
				tm.ring_segments = 16
				add(n, tm, Vector3(0, 3.0, 0), metal(Color(0.62, 0.66, 0.76), 0.3)).rotation.x = 0.35
				ball(n, 9.0, Vector3(-22, 10, -48), mat(Color(0.2, 0.42, 0.85), 0.9, 0.0, 0.3), 48)
				_light(n, Vector3(0, 5, 0), Color(0.7, 0.85, 1.0), 2.0, 12.0)
	n.set_meta("crowd", crowd_mat)
	n.set_meta("env", env)
	return n
