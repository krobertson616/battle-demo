extends Button

var item_data: ItemData = null
var source_type: String = ""
var source_index: int = -1

var panel: PanelContainer
var margin: MarginContainer
var vbox: VBoxContainer
var name_label: Label
var description_label: Label
var cost_label: Label

func setup(item: ItemData, p_source_type: String = "", p_source_index: int = -1) -> void:
	item_data = item
	source_type = p_source_type
	source_index = p_source_index

	if is_node_ready():
		_refresh_ui()

func _ready() -> void:
	flat = true
	text = ""
	custom_minimum_size = Vector2(150, 180)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_ui()
	_refresh_ui()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0
	add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.88)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.35, 0.35, 0.35, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 8
	margin.offset_top = 8
	margin.offset_right = -8
	margin.offset_bottom = -8
	panel.add_child(margin)

	vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	name_label = Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	description_label = Label.new()
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	description_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(description_label)

	cost_label = Label.new()
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(cost_label)

func _refresh_ui() -> void:
	if item_data == null:
		return

	name_label.text = item_data.display_name
	description_label.text = item_data.description
	cost_label.text = ""

func _get_drag_data(_at_position: Vector2):
	if source_type != "hand":
		return null

	if is_instance_valid(GameState.sell_strip_ref):
		GameState.sell_strip_ref.enable_drop_zone()

	var preview_root := Control.new()
	preview_root.custom_minimum_size = Vector2(1, 1)
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview_card := _build_drag_preview()
	preview_card.position = Vector2(-75, -90)

	preview_root.add_child(preview_card)
	set_drag_preview(preview_root)

	return {
		"source_type": "hand",
		"source_index": source_index,
		"card_type": "instinct",
		"item": item_data
	}

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		if is_instance_valid(GameState.sell_strip_ref):
			GameState.sell_strip_ref.disable_drop_zone()

func _build_drag_preview() -> Control:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(150, 180)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.88)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.35, 0.35, 0.35, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	root.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 8
	margin.offset_top = 8
	margin.offset_right = -8
	margin.offset_bottom = -8
	root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var preview_name := Label.new()
	preview_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	preview_name.add_theme_font_size_override("font_size", 18)
	preview_name.text = item_data.display_name
	vbox.add_child(preview_name)

	var preview_description := Label.new()
	preview_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_description.autowrap_mode = TextServer.AUTOWRAP_WORD
	preview_description.add_theme_font_size_override("font_size", 15)
	preview_description.text = item_data.description
	vbox.add_child(preview_description)

	return root
