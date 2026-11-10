extends RefCounted
# Small helpers for building the UI in code.
const BG := Color(0.05, 0.07, 0.12)
const PANEL := Color(0.11, 0.15, 0.24)
const ACCENT := Color(0.95, 0.35, 0.25)
const ACCENT2 := Color(0.2, 0.65, 0.95)
const TEXT := Color(0.95, 0.96, 1.0)
const DIM := Color(0.65, 0.7, 0.8)

static func style(c: Color, radius: int = 18, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(14)
	if border.a > 0.0:
		s.set_border_width_all(3)
		s.border_color = border
	return s

static func label(text: String, size: int = 28, c: Color = TEXT, center: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(text: String, cb: Callable, c: Color = PANEL, size: int = 30, min_h: int = 84) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_stylebox_override("normal", style(c))
	b.add_theme_stylebox_override("hover", style(c.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", style(c.lightened(0.2)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(0, min_h)
	b.clip_text = true
	b.pressed.connect(func():
		Sfx.play("ui")
		cb.call())
	return b

static func panel(c: Color = PANEL, radius: int = 22) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(c, radius))
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

# A labelled 0..1 stat bar.
static func bar(name: String, v: float, c: Color = ACCENT2) -> Control:
	var h := hbox(8)
	var l := label(name, 22, DIM)
	l.custom_minimum_size.x = 110
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.value = v
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 18)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.add_theme_stylebox_override("background", style(Color(0, 0, 0, 0.35), 8))
	pb.add_theme_stylebox_override("fill", style(c, 8))
	h.add_child(expand(pb))
	return h

static func slider(v: float, lo: float, hi: float, step: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = v
	s.custom_minimum_size = Vector2(0, 56)
	s.value_changed.connect(cb)
	return s
