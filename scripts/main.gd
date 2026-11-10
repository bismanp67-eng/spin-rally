extends Node
func _ready() -> void:
	var l := Label.new()
	l.text = "SPIN RALLY"
	l.add_theme_font_size_override("font_size", 72)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(l)
