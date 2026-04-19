extends Button
signal modifier_changed
signal instinct_dropped_on_card(source_index: int, slot_index: int, source_type: String)
signal board_swap_requested(source_index: int, target_index: int)
signal monster_dropped_on_card(source_type: String, source_index: int, slot_index: int)


@onready var portrait: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/Portrait
@onready var name_label: Label = $PanelContainer/MarginContainer/VBoxContainer/NameLabel
@onready var stats_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/StatsLabel
@onready var modifier_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ModifierLabel
@onready var slots_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SlotsLabel
@onready var xp_bar: ProgressBar = $PanelContainer/MarginContainer/VBoxContainer/ProgressBar

var _monster_data = null
var source_type: String = ""
var source_index: int = -1
var _pending_slot_index: int = -1
var greased_label: Label = null

func setup(monster, p_source_type: String = "", p_source_index: int = -1) -> void:
	_monster_data = monster
	source_type = p_source_type
	source_index = p_source_index
	call_deferred("_apply_data")

func _data_get(key: String, default_value = null):
	if _monster_data == null:
		return default_value

	if _monster_data is Dictionary:
		return _monster_data.get(key, default_value)

	return _monster_data.get(key) if _monster_data.get(key) != null else default_value

func _data_has_meta(key: String) -> bool:
	if _monster_data == null:
		return false
	if _monster_data is Dictionary:
		return _monster_data.has(key)
	return _monster_data.has_meta(key)

func _data_get_meta(key: String, default_value = null):
	if _monster_data == null:
		return default_value
	if _monster_data is Dictionary:
		return _monster_data.get(key, default_value)
	if _monster_data.has_meta(key):
		return _monster_data.get_meta(key)
	return default_value

func _apply_data() -> void:
	if _monster_data == null:
		return

	name_label.text = "%s  Lv.%d" % [
	str(_data_get("display_name", "Unknown")),
	int(_data_get("level", 1))
]
	stats_label.text = "%d / %d" % [
		int(_data_get("attack", 0)),
		int(_data_get("health", 0))
	]
	var level := int(_data_get("level", 1))
	var xp := int(_data_get("xp", 0))
	var needed := GameState.get_xp_needed_for_next_level(level)

	name_label.text = "%s  Lv.%d" % [
		str(_data_get("display_name", "Unknown")),
		level
	]

	if level >= 6:
		xp_bar.visible = true
		xp_bar.min_value = 0
		xp_bar.max_value = 1
		xp_bar.value = 1
		xp_bar.tooltip_text = "Max level"
	else:
		xp_bar.visible = true
		xp_bar.min_value = 0
		xp_bar.max_value = needed
		xp_bar.value = xp
		xp_bar.tooltip_text = "XP %d / %d" % [xp, needed]
	var tex = _data_get_meta("texture", null)
	if tex != null:
		portrait.texture = tex
	else:
		portrait.texture = null

	_update_modifier_label()
	_update_slots_label()
	_update_greased_indicator()
	_update_status_tint()

func _update_status_tint() -> void:
	if _monster_data == null:
		self_modulate = Color(1, 1, 1, 1)
		return

	var has_greased := false
	var modifiers = _data_get("modifiers", [])

	for mod in modifiers:
		if String(mod) == "greased":
			has_greased = true
			break

	if has_greased:
		self_modulate = Color(1.0, 0.96, 0.78, 1.0)
	else:
		self_modulate = Color(1, 1, 1, 1)

func _on_modifier_popup_selected(id: int) -> void:
	if _monster_data == null:
		return

	var modifier_id: String = ""
	var instinct: Dictionary = {}

	match id:
		0:
			modifier_id = "thorns"
		1:
			modifier_id = "shield"
		2:
			modifier_id = "parry"
		3:
			modifier_id = "oil"
		100:
			instinct = {
				"id": "target_highest_health",
				"name": "Hunter Instinct",
				"description": "Attack the highest health enemy",
				"type": "targeting",
				"rule": "highest_health"
			}

	if modifier_id != "":
		var success: bool = GameState.add_equipped_modifier(_monster_data, modifier_id)
		if success:
			_apply_data()
			modifier_changed.emit()
		return

	if not instinct.is_empty():
		var success: bool = GameState.add_instinct_to_monster(_monster_data, instinct)
		if success:
			_apply_data()
			modifier_changed.emit()
		return

func _get_drag_data(_at_position: Vector2):
	if source_type != "hand" and source_type != "board":
		return null

	if is_instance_valid(GameState.sell_strip_ref):
		GameState.sell_strip_ref.enable_drop_zone()

	var preview_root := Control.new()
	preview_root.custom_minimum_size = Vector2(1, 1)
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview_card = duplicate()
	preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_card.modulate.a = 0.9
	preview_card.custom_minimum_size = Vector2(150, 180)
	preview_card.position = Vector2(-75, -90)

	preview_root.add_child(preview_card)
	set_drag_preview(preview_root)

	return {
		"card_type": "monster",
		"source_type": source_type,
		"source_index": source_index,
		"monster": _monster_data
	}

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		if is_instance_valid(GameState.sell_strip_ref):
			GameState.sell_strip_ref.disable_drop_zone()

func _update_modifier_label() -> void:
	if _monster_data == null:
		modifier_label.text = ""
		modifier_label.visible = false
		return

	var parts: Array[String] = []
	var modifiers = _data_get("modifiers", [])
	var equipped_modifiers = _data_get("equipped_modifiers", [])

	for mod in modifiers:
		match String(mod):
			"taunt":
				parts.append("TAUNT")
			"burn":
				parts.append("BURN")
			"burning":
				pass
			"regenerate":
				parts.append("REGEN")
			"pack_hunter":
				parts.append("PACK")
			"oil":
				parts.append("OIL")
			"greased":
				pass
			_:
				parts.append(String(mod).to_upper())

	for mod in equipped_modifiers:
		match String(mod):
			"thorns":
				parts.append("THORNS")
			"shield":
				parts.append("SHIELD")
			"parry":
				parts.append("PARRY")
			"oil":
				parts.append("OIL")
			_:
				parts.append(String(mod).to_upper())

	parts = _dedupe_string_array(parts)

	if parts.is_empty():
		modifier_label.text = ""
		modifier_label.visible = false
		return

	modifier_label.text = " ".join(parts)
	modifier_label.visible = true

func _dedupe_string_array(items: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for item in items:
		if not result.has(item):
			result.append(item)
	return result

func _update_slots_label() -> void:
	if _monster_data == null:
		slots_label.text = ""
		slots_label.visible = false
		return

	var total: int = int(_data_get("modifier_slots", 0))
	var equipped = _data_get("equipped_modifiers", [])
	var instincts = _data_get("instincts", [])

	if total <= 0 and equipped.is_empty() and instincts.is_empty():
		slots_label.text = ""
		slots_label.visible = false
		return

	var parts: Array[String] = []

	for mod in equipped:
		match String(mod):
			"thorns":
				parts.append("🌵 THORNS")
			"shield":
				parts.append("🛡 SHIELD")
			"parry":
				parts.append("⚔ PARRY")
			"taunt":
				parts.append("🛡 TAUNT")
			_:
				parts.append(String(mod).to_upper())

	for inst in instincts:
		var rule := ""
		var label := ""

		if typeof(inst) == TYPE_DICTIONARY:
			var inst_dict: Dictionary = inst
			rule = String(inst_dict.get("rule", ""))
			label = String(inst_dict.get("name", "INSTINCT"))
		elif typeof(inst) == TYPE_STRING:
			var inst_str: String = inst
			match inst_str:
				"target_highest_health":
					rule = "highest_health"
					label = "Hunter Instinct"
				"target_lowest_health":
					rule = "lowest_health"
					label = "Execute Instinct"
				"target_front":
					rule = "front"
					label = "Front Instinct"
				"target_back":
					rule = "back"
					label = "Back Instinct"

		match rule:
			"highest_health":
				parts.append("🎯 HUNTER")
			"lowest_health":
				parts.append("🩸 EXECUTE")
			"front":
				parts.append("➡ FRONT")
			"back":
				parts.append("⬅ BACK")
			_:
				if label != "":
					parts.append("✨ " + label.to_upper())
				else:
					parts.append("✨ INSTINCT")

	if total > 0:
		var filled: int = int(equipped.size())
		var slot_text := ""

		for i in range(total):
			if i < filled:
				slot_text += "[X] "
			else:
				slot_text += "[ ] "

		parts.append(slot_text.strip_edges())

	slots_label.text = " ".join(parts)
	slots_label.visible = true

func _can_drop_data(_pos, data) -> bool:
	if source_type != "board":
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false

	var drag_card_type: String = String(data.get("card_type", "monster"))
	var drag_source_type: String = String(data.get("source_type", ""))

	# Allow instincts onto board monsters
	if drag_card_type == "instinct":
		return drag_source_type == "hand" or drag_source_type == "board_instinct"

	# Allow hand monsters onto board monsters (for duplicate XP)
	if drag_card_type == "monster" and drag_source_type == "hand":
		return true

	# Allow board monster onto another board monster to swap
	if drag_card_type == "monster" and drag_source_type == "board":
		return true

	return false

func _drop_data(_pos, data) -> void:
	if source_type != "board":
		return
	if typeof(data) != TYPE_DICTIONARY:
		return

	var drag_card_type: String = String(data.get("card_type", "monster"))
	var drag_source_type: String = String(data.get("source_type", ""))
	var drag_source_index: int = int(data.get("source_index", -1))

	if drag_card_type == "instinct":
		instinct_dropped_on_card.emit(drag_source_index, source_index, drag_source_type)
		return

	if drag_card_type == "monster":
		if drag_source_type == "hand":
			monster_dropped_on_card.emit(drag_source_type, drag_source_index, source_index)
			return

		if drag_source_type == "board":
			if drag_source_index == source_index:
				return
			board_swap_requested.emit(drag_source_index, source_index)
			return
func _update_greased_indicator() -> void:
	if greased_label != null:
		greased_label.queue_free()
		greased_label = null

	if _monster_data == null:
		return

	var modifiers = _data_get("modifiers", [])
	var has_greased := false
	var has_burning := false

	for mod in modifiers:
		match String(mod):
			"greased":
				has_greased = true
			"burning":
				has_burning = true

	if not has_greased and not has_burning:
		return

	var parts: Array[String] = []
	if has_greased:
		parts.append("G")
	if has_burning:
		parts.append("B")

	greased_label = Label.new()
	greased_label.text = " ".join(parts)
	greased_label.z_index = 100
	greased_label.add_theme_font_size_override("font_size", 18)
	greased_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	greased_label.add_theme_constant_override("outline_size", 4)
	greased_label.position = Vector2(4, 2)

	if has_burning and not has_greased:
		greased_label.modulate = Color(1.0, 0.35, 0.1)
	elif has_greased and not has_burning:
		greased_label.modulate = Color(1, 1, 0.2)
	else:
		greased_label.modulate = Color(1.0, 0.75, 0.2)

	add_child(greased_label)
