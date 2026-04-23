extends PanelContainer

@export var label_text: String = "CHIP"
@export var tooltip_text_custom: String = ""
@export var tooltip_bg_color: Color = Color(0.2, 0.2, 0.2, 1.0)
@export var tooltip_border_color: Color = Color(1, 1, 1, 1)
@export var tooltip_text_color: Color = Color(1, 1, 1, 1)
@export var chip_bg_color: Color = Color(0.3, 0.3, 0.3, 1.0)

@onready var label: Label = $MarginContainer/Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = tooltip_text_custom

	if theme == null:
		theme = Theme.new()
	else:
		theme = theme.duplicate()

	theme.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())

	var style := StyleBoxFlat.new()
	style.bg_color = chip_bg_color
	style.border_color = chip_bg_color.lightened(0.15)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style)

	if label != null:
		label.text = label_text
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("outline_size", 2)

func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty():
		return null

	var root := MarginContainer.new()
	root.custom_minimum_size = Vector2(220, 0)
	root.add_theme_constant_override("margin_left", 0)
	root.add_theme_constant_override("margin_right", 0)
	root.add_theme_constant_override("margin_top", 0)
	root.add_theme_constant_override("margin_bottom", 0)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = tooltip_bg_color
	panel_style.border_color = tooltip_border_color
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)

	var tooltip_label := Label.new()
	tooltip_label.text = for_text
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tooltip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tooltip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip_label.custom_minimum_size = Vector2(180, 0)
	tooltip_label.add_theme_font_size_override("font_size", 13)
	tooltip_label.add_theme_color_override("font_color", tooltip_text_color)
	tooltip_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	tooltip_label.add_theme_constant_override("outline_size", 2)

	root.add_child(panel)
	panel.add_child(margin)
	margin.add_child(tooltip_label)

	return root
