extends Button
signal modifier_changed
signal instinct_dropped_on_card(source_index: int, slot_index: int, source_type: String)
signal board_swap_requested(source_index: int, target_index: int)
signal monster_dropped_on_card(source_type: String, source_index: int, slot_index: int)

const CARD_WIDTH := 170
const CARD_HEIGHT := 260

@onready var panel_root: PanelContainer = $PanelContainer
@onready var card_margin: MarginContainer = $PanelContainer/MarginContainer
@onready var card_vbox: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer
@onready var art_frame: PanelContainer = $PanelContainer/MarginContainer/VBoxContainer/ArtFrame
@onready var portrait: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/ArtFrame/AspectRatioContainer/Portrait
@onready var name_label: Label = $PanelContainer/MarginContainer/VBoxContainer/NameLabel
@onready var modifier_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsRow/ModifierLabel
@onready var attack_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsRow/AttackLabel
@onready var slash_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsRow/SlashLabel
@onready var health_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsRow/HealthLabel
@onready var upgrade_chips: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/UpgradeChips
@onready var xp_bar: ProgressBar = $PanelContainer/MarginContainer/VBoxContainer/ProgressBar
@onready var atb_bar: ProgressBar = $PanelContainer/MarginContainer/VBoxContainer/AtbBar

var _monster_data = null
var source_type: String = ""
var source_index: int = -1
var _pending_slot_index: int = -1
var greased_label: Label = null
var _show_instinct_details: bool = false
var _combat_mode: bool = false
var _intent_text: String = ""
var _intent_label: Label = null
var _apply_data_queued: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	toggle_mode = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_apply_card_theme()

	_set_children_mouse_ignore(panel_root)

	if portrait != null:
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


	if card_vbox != null:
		card_vbox.add_theme_constant_override("separation", 4)

	if name_label != null:
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.90))
		name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		name_label.add_theme_constant_override("outline_size", 4)

	if modifier_label != null:
		modifier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		modifier_label.add_theme_font_size_override("font_size", 15)
		modifier_label.add_theme_color_override("font_color", Color(0.88, 0.86, 0.76))
		modifier_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		modifier_label.add_theme_constant_override("outline_size", 4)

	for lbl in [attack_label, slash_label, health_label]:
		if lbl != null:
			lbl.add_theme_font_size_override("font_size", 22)
			lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			lbl.add_theme_constant_override("outline_size", 4)

	if xp_bar != null:
		xp_bar.custom_minimum_size = Vector2(0, 10)
		xp_bar.show_percentage = false

	if atb_bar != null:
		atb_bar.custom_minimum_size = Vector2(0, 10)
		atb_bar.show_percentage = false


func _apply_card_theme() -> void:
	if panel_root == null:
		return

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.09, 0.09, 0.11, 0.96)
	normal_style.border_color = Color(0.80, 0.66, 0.36, 1.0)
	normal_style.set_border_width_all(3)
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.corner_radius_bottom_right = 12
	normal_style.shadow_color = Color(0, 0, 0, 0.28)
	normal_style.shadow_size = 6
	normal_style.shadow_offset = Vector2(0, 3)

	panel_root.add_theme_stylebox_override("panel", normal_style)

	if art_frame != null:
		var art_style := StyleBoxFlat.new()
		art_style.bg_color = Color(0.16, 0.13, 0.10, 1.0)
		art_style.border_color = Color(0.95, 0.82, 0.48, 1.0)
		art_style.set_border_width_all(2)
		art_style.corner_radius_top_left = 8
		art_style.corner_radius_top_right = 8
		art_style.corner_radius_bottom_left = 8
		art_style.corner_radius_bottom_right = 8
		art_frame.add_theme_stylebox_override("panel", art_style)

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.12, 0.12, 0.15, 0.98)
	hover_style.border_color = Color(0.92, 0.78, 0.46, 1.0)

	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.07, 0.07, 0.09, 1.0)
	pressed_style.border_color = Color(0.72, 0.86, 1.0, 1.0)

	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_theme_stylebox_override("disabled", StyleBoxEmpty.new())

	disabled = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(monster, p_source_type: String = "", p_source_index: int = -1) -> void:
	_monster_data = monster
	source_type = p_source_type
	source_index = p_source_index
	_queue_apply_data()

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

	var modifiers = _data_get("modifiers", [])
	var has_poisoned := false
	for mod in modifiers:
		if String(mod) == "poisoned":
			has_poisoned = true
			break

	var base_attack: int = int(_data_get("attack", 0))
	var poison_penalty: int = 1 if has_poisoned else 0
	var shown_attack: int = int(max(1, base_attack - poison_penalty))
	var shown_health: int = int(_data_get("health", 0))

	var level: int = int(_data_get("level", 1))
	var current_slots: int = int(_data_get("modifier_slots", 1))
	var next_slot_level := -1

	for test_level in range(level + 1, 21):
		if GameState.get_upgrade_slot_count_for_level(test_level) > current_slots:
			next_slot_level = test_level
			break

	var xp: int = int(_data_get("xp", 0))
	var needed: int = GameState.get_xp_needed_for_next_level(level)

	name_label.text = "%s Lv.%d" % [
		str(_data_get("display_name", "Unknown")),
		level
	]

	attack_label.text = str(shown_attack)
	health_label.text = str(shown_health)
	slash_label.text = " / "
	upgrade_chips.visible = not _combat_mode

	if has_poisoned:
		attack_label.modulate = Color(0.35, 1.0, 0.35, 1.0)
	else:
		attack_label.modulate = Color(1, 1, 1, 1)

	health_label.modulate = Color(1, 1, 1, 1)
	slash_label.modulate = Color(0.85, 0.85, 0.85, 1)

	if _combat_mode:
		xp_bar.visible = false
	else:
		xp_bar.visible = true
		if level >= 12:
			xp_bar.min_value = 0
			xp_bar.max_value = 1
			xp_bar.value = 1
			if next_slot_level != -1:
				xp_bar.tooltip_text = "XP %d / %d\nNext slot at Lv.%d" % [xp, needed, next_slot_level]
			else:
				xp_bar.tooltip_text = "XP %d / %d\nMax slots reached" % [xp, needed]
		else:
			xp_bar.min_value = 0
			xp_bar.max_value = needed
			xp_bar.value = xp
			xp_bar.tooltip_text = "XP %d / %d" % [xp, needed]

	var tex = _data_get_meta("texture", null)
	portrait.texture = tex if tex != null else null

	_update_modifier_label()
	_update_slots_label()
	_update_greased_indicator()
	_update_status_tint()
	_update_intent_label()
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
	preview_card.modulate.a = 0.92
	preview_card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	preview_card.position = Vector2(-CARD_WIDTH / 2.0, -CARD_HEIGHT * 0.42)

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
	if modifier_label == null:
		return
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
			"freeze":
				parts.append("FREEZE")
			"frozen":
				pass
			"poison":
				parts.append("POISON")
			"windfury":
				parts.append("WINDFURY")
			"poisoned":
				pass
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

	modifier_label.text = " • ".join(parts)
	modifier_label.visible = true
func _dedupe_string_array(items: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for item in items:
		if not result.has(item):
			result.append(item)
	return result
func _clear_upgrade_chips() -> void:
	for child in upgrade_chips.get_children():
		child.queue_free()


func _add_upgrade_chip(text: String, tooltip: String) -> void:
	var chip := Label.new()
	chip.text = text
	chip.tooltip_text = tooltip
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.focus_mode = Control.FOCUS_NONE
	chip.add_theme_font_size_override("font_size", 13)
	chip.add_theme_color_override("font_color", Color(0.90, 0.88, 0.82, 1.0))
	chip.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	chip.add_theme_constant_override("outline_size", 3)
	chip.clip_text = false
	upgrade_chips.add_child(chip)
func _update_slots_label() -> void:
	_clear_upgrade_chips()

	if _monster_data == null:
		return

	var total_slots: int = int(_data_get("modifier_slots", 0))
	var equipped = _data_get("equipped_modifiers", [])
	var instincts = _data_get("instincts", [])
	var used_slots: int = equipped.size() + instincts.size()

	_add_slot_chip(used_slots, total_slots)

	for mod in equipped:
		match String(mod):
			"thorns":
				_add_upgrade_chip("🌵 SPIKED", "When hit by an attack, deal 1 damage back.")
			"shield":
				_add_upgrade_chip("🛡 SHIELD", "Defensive upgrade.")
			"parry":
				_add_upgrade_chip("⚔ PARRY", "Defensive upgrade.")
			"taunt":
				_add_upgrade_chip("🛡 TAUNT", "Enemies must target this unit if able.")
			_:
				_add_upgrade_chip(String(mod).to_upper(), String(mod).capitalize())

	for inst in instincts:
		var rule := ""
		var label := ""
		var description := ""

		if typeof(inst) == TYPE_DICTIONARY:
			var inst_dict: Dictionary = inst
			rule = String(inst_dict.get("rule", ""))
			label = String(inst_dict.get("name", "INSTINCT"))
			description = String(inst_dict.get("description", ""))
		elif typeof(inst) == TYPE_STRING:
			var inst_str: String = inst
			match inst_str:
				"target_highest_health":
					rule = "highest_health"
					label = "Hunter Instinct"
					description = "Attack the highest health enemy."
				"target_lowest_health":
					rule = "lowest_health"
					label = "Execute Instinct"
					description = "Attack the lowest health enemy."
				"target_front":
					rule = "front"
					label = "Front Instinct"
					description = "Attack the front enemy."
				"target_back":
					rule = "back"
					label = "Back Instinct"
					description = "Attack the back enemy."
				"target_burning":
					rule = "burning"
					label = "Scorch Hunter"
					description = "Attack burning enemies first."
				"target_poisoned":
					rule = "poisoned"
					label = "Venom Hunter"
					description = "Attack poisoned enemies first."
				"target_frozen":
					rule = "frozen"
					label = "Frost Hunter"
					description = "Attack frozen enemies first."

		match rule:
			"highest_health":
				_add_upgrade_chip("🎯 HUNTER", description if description != "" else "Attack the highest health enemy.")
			"lowest_health":
				_add_upgrade_chip("🩸 EXECUTE", description if description != "" else "Attack the lowest health enemy.")
			"front":
				_add_upgrade_chip("➡ FRONT", description if description != "" else "Attack the front enemy.")
			"back":
				_add_upgrade_chip("⬅ BACK", description if description != "" else "Attack the back enemy.")
			"burning":
				_add_upgrade_chip("🔥 SCORCH", description if description != "" else "Attack burning enemies first.")
			"poisoned":
				_add_upgrade_chip("☠ VENOM", description if description != "" else "Attack poisoned enemies first.")
			"frozen":
				_add_upgrade_chip("❄ FROST", description if description != "" else "Attack frozen enemies first.")
			"reduce_damage":
				_add_upgrade_chip("🛡 THICK HIDE", description if description != "" else "Takes 1 less damage from attacks.")
			"thorns_on_hit":
				_add_upgrade_chip("🌵 SPIKED", description if description != "" else "When hit by an attack, deal 1 damage back.")
			"low_hp_attack":
				_add_upgrade_chip("🔥 LAST STAND", description if description != "" else "Gain bonus attack while below half health.")
			"bonus_vs_greased":
				_add_upgrade_chip("🪔 KINDLING", description if description != "" else "Deal +1 damage to greased enemies.")
			"gain_attack_on_burning_hit":
				_add_upgrade_chip("🔥 WILDFIRE", description if description != "" else "After damaging a burning enemy, gain +1 attack this combat.")
			"first_hit_grease":
				_add_upgrade_chip("🛢 SLICK", description if description != "" else "First successful attack each combat also applies greased.")
			"bonus_vs_poisoned":
				_add_upgrade_chip("☠ VENOM FANG", description if description != "" else "Deal +1 damage to poisoned enemies.")
			"bonus_vs_frozen":
				_add_upgrade_chip("❄ SHATTER", description if description != "" else "Deal +2 damage to frozen enemies.")
			"gain_attack_on_kill":
				_add_upgrade_chip("🩸 BLOOD RUSH", description if description != "" else "When this kills an enemy, gain +1 attack.")
			_:
				if label != "":
					_add_upgrade_chip("✨ " + label.to_upper(), description if description != "" else label)
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
	var has_poisoned := false
	var has_frozen := false

	for mod in modifiers:
		match String(mod):
			"greased":
				has_greased = true
			"burning":
				has_burning = true
			"poisoned":
				has_poisoned = true
			"frozen":
				has_frozen = true

	if not has_greased and not has_burning and not has_poisoned and not has_frozen:
		return

	var parts: Array[String] = []
	if has_greased:
		parts.append("G")
	if has_burning:
		parts.append("B")
	if has_poisoned:
		parts.append("P")
	if has_frozen:
		parts.append("F")

	greased_label = Label.new()
	greased_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	greased_label.focus_mode = Control.FOCUS_NONE
	greased_label.text = " ".join(parts)
	greased_label.z_index = 100
	greased_label.position = Vector2(6, 4)
	greased_label.add_theme_font_size_override("font_size", 18)
	greased_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	greased_label.add_theme_constant_override("outline_size", 4)

	if has_frozen and not has_greased and not has_burning and not has_poisoned:
		greased_label.modulate = Color(0.55, 0.8, 1.0, 1.0)
	elif has_poisoned and not has_greased and not has_burning and not has_frozen:
		greased_label.modulate = Color(0.35, 1.0, 0.35, 1.0)
	elif has_burning and not has_greased and not has_poisoned and not has_frozen:
		greased_label.modulate = Color(1.0, 0.35, 0.1, 1.0)
	elif has_greased and not has_burning and not has_poisoned and not has_frozen:
		greased_label.modulate = Color(1.0, 0.95, 0.2, 1.0)
	else:
		greased_label.modulate = Color(0.9, 1.0, 0.55, 1.0)

	art_frame.add_child(greased_label)
func _add_slot_chip(used: int, total: int) -> void:
	var parts: Array[String] = []

	for i in range(total):
		if i < used:
			parts.append("●")
		else:
			parts.append("○")

	var chip := Label.new()
	chip.text = "SLOTS " + " ".join(parts)
	chip.tooltip_text = "Used %d / %d upgrade slots" % [used, total]
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.focus_mode = Control.FOCUS_NONE
	chip.add_theme_font_size_override("font_size", 13)
	chip.add_theme_color_override("font_color", Color(0.84, 0.82, 0.76, 1.0))
	chip.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	chip.add_theme_constant_override("outline_size", 3)

	upgrade_chips.add_child(chip)
func set_combat_ui(enabled: bool) -> void:
	if atb_bar != null:
		atb_bar.visible = enabled

	# Hide XP bar in combat if you don't want both shown
	if xp_bar != null:
		xp_bar.visible = not enabled


func set_atb(current: float, maximum: float, ready: bool = false) -> void:
	if atb_bar == null:
		return

	atb_bar.min_value = 0.0
	atb_bar.max_value = maximum
	atb_bar.value = clamp(current, 0.0, maximum)
	atb_bar.tooltip_text = "ATB %d / %d" % [int(current), int(maximum)]

	if ready:
		atb_bar.modulate = Color(0.65, 1.0, 0.65, 1.0)
	else:
		atb_bar.modulate = Color(1, 1, 1, 1)
func set_combat_mode(enabled: bool) -> void:
	_combat_mode = enabled
	_queue_apply_data()


func set_intent_text(text: String) -> void:
	_intent_text = text
	_queue_apply_data()
func _update_intent_label() -> void:
	if _intent_label == null:
		_intent_label = Label.new()
		_intent_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_intent_label.focus_mode = Control.FOCUS_NONE
		_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_intent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_intent_label.add_theme_font_size_override("font_size", 13)
		_intent_label.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0, 1.0))
		_intent_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		_intent_label.add_theme_constant_override("outline_size", 4)
		card_vbox.add_child(_intent_label)

	if _combat_mode:
		_intent_label.visible = true
		_intent_label.text = _intent_text
	else:
		_intent_label.visible = false
func _queue_apply_data() -> void:
	if _apply_data_queued:
		return

	_apply_data_queued = true
	call_deferred("_apply_data_deferred")


func _apply_data_deferred() -> void:
	_apply_data_queued = false
	_apply_data()
func update_combat_snapshot(monster, intent_text: String = "", ready: bool = false, atb_current: float = 0.0, atb_maximum: float = 100.0) -> void:
	_monster_data = monster

	var modifiers = _data_get("modifiers", [])
	var has_poisoned := false
	for mod in modifiers:
		if String(mod) == "poisoned":
			has_poisoned = true
			break

	var base_attack: int = int(_data_get("attack", 0))
	var poison_penalty: int = 1 if has_poisoned else 0
	var shown_attack: int = int(max(1, base_attack - poison_penalty))
	var shown_health: int = int(_data_get("health", 0))
	var level: int = int(_data_get("level", 1))

	name_label.text = "%s Lv.%d" % [
		str(_data_get("display_name", "Unknown")),
		level
	]

	attack_label.text = str(shown_attack)
	health_label.text = str(shown_health)
	slash_label.text = " / "

	attack_label.modulate = Color(0.35, 1.0, 0.35, 1.0) if has_poisoned else Color(1, 1, 1, 1)
	health_label.modulate = Color(1, 1, 1, 1)
	slash_label.modulate = Color(1, 1, 1, 1)

	if xp_bar != null:
		xp_bar.visible = false
	if upgrade_chips != null:
		upgrade_chips.visible = false
	if atb_bar != null:
		atb_bar.visible = true

	_update_modifier_label()
	_update_greased_indicator()
	_update_status_tint()

	if _intent_label == null:
		_update_intent_label()

	if _intent_label != null:
		_intent_label.visible = _combat_mode
		_intent_label.text = intent_text

	set_atb(atb_current, atb_maximum, ready)
func _set_children_mouse_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			var c := child as Control
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.focus_mode = Control.FOCUS_NONE
		_set_children_mouse_ignore(child)
