extends "res://monster_card.gd"

var _victory_xp_label: Label = null
var _cached_victory_xp_text: String = ""

func _ready() -> void:
	super._ready()
	_ensure_victory_xp_label()
	_sync_victory_xp_overlay()

func _process(_delta: float) -> void:
	_sync_victory_xp_overlay()

func _apply_data() -> void:
	_cached_victory_xp_text = ""
	super._apply_data()
	_sync_victory_xp_overlay()

func set_victory_xp_gain(amount: int) -> void:
	if amount <= 0:
		_cached_victory_xp_text = ""
	else:
		_cached_victory_xp_text = "+%d XP" % amount

	_sync_victory_xp_overlay()

func _ensure_victory_xp_label() -> void:
	if _victory_xp_label != null and is_instance_valid(_victory_xp_label):
		return
	if art_frame == null:
		return

	_victory_xp_label = Label.new()
	_victory_xp_label.name = "VictoryXpLabel"
	_victory_xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_victory_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_victory_xp_label.add_theme_font_size_override("font_size", 22)
	_victory_xp_label.add_theme_color_override("font_color", Color(0.72, 0.44, 1.0, 1.0))
	_victory_xp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_victory_xp_label.add_theme_constant_override("outline_size", 5)
	_victory_xp_label.z_index = 50
	_victory_xp_label.visible = false
	_victory_xp_label.anchor_left = 0.0
	_victory_xp_label.anchor_top = 0.03
	_victory_xp_label.anchor_right = 1.0
	_victory_xp_label.anchor_bottom = 0.38
	_victory_xp_label.offset_left = 0.0
	_victory_xp_label.offset_top = 0.0
	_victory_xp_label.offset_right = 0.0
	_victory_xp_label.offset_bottom = 0.0

	art_frame.add_child(_victory_xp_label)
	_victory_xp_label.move_to_front()

func _sync_victory_xp_overlay() -> void:
	if art_frame == null:
		return

	_ensure_victory_xp_label()
	if _victory_xp_label == null:
		return

	var xp_text := _get_victory_xp_text_from_data()
	if xp_text == "":
		xp_text = _get_victory_xp_text_from_upgrade_chips()
	if xp_text == "" and _cached_victory_xp_text != "":
		xp_text = _cached_victory_xp_text

	_victory_xp_label.text = xp_text
	_victory_xp_label.visible = xp_text != ""

	if xp_text != "":
		_cached_victory_xp_text = xp_text
		_hide_victory_xp_text_in_upgrade_chips()
		_victory_xp_label.move_to_front()

func _get_victory_xp_text_from_data() -> String:
	for key in ["victory_xp_gain", "xp_gain", "pending_xp_gain", "xp_reward"]:
		var value = _data_get_meta(key, null)
		if value == null:
			value = _data_get(key, null)

		if value == null:
			continue

		var amount := int(value)
		if amount > 0:
			return "+%d XP" % amount

	return ""

func _get_victory_xp_text_from_upgrade_chips() -> String:
	if upgrade_chips == null:
		return ""

	for child in upgrade_chips.get_children():
		if child is Label:
			var xp_text := _extract_victory_xp_text((child as Label).text)
			if xp_text != "":
				return xp_text

	return ""

func _hide_victory_xp_text_in_upgrade_chips() -> void:
	if upgrade_chips == null:
		return

	for child in upgrade_chips.get_children():
		if not child is Label:
			continue

		var label := child as Label
		var xp_text := _extract_victory_xp_text(label.text)
		if xp_text == "":
			continue

		if label.text.strip_edges() == xp_text:
			label.visible = false
		else:
			label.text = label.text.replace(xp_text, "").strip_edges()

func _extract_victory_xp_text(text: String) -> String:
	var xp_index := text.find("XP")
	var plus_index := text.rfind("+")
	if xp_index == -1 or plus_index == -1 or plus_index > xp_index:
		return ""

	var number_text := text.substr(plus_index + 1, xp_index - plus_index - 1).strip_edges()
	if not number_text.is_valid_int():
		return ""

	var amount := int(number_text)
	if amount <= 0:
		return ""

	return "+%d XP" % amount
