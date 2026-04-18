extends Button
signal modifier_changed
signal instinct_dropped_on_card(source_index: int, slot_index: int, source_type: String)

@onready var portrait: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/Portrait
@onready var name_label: Label = $PanelContainer/MarginContainer/VBoxContainer/NameLabel
@onready var stats_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/StatsLabel
@onready var modifier_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ModifierLabel
@onready var slots_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SlotsLabel
@onready var socket_row: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/SocketRow
@onready var socket_button_0: Button = $PanelContainer/MarginContainer/VBoxContainer/SocketRow/SocketButton0
@onready var socket_button_1: Button = $PanelContainer/MarginContainer/VBoxContainer/SocketRow/SocketButton1
@onready var modifier_popup: PopupMenu = $ModifierPopup

var _monster_data = null
var source_type: String = ""
var source_index: int = -1
var _pending_slot_index: int = -1

func _ready() -> void:
	if socket_button_0:
		socket_button_0.pressed.connect(_on_socket_pressed.bind(0))
	if socket_button_1:
		socket_button_1.pressed.connect(_on_socket_pressed.bind(1))
	if modifier_popup:
		modifier_popup.id_pressed.connect(_on_modifier_popup_selected)

func setup(monster, p_source_type: String = "", p_source_index: int = -1) -> void:
	_monster_data = monster
	source_type = p_source_type
	source_index = p_source_index
	call_deferred("_apply_data")

func _apply_data() -> void:
	if _monster_data == null:
		return

	name_label.text = _monster_data.display_name
	stats_label.text = "%d / %d" % [_monster_data.attack, _monster_data.health]

	if _monster_data.has_meta("texture"):
		portrait.texture = _monster_data.get_meta("texture")

	_update_modifier_label()
	_update_slots_label()
	_update_socket_buttons()

func _update_socket_buttons() -> void:
	if _monster_data == null:
		socket_row.visible = false
		return

	var total: int = int(_monster_data.modifier_slots)
	var filled: int = int(_monster_data.equipped_modifiers.size())

	# Show sockets only on board cards for now
	socket_row.visible = (source_type == "board" and total > 0)

	socket_button_0.visible = total >= 1
	socket_button_1.visible = total >= 2

	if total >= 1:
		socket_button_0.text = "[X]" if filled >= 1 else "[ ]"

	if total >= 2:
		socket_button_1.text = "[X]" if filled >= 2 else "[ ]"

func _on_socket_pressed(slot_index: int) -> void:
	if _monster_data == null:
		return

	# Don't overwrite a filled slot
	if slot_index < _monster_data.equipped_modifiers.size():
		return

	_pending_slot_index = slot_index

	modifier_popup.clear()
	modifier_popup.add_item("🌵 Thorns", 0)
	modifier_popup.add_item("🛡 Shield", 1)
	modifier_popup.add_item("⚔ Parry", 2)
	modifier_popup.add_separator()
	modifier_popup.add_item("🎯 Hunter Instinct", 100)

	modifier_popup.position = Vector2i(get_global_mouse_position())
	modifier_popup.popup()

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
		"source_type": source_type,
		"source_index": source_index
	}

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		if is_instance_valid(GameState.sell_strip_ref):
			GameState.sell_strip_ref.disable_drop_zone()

func _update_modifier_label() -> void:
	if _monster_data == null or _monster_data.modifiers.is_empty():
		modifier_label.text = ""
		modifier_label.visible = false
		return

	var parts: Array[String] = []

	for mod in _monster_data.modifiers:
		match String(mod):
			"taunt":
				parts.append("🛡 TAUNT")
			"burn":
				parts.append("🔥 BURN")
			"regenerate":
				parts.append("💚 REGEN")
			"pack_hunter":
				parts.append("🐺 PACK")
			_:
				parts.append(String(mod).to_upper())

	modifier_label.text = " ".join(parts)
	modifier_label.visible = true

func _update_slots_label() -> void:
	if _monster_data == null:
		slots_label.text = ""
		slots_label.visible = false
		return

	var total: int = int(_monster_data.modifier_slots)
	var equipped = _monster_data.equipped_modifiers
	var instincts = _monster_data.instincts

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

	return drag_card_type == "instinct" and (drag_source_type == "hand" or drag_source_type == "board_instinct")


func _drop_data(_pos, data) -> void:
	if source_type != "board":
		return

	if typeof(data) != TYPE_DICTIONARY:
		return

	var drag_card_type: String = String(data.get("card_type", "monster"))
	if drag_card_type != "instinct":
		return

	var drag_source_type: String = String(data.get("source_type", ""))
	var drag_source_index: int = int(data.get("source_index", -1))

	instinct_dropped_on_card.emit(drag_source_index, source_index, drag_source_type)
