extends RefCounted
# Design system: Montserrat, dark sporty palette with one accent, 8 px spacing scale, glass cards, motion.
const BG := Color(0.035, 0.05, 0.09)
const PANEL := Color(0.09, 0.125, 0.2, 0.82)
const ACCENT := Color(1.0, 0.36, 0.17)
const ACCENT2 := Color(0.3, 0.72, 1.0)
const GOOD := Color(0.16, 0.5, 0.36, 0.9)
const TEXT := Color(0.96, 0.97, 1.0)
const DIM := Color(0.66, 0.72, 0.84)
const S1 := 8
const S2 := 16
const S3 := 24
static var _fonts := {}

static func font(weight: int) -> Font:
	if not _fonts.has(weight):
		var path := "res://assets/fonts/montserrat-%d.woff2" % weight
		_fonts[weight] = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	return _fonts[weight]

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(500)
	t.default_font_size = 26
	return t

static func style(c: Color, radius: int = 20, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.anti_aliasing_size = 1.2
	s.set_content_margin_all(S2)
	if border.a > 0.0:
		s.set_border_width_all(3)
		s.border_color = border
	return s

# Translucent card with a hairline highlight and soft shadow.
static func glass(c: Color = PANEL, radius: int = 24) -> StyleBoxFlat:
	var s := style(c, radius)
	s.set_border_width_all(1)
	s.border_color = Color(1, 1, 1, 0.14)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	return s

static func label(text: String, size: int = 28, c: Color = TEXT, center: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(800 if size >= 40 else (700 if size >= 28 else 500)))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(text: String, cb: Callable, c: Color = PANEL, size: int = 30, min_h: int = 88) -> Button:
	var b := Button.new()
	b.text = text
	var solid := c.a > 0.95
	b.add_theme_font_override("font", font(800 if solid else 700))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	var st := glass(c, 22)
	if solid:
		# selected / primary: glow in its own colour
		st.shadow_color = Color(c.r, c.g, c.b, 0.45)
		st.shadow_size = 14
		st.border_color = Color(1, 1, 1, 0.3)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	var pr: StyleBoxFlat = st.duplicate()
	pr.bg_color = c.lightened(0.18)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(0, min_h)
	b.clip_text = true
	b.button_down.connect(func():
		b.pivot_offset = b.size * 0.5
		b.create_tween().tween_property(b, "scale", Vector2(0.95, 0.95), 0.06))
	b.button_up.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.pressed.connect(func():
		Sfx.play("select" if solid else "ui")
		cb.call())
	return b

static func panel(c: Color = PANEL, radius: int = 24) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", glass(c, radius))
	return p

static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

# A labelled 0..1 stat bar that fills up when shown.
static func bar(name: String, v: float, c: Color = ACCENT2) -> Control:
	var h := hbox(S1)
	var l := label(name, 22, DIM)
	l.custom_minimum_size.x = 120
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.value = 0.0
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 16)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.add_theme_stylebox_override("background", style(Color(0, 0, 0, 0.4), 8))
	pb.add_theme_stylebox_override("fill", style(c, 8))
	h.add_child(expand(pb))
	pb.create_tween().tween_property(pb, "value", v, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var n := label(str(int(round(v * 100.0))), 22, TEXT)
	n.custom_minimum_size.x = 44
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(n)
	return h

static func slider(v: float, lo: float, hi: float, step: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = v
	s.custom_minimum_size = Vector2(0, 60)
	s.add_theme_stylebox_override("slider", style(Color(1, 1, 1, 0.16), 6))
	s.add_theme_stylebox_override("grabber_area", style(ACCENT, 6))
	s.add_theme_stylebox_override("grabber_area_highlight", style(ACCENT, 6))
	s.value_changed.connect(cb)
	return s

# Number label that counts up to its value.
static func count_up(l: Label, to: float, fmt: String) -> void:
	l.text = fmt % 0
	l.create_tween().tween_method(func(x: float): l.text = fmt % int(x), 0.0, to, 0.6).set_ease(Tween.EASE_OUT)

# Staggered entrance: fade and rise. Nothing just pops in.
static func enter(c: Control, i: int = 0) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_interval(0.025 * mini(i, 14))
	tw.tween_property(c, "modulate:a", 1.0, 0.2)

static func safe_top(c: Control) -> float:
	var vs := c.get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if win.y <= 0.0:
		return 24.0
	return maxf(24.0, float(safe.position.y) * vs.y / win.y + 12.0)
