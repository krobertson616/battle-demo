extends Control

@onready var enemy_row: HBoxContainer = $MarginContainer/VBoxContainer/EnemyRow
@onready var player_row: HBoxContainer = $MarginContainer/VBoxContainer/PlayerRow
@onready var result_label: Label = $MarginContainer/VBoxContainer/ResultLabel
@onready var combat_log: RichTextLabel = $MarginContainer/VBoxContainer/CombatLog
@onready var continue_button: Button = $MarginContainer/VBoxContainer/ContinueButton
@onready var background = $BackgroundTexture
@onready var reward_overlay: CenterContainer = $RewardOverlay
@onready var reward_panel: PanelContainer = $RewardOverlay/RewardPanel
@onready var reward_title: Label = $RewardOverlay/RewardPanel/RewardVBox/RewardTitle
@onready var xp_gain_label: Label = $RewardOverlay/RewardPanel/RewardVBox/XpGainLabel
@onready var reward_choices_row: HBoxContainer = $RewardOverlay/RewardPanel/RewardVBox/RewardChoiceRow
var monster_card_scene = preload("res://scenes/monster_card.tscn")

var visual_enemy_team: Array = []
var visual_player_team: Array = []

const CARD_WIDTH := 150
const CARD_HEIGHT := 250

const ATTACK_ANIM_TIME := 0.28
const HIT_ANIM_TIME := 0.18
const ATTACK_PAUSE := 0.14
const DAMAGE_PAUSE := 0.22
const DEATH_PAUSE := 0.45
var current_player_index: int = -1
var selected_action: String = ""
var battle_over := false
var battle_ui: VBoxContainer
var turn_info_label: Label
var action_row: HBoxContainer
var target_row: HBoxContainer
var attack_button: Button
var defend_button: Button
var player_units: Array = []
var enemy_units: Array = []
var current_enemy_index: int = -1
var player_turn_cursor: int = 0
var enemy_turn_cursor: int = 0
var current_side: String = "player"
var instinct_button: Button
var battle_paused_for_input := false
var ready_side: String = ""
var ready_index: int = -1
var battle_paused := false
var manual_selected_player_index: int = -1
var pause_button: Button
var action_in_progress := false
var drag_assigning := false
var drag_start_player_index: int = -1
var drag_hover_enemy_index: int = -1
var drag_mouse_local: Vector2 = Vector2.ZERO
var line_layer: Node2D
var drag_line: Line2D
var pause_dim: ColorRect

const PLAYER_AUTO_ACTION_DELAY := 0.9
const BATTLE_SPEED_SCALE: float = 0.5

var pending_player_click_index: int = -1
var pending_drag_started: bool = false
var pending_drag_start_pos: Vector2 = Vector2.ZERO

const DRAG_START_DISTANCE: float = 18.0
const INSTINCT_COOLDOWN_TURNS: int = 3

func _ready() -> void:
	randomize()
	#print("ARENA selected_location =", GameState.selected_location)
	#print("ARENA active_node_type =", GameState.active_node_type)
	_set_background()
	reward_overlay.visible = false
	_set_battle_paused_state(true)

	if turn_info_label != null:
		turn_info_label.text = "Battle paused - issue commands"
	#print("Entered arena scene")
	#print("Pending player team size:", GameState.pending_player_team.size())
	#print("Pending enemy team size:", GameState.pending_enemy_team.size())

	for i in range(GameState.pending_player_team.size()):
		var monster = _get_monster_from_entry(GameState.pending_player_team[i])
		if monster != null:
			print("Player monster ", i, ": ", monster.display_name)

	for i in range(GameState.pending_enemy_team.size()):
		var monster = _get_monster_from_entry(GameState.pending_enemy_team[i])
		if monster != null:
			print("Enemy monster ", i, ": ", monster.display_name)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.disabled = true

	visual_enemy_team.clear()
	visual_player_team.clear()

	for entry in GameState.pending_enemy_team:
		var monster = _get_monster_from_entry(entry)
		if monster != null:
			visual_enemy_team.append(monster.duplicate(true))

	for entry in GameState.pending_player_team:
		var monster = _get_monster_from_entry(entry)
		if monster != null:
			visual_player_team.append(monster.duplicate(true))

	combat_log.clear()
	result_label.text = ""
	_build_battle_state()
	_render_teams()
	_build_pause_dim()
	_build_battle_ui()
	_update_battle_ui_visibility()
	_build_line_overlay()
	attack_button.disabled = true
	defend_button.disabled = true
	instinct_button.disabled = true
	instinct_button.text = "Instinct"
	_clear_target_buttons()
	_refresh_cards_light()

	set_process(true)
func _update_pause_dim() -> void:
	if pause_dim == null:
		return

	pause_dim.visible = battle_paused
func _render_teams() -> void:
	for c in enemy_row.get_children():
		c.queue_free()

	for c in player_row.get_children():
		c.queue_free()

	var combat_cards := not battle_over

	for i in range(visual_enemy_team.size()):
		var monster = visual_enemy_team[i]

		var holder := Control.new()
		holder.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)

		var card = monster_card_scene.instantiate()
		card.setup(monster)
		card.position = Vector2.ZERO

		if card.has_method("set_combat_mode"):
			card.set_combat_mode(combat_cards)

		if card.has_method("set_combat_ui"):
			card.set_combat_ui(combat_cards)

		if card.has_method("set_intent_text"):
			if battle_over:
				card.set_intent_text("")
			elif i < enemy_units.size():
				card.set_intent_text(_get_enemy_intent_text(i))
			else:
				card.set_intent_text("")

		if i < enemy_units.size() and card.has_method("set_atb"):
			card.set_atb(
				float(enemy_units[i]["atb"]),
				float(enemy_units[i]["atb_max"]),
				bool(enemy_units[i]["is_ready"])
			)

		if monster.health <= 0:
			card.modulate = Color(1, 1, 1, 0.35)
		elif battle_paused and selected_action == "queue_attack" and manual_selected_player_index != -1:
			card.modulate = Color(1.1, 0.9, 0.9, 1.0)
		else:
			card.modulate = Color(1, 1, 1, 1)

		if card is BaseButton:
			card.disabled = false

		holder.add_child(card)
		enemy_row.add_child(holder)

	for i in range(visual_player_team.size()):
		var monster = visual_player_team[i]

		var holder := Control.new()
		holder.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)

		var card = monster_card_scene.instantiate()
		card.setup(monster)
		card.position = Vector2.ZERO

		if card.has_method("set_combat_mode"):
			card.set_combat_mode(combat_cards)

		if card.has_method("set_combat_ui"):
			card.set_combat_ui(combat_cards)

		if card.has_method("set_intent_text"):
			if battle_over:
				card.set_intent_text("")
			elif i < player_units.size():
				card.set_intent_text(_get_player_intent_text(i))
			else:
				card.set_intent_text("")

		if i < player_units.size() and card.has_method("set_atb"):
			card.set_atb(
				float(player_units[i]["atb"]),
				float(player_units[i]["atb_max"]),
				bool(player_units[i]["is_ready"])
			)

		if monster.health <= 0:
			card.modulate = Color(1, 1, 1, 0.35)
		elif battle_paused and i == manual_selected_player_index:
			card.modulate = Color(1.2, 1.2, 0.7, 1.0)
		elif battle_paused and i < player_units.size() and bool(player_units[i]["is_ready"]):
			card.modulate = Color(0.85, 1.05, 0.85, 1.0)
		else:
			card.modulate = Color(1, 1, 1, 1)

		if card is BaseButton:
			card.disabled = false
			card.button_down.connect(_on_player_card_button_down.bind(i))

		holder.add_child(card)
		player_row.add_child(holder)
func _run_combat() -> void:
	GameState.pending_result = CombatResolver.resolve_combat(
		GameState.pending_player_team,
		GameState.pending_enemy_team
	)

	combat_log.clear()
	result_label.text = ""

	await _play_combat_events(GameState.pending_result.get("events", []))
	_persist_player_combat_bonuses()

	if GameState.pending_result.get("player_won", false):
		result_label.text = "Victory!"
		await _show_post_combat_rewards()
	else:
		result_label.text = "Defeat!"
		continue_button.disabled = false
func _play_combat_events(events: Array) -> void:
	for event in events:
		var event_type: String = str(event.get("type", ""))

		match event_type:
			"attack":
				combat_log.append_text(
					"%s attacks %s\n" % [
						event.get("attacker_name", ""),
						event.get("target_name", "")
					]
				)

				await _animate_attack(
					str(event.get("attacker_side", "")),
					int(event.get("attacker_index", 0)),
					str(event.get("target_side", "")),
					int(event.get("target_index", 0))
				)
				await get_tree().create_timer(ATTACK_PAUSE).timeout
			"status_applied":
				var target_side: String = str(event.get("target_side", ""))
				var target_name: String = str(event.get("target_name", ""))
				var target_index: int = int(event.get("target_index", -1))
				var status: String = str(event.get("status", ""))

				if status == "greased" or status == "burning" or status == "poisoned" or status == "frozen":
					combat_log.append_text("%s is %s!\n" % [target_name, status])

					if target_side == "enemy":
						if target_index >= 0 and target_index < visual_enemy_team.size():
							if not visual_enemy_team[target_index].modifiers.has(status):
								visual_enemy_team[target_index].modifiers.append(status)
					elif target_side == "player":
						if target_index >= 0 and target_index < visual_player_team.size():
							if not visual_player_team[target_index].modifiers.has(status):
								visual_player_team[target_index].modifiers.append(status)

					_render_teams()
					await get_tree().create_timer(0.12).timeout
			"status_removed":
				var target_side: String = str(event.get("target_side", ""))
				var target_name: String = str(event.get("target_name", ""))
				var target_index: int = int(event.get("target_index", -1))
				var status: String = str(event.get("status", ""))

				if status == "greased" or status == "burning" or status == "poisoned" or status == "frozen":
					combat_log.append_text("%s is no longer %s.\n" % [target_name, status])

					if target_side == "enemy":
						if target_index >= 0 and target_index < visual_enemy_team.size():
							visual_enemy_team[target_index].modifiers.erase(status)
					elif target_side == "player":
						if target_index >= 0 and target_index < visual_player_team.size():
							visual_player_team[target_index].modifiers.erase(status)

					_render_teams()
					await get_tree().create_timer(0.08).timeout
			"miss":
					var target_side: String = str(event.get("target_side", ""))
					var target_name: String = str(event.get("target_name", ""))
					var target_index: int = int(event.get("target_index", 0))

					combat_log.append_text("%s dodges the attack!\n" % target_name)
					_show_floating_miss(target_side, target_index)
					await get_tree().create_timer(0.18).timeout
			"skip_turn":
				var side: String = str(event.get("side", ""))
				var target_index: int = int(event.get("target_index", -1))
				var name: String = str(event.get("name", ""))
				var reason: String = str(event.get("reason", ""))

				combat_log.append_text("%s skips the turn (%s)\n" % [name, reason])
				_show_floating_skip(side, target_index, "FROZEN")
				await get_tree().create_timer(0.35).timeout
			"heal":
				var target_side: String = str(event.get("target_side", ""))
				var target_index: int = int(event.get("target_index", -1))
				var target_name: String = str(event.get("target_name", ""))
				var amount: int = int(event.get("amount", 0))
				var remaining_hp: int = int(event.get("remaining_hp", 0))
				var source_name: String = str(event.get("source_name", ""))

				combat_log.append_text("%s heals %s for %d\n" % [source_name, target_name, amount])

				if target_side == "player":
					if target_index >= 0 and target_index < visual_player_team.size():
						visual_player_team[target_index].health = remaining_hp
				elif target_side == "enemy":
					if target_index >= 0 and target_index < visual_enemy_team.size():
						visual_enemy_team[target_index].health = remaining_hp

				_show_floating_heal(target_side, target_index, amount)
				_render_teams()
				await get_tree().create_timer(0.25).timeout
			"attack_changed":
				var target_side: String = str(event.get("target_side", ""))
				var target_name: String = str(event.get("target_name", ""))
				var target_index: int = int(event.get("target_index", -1))
				var amount: int = int(event.get("amount", 0))
				var new_attack: int = int(event.get("new_attack", 0))
				var reason: String = str(event.get("reason", ""))

				combat_log.append_text("%s gains +%d attack from %s\n" % [target_name, amount, reason])

				if target_side == "enemy":
					if target_index >= 0 and target_index < visual_enemy_team.size():
						visual_enemy_team[target_index].attack = new_attack
				elif target_side == "player":
					if target_index >= 0 and target_index < visual_player_team.size():
						visual_player_team[target_index].attack = new_attack

				_render_teams()
				await get_tree().create_timer(0.12).timeout
			"dot_damage":
				var target_side: String = str(event.get("target_side", ""))
				var target_name: String = str(event.get("target_name", ""))
				var target_index: int = int(event.get("target_index", 0))
				var remaining_hp: int = int(event.get("remaining_hp", 0))
				var damage_amount: int = int(event.get("amount", 0))
				var source: String = str(event.get("source", ""))

				combat_log.append_text(
					"%s takes %d %s damage (%d HP left)\n" % [
						target_name, damage_amount, source, remaining_hp
					]
				)

				if source == "burn":
					_show_floating_burn_damage(target_side, target_index, damage_amount)
				elif source == "poison":
					_show_floating_poison_damage(target_side, target_index, damage_amount)
				else:
					_show_floating_damage(target_side, target_index, damage_amount)
				if target_side == "enemy":
					if target_index >= 0 and target_index < visual_enemy_team.size():
						visual_enemy_team[target_index].health = remaining_hp
				elif target_side == "player":
					if target_index >= 0 and target_index < visual_player_team.size():
						visual_player_team[target_index].health = remaining_hp

				_render_teams()
				await get_tree().create_timer(DAMAGE_PAUSE).timeout
			"damage":
				var target_side: String = str(event.get("target_side", ""))
				var target_name: String = str(event.get("target_name", ""))
				var target_index: int = int(event.get("target_index", 0))
				var remaining_hp: int = int(event.get("remaining_hp", 0))
				var damage_amount: int = int(event.get("amount", 0))
				var soaked: bool = bool(event.get("soaked", false))
				var reduced_by: int = int(event.get("reduced_by", 0))

				combat_log.append_text(
					"%s takes %d damage (%d HP left)\n" % [
						target_name, damage_amount, remaining_hp
					]
				)
				_show_floating_damage(target_side, target_index, damage_amount)
				if soaked:
					_show_floating_soak(target_side, target_index, reduced_by)
					await _flash_soak(target_side, target_index)

				await _animate_hit(target_side, target_index)
				if target_side == "enemy":
					if target_index >= 0 and target_index < visual_enemy_team.size():
						visual_enemy_team[target_index].health = remaining_hp
				elif target_side == "player":
					if target_index >= 0 and target_index < visual_player_team.size():
						visual_player_team[target_index].health = remaining_hp

				_render_teams()
				await get_tree().create_timer(DAMAGE_PAUSE).timeout

			"death":
				var dead_side: String = str(event.get("side", ""))
				var dead_name: String = str(event.get("name", ""))
				var dead_index: int = int(event.get("target_index", 0))

				await _animate_death(dead_side, dead_index)

				if dead_side == "enemy":
					if dead_index >= 0 and dead_index < visual_enemy_team.size():
						visual_enemy_team.remove_at(dead_index)
				elif dead_side == "player":
					if dead_index >= 0 and dead_index < visual_player_team.size():
						visual_player_team.remove_at(dead_index)

				_render_teams()
				combat_log.append_text("%s dies!\n" % dead_name)
				await get_tree().create_timer(DEATH_PAUSE).timeout

func _get_holder_node(side: String, index: int) -> Control:
	var row: HBoxContainer = player_row if side == "player" else enemy_row
	if index < 0 or index >= row.get_child_count():
		return null

	var holder = row.get_child(index)
	if holder == null:
		return null

	return holder


func _get_card_node(side: String, index: int) -> Control:
	var holder = _get_holder_node(side, index)
	if holder == null or holder.get_child_count() == 0:
		return null

	return holder.get_child(0)

func _animate_attack(attacker_side: String, attacker_index: int, target_side: String, target_index: int) -> void:
	var attacker = _get_card_node(attacker_side, attacker_index)
	var target = _get_card_node(target_side, target_index)
	if attacker == null:
		return

	var original_pos: Vector2 = attacker.position
	var original_scale: Vector2 = attacker.scale

	var lunge_offset := Vector2(0, -70)
	if attacker_side == "enemy":
		lunge_offset = Vector2(0, 70)

	if target != null:
		var dx = target.get_global_position().x - attacker.get_global_position().x
		lunge_offset.x = clamp(dx * 0.25, -35.0, 35.0)

	var tween = create_tween()
	tween.tween_property(attacker, "position", original_pos + lunge_offset, ATTACK_ANIM_TIME)
	tween.parallel().tween_property(attacker, "scale", Vector2(1.08, 1.08), ATTACK_ANIM_TIME)
	tween.tween_property(attacker, "position", original_pos, ATTACK_ANIM_TIME)
	tween.parallel().tween_property(attacker, "scale", original_scale, ATTACK_ANIM_TIME)

	await tween.finished
func _animate_hit(side: String, index: int) -> void:
	var card = _get_card_node(side, index)
	if card == null:
		return

	var original_pos: Vector2 = card.position
	var original_modulate: Color = card.modulate

	var offset := Vector2(-12, 0)
	if side == "enemy":
		offset = Vector2(12, 0)

	var tween = create_tween()
	tween.tween_property(card, "position", original_pos + offset, HIT_ANIM_TIME)
	tween.parallel().tween_property(card, "modulate", Color(1, 0.25, 0.25), HIT_ANIM_TIME)
	tween.tween_property(card, "position", original_pos, HIT_ANIM_TIME)
	tween.parallel().tween_property(card, "modulate", original_modulate, HIT_ANIM_TIME)

	await tween.finished
	
func _show_floating_damage(side: String, index: int, amount: int) -> void:
	var holder = _get_holder_node(side, index)
	if holder == null:
		return

	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_font_size_override("font_size", 32)
	label.modulate = Color(1, 0.1, 0.1, 1)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	var card_center = holder.get_global_position() + (holder.size / 2.0)
	var local_pos = card_center - global_position
	label.position = local_pos + Vector2(-20, -40)

	var tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -60), 0.6)
	tween.parallel().tween_property(label, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(label, "scale", Vector2(1, 1), 0.2)
	tween.parallel().tween_property(label, "modulate", Color(1, 0.1, 0.1, 0), 0.6)
	tween.finished.connect(func(): label.queue_free())
func _animate_death(side: String, index: int) -> void:
	var card = _get_card_node(side, index)
	if card == null:
		return

	var tween = create_tween()
	tween.tween_property(card, "modulate", Color(1, 0, 0, 1), 0.12)
	tween.tween_property(card, "modulate", Color(1, 0, 0, 0), 0.25)

	await tween.finished
func _on_continue_pressed() -> void:
	#print("Continue pressed")

	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")
	
func _get_monster_from_entry(entry):
	if entry == null:
		return null
	if entry is Dictionary:
		if entry.has("monster"):
			return entry["monster"]
		return entry
	return entry
func _set_background() -> void:
	var texture: Texture2D
	var encounter_id := GameState.get_current_encounter_id()

	var cave_backgrounds: Array[Texture2D] = [
		preload("res://assets/cave/cave.png"),
		preload("res://assets/cave/cave2.png"),
		preload("res://assets/cave/cave3.png"),
		preload("res://assets/cave/cave4.png"),
		preload("res://assets/cave/cave5.png"),
		preload("res://assets/cave/cave6.png"),
	]

	match encounter_id:
		"cave_1", "cave_2", "cave_3", "cave_4", "cave_elite_1", "cave_boss_1":
			if GameState.current_run_background_path != "":
				texture = load(GameState.current_run_background_path)
			else:
				texture = preload("res://assets/cave/cave.png")
		"forest_1":
			texture = preload("res://assets/forest.png")
		"crypt_1":
			texture = preload("res://assets/crypt.png")
		_:
			texture = preload("res://assets/forest.png")

	if background is TextureRect:
		background.texture = texture
	elif background is Sprite2D:
		background.texture = texture
func _show_floating_miss(side: String, index: int) -> void:
	var holder = _get_holder_node(side, index)
	if holder == null:
		return

	var label := Label.new()
	label.text = "MISS"
	label.add_theme_font_size_override("font_size", 26)
	label.modulate = Color(1, 1, 1, 1)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	var card_center = holder.get_global_position() + (holder.size / 2.0)
	var local_pos = card_center - global_position
	label.position = local_pos + Vector2(-28, -35)

	var tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -40), 0.5)
	tween.parallel().tween_property(label, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.finished.connect(func(): label.queue_free())
func _flash_soak(side: String, index: int) -> void:
	var card = _get_card_node(side, index)
	if card == null:
		return

	var original_modulate: Color = card.modulate

	var tween = create_tween()
	tween.tween_property(card, "modulate", Color(0.7, 0.9, 1.0, 1.0), 0.08)
	tween.tween_property(card, "modulate", original_modulate, 0.12)

	await tween.finished


func _show_floating_soak(side: String, index: int, amount: int) -> void:
	var holder = _get_holder_node(side, index)
	if holder == null:
		return

	var label := Label.new()
	label.text = "BLOCK -%d" % amount
	label.add_theme_font_size_override("font_size", 22)
	label.modulate = Color(0.75, 0.9, 1.0, 1.0)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 5)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	var card_center = holder.get_global_position() + (holder.size / 2.0)
	var local_pos = card_center - global_position
	label.position = local_pos + Vector2(-45, -65)

	var tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -35), 0.45)
	tween.parallel().tween_property(label, "modulate", Color(0.75, 0.9, 1.0, 0), 0.45)
	await tween.finished
	label.queue_free()
func _show_floating_burn_damage(side: String, index: int, amount: int) -> void:
	var holder = _get_holder_node(side, index)
	if holder == null:
		return

	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_font_size_override("font_size", 30)

	# 🔥 Burn color (orange/red)
	label.modulate = Color(1.0, 0.4, 0.1, 1.0)

	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)

	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	var card_center = holder.get_global_position() + (holder.size / 2.0)
	var local_pos = card_center - global_position
	label.position = local_pos + Vector2(-20, -40)

	var tween = create_tween()

	# Slightly different feel than normal damage
	tween.tween_property(label, "position", label.position + Vector2(0, -50), 0.5)
	tween.parallel().tween_property(label, "scale", Vector2(1.15, 1.15), 0.2)
	tween.tween_property(label, "scale", Vector2(1, 1), 0.2)

	# fade out
	tween.parallel().tween_property(label, "modulate", Color(1.0, 0.4, 0.1, 0), 0.5)

	await tween.finished
	label.queue_free()
	
func _show_floating_heal(side: String, index: int, amount: int) -> void:
	var holder = _get_holder_node(side, index)
	if holder == null:
		return

	var label := Label.new()
	label.text = "+%d" % amount
	label.add_theme_font_size_override("font_size", 26)
	label.modulate = Color(0.3, 1.0, 0.4, 1.0)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(label)

	var card_center = holder.get_global_position() + (holder.size / 2.0)
	var local_pos = card_center - global_position
	label.position = local_pos + Vector2(-18, -35)

	var tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -45), 0.5)
	tween.parallel().tween_property(label, "modulate", Color(0.3, 1.0, 0.4, 0.0), 0.5)

	await tween.finished
	label.queue_free()
func _show_floating_poison_damage(side: String, index: int, amount: int) -> void:
	var holder = _get_holder_node(side, index)
	if holder == null:
		return

	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_font_size_override("font_size", 30)
	label.modulate = Color(0.35, 1.0, 0.35, 1.0)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(label)

	var card_center = holder.get_global_position() + (holder.size / 2.0)
	var local_pos = card_center - global_position
	label.position = local_pos + Vector2(-20, -40)

	var tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -50), 0.5)
	tween.parallel().tween_property(label, "scale", Vector2(1.12, 1.12), 0.2)
	tween.tween_property(label, "scale", Vector2(1, 1), 0.2)
	tween.parallel().tween_property(label, "modulate", Color(0.35, 1.0, 0.35, 0), 0.5)

	await tween.finished
	label.queue_free()
func _show_floating_skip(side: String, index: int, text: String) -> void:
	var holder = _get_holder_node(side, index)
	if holder == null:
		return

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color(0.55, 0.8, 1.0, 1.0)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(label)

	var card_center = holder.get_global_position() + (holder.size / 2.0)
	var local_pos = card_center - global_position
	label.position = local_pos + Vector2(-35, -38)

	var tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -45), 0.5)
	tween.parallel().tween_property(label, "modulate", Color(0.55, 0.8, 1.0, 0.0), 0.5)

	await tween.finished
	label.queue_free()
func _persist_player_combat_bonuses() -> void:
	var survivors: Array = GameState.pending_result.get("player_survivors", [])

	for survivor in survivors:
		if typeof(survivor) != TYPE_DICTIONARY:
			continue

		var slot_index: int = int(survivor.get("slot_index", -1))
		if slot_index < 0 or slot_index >= GameState.board_monsters.size():
			continue

		var board_monster = GameState.board_monsters[slot_index]
		if board_monster == null:
			continue

		# Persist Blood Rush / Wildfire style permanent combat attack gains
		board_monster.attack = int(survivor.get("attack", board_monster.attack))
func _show_post_combat_rewards() -> void:
	reward_overlay.visible = true
	reward_panel.visible = true
	reward_overlay.move_to_front()
	continue_button.disabled = true
	reward_title.text = "Choose an Instinct"

	for child in reward_choices_row.get_children():
		child.queue_free()

	var survivors: Array = GameState.pending_result.get("player_survivors", [])
	var xp_lines: Array[String] = []

	for survivor in survivors:
		if typeof(survivor) != TYPE_DICTIONARY:
			continue
		xp_lines.append("%s +1 XP" % str(survivor.get("name", "Unit")))

	if xp_lines.is_empty():
		xp_gain_label.text = "No XP gained."
	else:
		xp_gain_label.text = "XP Gain:\n" + "\n".join(xp_lines)

	var choices: Array = GameState.build_instinct_reward_choices(3)

	for instinct in choices:
		var button := Button.new()
		button.custom_minimum_size = Vector2(210, 110)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s\n%s" % [
			str(instinct.get("name", "Instinct")),
			str(instinct.get("description", ""))
		]

		button.pressed.connect(func():
			_take_reward_choice(instinct)
		)

		reward_choices_row.add_child(button)

func _take_reward_choice(instinct: Dictionary) -> void:
	GameState.add_instinct_reward_to_hand(instinct)
	combat_log.append_text("You gained %s.\n" % str(instinct.get("name", "Instinct")))
	reward_overlay.visible = false
	continue_button.disabled = false
func _build_battle_state() -> void:
	
	player_units.clear()
	enemy_units.clear()
	battle_over = false
	selected_action = ""
	player_turn_cursor = 0
	enemy_turn_cursor = 0
	current_player_index = -1
	current_enemy_index = -1
	current_side = "player"
	current_player_index = -1

	for i in range(GameState.pending_player_team.size()):
		var monster = _get_monster_from_entry(GameState.pending_player_team[i])
		if monster != null:
			player_units.append(_monster_to_battle_unit(monster, "player", i))

	for i in range(GameState.pending_enemy_team.size()):
		var monster = _get_monster_from_entry(GameState.pending_enemy_team[i])
		if monster != null:
			enemy_units.append(_monster_to_battle_unit(monster, "enemy", i))


func _monster_to_battle_unit(monster, side: String, index: int) -> Dictionary:
	var instinct_id := ""
	var target_rule := "front"
	var action_rule := "attack_only"
	var base_speed := 35.0

	if monster.display_name == "Pebble":
		instinct_id = "taunt"
		target_rule = "self"
		action_rule = "attack_only"
		base_speed = 30.0
	elif monster.display_name == "Imp":
		instinct_id = "ignite"
		target_rule = "lowest_hp"
		action_rule = "attack_only"
		base_speed = 42.0
	elif monster.display_name == "Slime":
		instinct_id = "oil"
		target_rule = "lowest_hp"
		action_rule = "attack_only"
		base_speed = 32.0
	elif monster.display_name == "Frost Wisp":
		instinct_id = "freeze"
		target_rule = "lowest_hp"
		action_rule = "attack_only"
		base_speed = 38.0
	elif monster.display_name == "Fang Adder":
		instinct_id = "poison"
		target_rule = "lowest_hp"
		action_rule = "attack_only"
		base_speed = 36.0

	var speed_roll: float = randf_range(-3.0, 3.0)
	var final_speed: float = maxf(20.0, base_speed + speed_roll)
	var starting_atb: float = randf_range(0.0, 35.0)

	return {
		"name": monster.display_name,
		"side": side,
		"index": index,
		"slot_index": index,
		"attack": int(monster.attack),
		"health": int(monster.health),
		"max_health": int(monster.max_health),
		"is_defending": false,
		"is_taunting": false,
		"instinct_used": false,
		"queued_action": "",
		"source_monster": monster,
		"instinct_id": instinct_id,
		"modifiers": monster.modifiers.duplicate() if "modifiers" in monster else [],
		"target_rule": target_rule,
		"action_rule": action_rule,
		"atb": starting_atb,
		"atb_max": 100.0,
		"is_ready": false,
		"ready_time": 0.0,
		"speed": final_speed,
		"queued_target_index": -1,
		"instinct_cooldown_remaining": 0,
		"used_instinct_this_action": false,
	}
func _get_instinct_cooldown_remaining(unit: Dictionary) -> int:
	return int(unit.get("instinct_cooldown_remaining", 0))


func _get_instinct_button_display_text(unit: Dictionary) -> String:
	var base_text := _get_instinct_button_text(unit)
	var cooldown := _get_instinct_cooldown_remaining(unit)

	if cooldown > 0:
		return "%s (%d)" % [base_text, cooldown]

	return base_text
func _get_taunting_player_index() -> int:
	for i in range(player_units.size()):
		var unit = player_units[i]
		if int(unit["health"]) <= 0:
			continue
		if bool(unit.get("is_taunting", false)):
			return i
	return -1


func _get_enemy_target_index() -> int:
	var taunt_index := _get_taunting_player_index()
	if taunt_index != -1:
		return taunt_index

	return _get_random_alive_index(player_units)
func _get_next_alive_index(units: Array, start_index: int) -> int:
	if units.is_empty():
		return -1

	for offset in range(units.size()):
		var i = (start_index + offset) % units.size()
		if int(units[i]["health"]) > 0:
			return i

	return -1
func _build_battle_ui() -> void:
	battle_ui = VBoxContainer.new()
	battle_ui.anchor_left = 0.5
	battle_ui.anchor_right = 0.5
	battle_ui.anchor_top = 1.0
	battle_ui.anchor_bottom = 1.0
	battle_ui.offset_left = -260
	battle_ui.offset_right = 260
	battle_ui.offset_top = -95
	battle_ui.offset_bottom = -10
	battle_ui.visible = false
	battle_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(battle_ui)

	turn_info_label = Label.new()
	turn_info_label.text = "Battle Start"
	battle_ui.add_child(turn_info_label)

	action_row = HBoxContainer.new()
	battle_ui.add_child(action_row)

	attack_button = Button.new()
	attack_button.text = "Attack"
	attack_button.pressed.connect(_on_attack_pressed)
	action_row.add_child(attack_button)

	defend_button = Button.new()
	defend_button.text = "Defend"
	defend_button.pressed.connect(_on_defend_pressed)
	action_row.add_child(defend_button)

	instinct_button = Button.new()
	instinct_button.text = "Instinct"
	instinct_button.pressed.connect(_on_instinct_pressed)
	action_row.add_child(instinct_button)

	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(_on_pause_pressed)
	action_row.add_child(pause_button)

	target_row = HBoxContainer.new()
	battle_ui.add_child(target_row)
func _start_player_turn() -> void:
	instinct_button.disabled = false
	if battle_over:
		return

	if _all_dead(enemy_units):
		_end_battle(true)
		return

	if _all_dead(player_units):
		_end_battle(false)
		return

	current_side = "player"
	current_player_index = _get_next_alive_index(player_units, player_turn_cursor)

	if current_player_index == -1:
		_end_battle(false)
		return

	selected_action = ""
	_clear_target_buttons()

	attack_button.disabled = false
	defend_button.disabled = false

	var actor = player_units[current_player_index]
	turn_info_label.text = "%s's turn" % actor["name"]
	combat_log.append_text("\n%s's turn.\n" % actor["name"])
func _get_first_alive_index(units: Array) -> int:
	for i in range(units.size()):
		if int(units[i]["health"]) > 0:
			return i
	return -1


func _all_dead(units: Array) -> bool:
	for unit in units:
		if int(unit["health"]) > 0:
			return false
	return true
func _on_attack_pressed() -> void:
	if battle_over:
		return
	if not battle_paused:
		return
	if action_in_progress:
		return
	if manual_selected_player_index == -1:
		return

	selected_action = "queue_attack"
	turn_info_label.text = "Choose an enemy target"
	_refresh_visual_units()
func _on_defend_pressed() -> void:
	pass
func _on_enemy_card_pressed(index: int) -> void:
	pass
func _show_enemy_target_buttons() -> void:
	_clear_target_buttons()

	for i in range(enemy_units.size()):
		var unit = enemy_units[i]
		if int(unit["health"]) <= 0:
			continue

		var btn := Button.new()
		btn.text = "%s (%d HP)" % [unit["name"], unit["health"]]
		btn.pressed.connect(func(): _on_enemy_target_selected(i))
		target_row.add_child(btn)


func _clear_target_buttons() -> void:
	if target_row == null:
		return

	for child in target_row.get_children():
		child.queue_free()
func _on_enemy_target_selected(target_index: int) -> void:
	if battle_over:
		return

	match selected_action:
		"attack":
			await _perform_player_attack(target_index)
		"instinct":
			await _perform_player_instinct(target_index)
func _perform_player_attack_from_index(attacker_index: int, target_index: int) -> void:
	if attacker_index < 0 or attacker_index >= player_units.size():
		action_in_progress = false
		return

	if target_index < 0 or target_index >= enemy_units.size():
		action_in_progress = false
		return

	var attacker = player_units[attacker_index]
	var defender = enemy_units[target_index]

	if int(attacker["health"]) <= 0 or int(defender["health"]) <= 0:
		_finish_unit_action("player", attacker_index)
		return

	combat_log.append_text("%s attacks %s\n" % [attacker["name"], defender["name"]])

	await _animate_attack("player", attacker_index, "enemy", target_index)

	var damage := int(attacker["attack"])
	if bool(defender["is_defending"]):
		damage = int(ceil(float(damage) * 0.5))

	defender["health"] = max(0, int(defender["health"]) - damage)
	defender["is_defending"] = false

	_show_floating_damage("enemy", target_index, damage)
	await _animate_hit("enemy", target_index)

	combat_log.append_text("%s takes %d damage (%d HP left)\n" % [
		defender["name"], damage, defender["health"]
	])

	_update_card_from_unit("player", attacker_index)
	_update_card_from_unit("enemy", target_index)
	_update_atb_bars()
	_update_target_lines()
	_clear_target_buttons()

	if int(defender["health"]) <= 0:
		await _handle_unit_death("enemy", target_index)

	if _all_dead(enemy_units):
		_end_battle(true)
		return

	await get_tree().create_timer(0.2).timeout
	_finish_unit_action("player", attacker_index)
func _auto_enemy_action(index: int) -> void:
	if battle_over:
		action_in_progress = false
		return

	if index < 0 or index >= enemy_units.size():
		action_in_progress = false
		return

	var skipped := await _resolve_pre_action_statuses("enemy", index)
	if skipped:
		_finish_unit_action("enemy", index)
		return

	if battle_over:
		action_in_progress = false
		return

	if index < 0 or index >= enemy_units.size():
		action_in_progress = false
		return

	var attacker = enemy_units[index]
	if int(attacker["health"]) <= 0:
		_finish_unit_action("enemy", index)
		return

	if not bool(attacker["is_ready"]):
		action_in_progress = false
		return

	var target_index := _get_enemy_target_index()
	if target_index == -1:
		_end_battle(false)
		return

	await _perform_enemy_attack_from_index(index, target_index)
func _handle_unit_death(side: String, index: int) -> void:
	var name := ""
	if side == "enemy" and index >= 0 and index < enemy_units.size():
		name = enemy_units[index]["name"]
	elif side == "player" and index >= 0 and index < player_units.size():
		name = player_units[index]["name"]

	await _animate_death(side, index)
	combat_log.append_text("%s dies!\n" % name)
	_refresh_visual_units()
func _refresh_visual_units() -> void:
	visual_enemy_team.clear()
	visual_player_team.clear()

	for unit in enemy_units:
		var src = unit["source_monster"]
		var copy = src.duplicate(true)
		copy.health = int(unit["health"])
		copy.modifiers = unit.get("modifiers", []).duplicate()
		visual_enemy_team.append(copy)

	for unit in player_units:
		var src = unit["source_monster"]
		var copy = src.duplicate(true)
		copy.health = int(unit["health"])
		copy.modifiers = unit.get("modifiers", []).duplicate()
		visual_player_team.append(copy)

	_render_teams()
	_update_atb_bars()
	_update_target_lines()
func _end_battle(player_won: bool) -> void:
	instinct_button.disabled = true
	if battle_over:
		return

	battle_paused = false
	_update_pause_dim()
	battle_over = true

	if battle_ui != null:
		battle_ui.visible = false

	attack_button.disabled = true
	defend_button.disabled = true
	_clear_target_buttons()

	GameState.pending_result = {
		"player_won": player_won,
		"player_survivors": _build_player_survivors(),
		"enemy_survivors": _build_enemy_survivors(),
		"events": []
	}

	_refresh_visual_units()
	_persist_player_combat_bonuses()

	if player_won:
		result_label.text = "Victory!"
		await _show_post_combat_rewards()
	else:
		result_label.text = "Defeat!"
		continue_button.disabled = false
func _build_player_survivors() -> Array:
	var survivors: Array = []

	for i in range(player_units.size()):
		var unit = player_units[i]
		if int(unit["health"]) <= 0:
			continue

		survivors.append({
			"name": unit["name"],
			"slot_index": i,
			"attack": int(unit["attack"]),
			"health": int(unit["health"]),
			"max_health": int(unit["max_health"])
		})

	return survivors
func _build_enemy_survivors() -> Array:
	var survivors: Array = []

	for i in range(enemy_units.size()):
		var unit = enemy_units[i]
		if int(unit["health"]) <= 0:
			continue

		survivors.append({
			"name": unit["name"],
			"slot_index": i,
			"attack": int(unit["attack"]),
			"health": int(unit["health"]),
			"max_health": int(unit["max_health"])
		})

	return survivors
func _get_random_alive_index(units: Array) -> int:
	var alive_indices: Array = []

	for i in range(units.size()):
		if int(units[i]["health"]) > 0:
			alive_indices.append(i)

	if alive_indices.is_empty():
		return -1

	return alive_indices[randi() % alive_indices.size()]
	
func _on_instinct_pressed() -> void:
	if battle_over:
		return
	if not battle_paused:
		return
	if action_in_progress:
		return
	if manual_selected_player_index == -1:
		return
	if manual_selected_player_index < 0 or manual_selected_player_index >= player_units.size():
		return

	var unit = player_units[manual_selected_player_index]
	if int(unit["health"]) <= 0:
		return

	var instinct_id := str(unit.get("instinct_id", ""))
	if instinct_id == "":
		return

	var cooldown := _get_instinct_cooldown_remaining(unit)
	if cooldown > 0:
		turn_info_label.text = "%s is on cooldown for %d more turns" % [unit["name"], cooldown]
		return

	if instinct_id == "taunt":
		unit["queued_action"] = "taunt"
		selected_action = ""
		drag_assigning = false
		drag_start_player_index = -1
		drag_hover_enemy_index = -1

		turn_info_label.text = "%s will use Taunt when ready" % unit["name"]
		combat_log.append_text("%s will use Taunt when ready.\n" % unit["name"])

		_refresh_cards_light()
		_update_target_lines()
		return

	var existing_target_index: int = int(unit.get("queued_target_index", -1))
	if existing_target_index >= 0 and existing_target_index < enemy_units.size() and int(enemy_units[existing_target_index]["health"]) > 0:
		unit["queued_action"] = instinct_id
		selected_action = ""

		turn_info_label.text = "%s will use %s on %s" % [
			unit["name"],
			_get_instinct_button_text(unit),
			enemy_units[existing_target_index]["name"]
		]
		combat_log.append_text("%s will use %s on %s.\n" % [
			unit["name"],
			_get_instinct_button_text(unit),
			enemy_units[existing_target_index]["name"]
		])

		_refresh_cards_light()
		_update_target_lines()
		return

	selected_action = "queue_instinct"
	turn_info_label.text = "Drag an enemy to queue %s" % _get_instinct_button_text(unit)
	_refresh_visual_units()
func _perform_player_instinct(target_index: int) -> void:
	if ready_side != "player":
		return
	if ready_index < 0 or ready_index >= player_units.size():
		return

	action_in_progress = true
	var attacker = player_units[ready_index]
	var instinct_id = str(attacker.get("instinct_id", ""))

	if int(attacker["health"]) <= 0:
		return

	match instinct_id:
		"taunt":
			combat_log.append_text("%s uses Taunt!\n" % attacker["name"])

			attacker["is_taunting"] = true

			var attacker_mods: Array = attacker.get("modifiers", []).duplicate()
			if not attacker_mods.has("taunt"):
				attacker_mods.append("taunt")
			attacker["modifiers"] = attacker_mods

			_update_card_from_unit("player", ready_index)
			_update_atb_bars()
			_update_target_lines()

			await get_tree().create_timer(0.2).timeout
			_finish_unit_action("player", ready_index)

		"ignite":
			if target_index < 0 or target_index >= enemy_units.size():
				action_in_progress = false
				return

			var defender = enemy_units[target_index]
			var damage := 2
			var target_mods: Array = defender.get("modifiers", [])

			if target_mods.has("greased"):
				damage += 3

			combat_log.append_text("%s uses Ignite on %s\n" % [attacker["name"], defender["name"]])

			await _animate_attack("player", ready_index, "enemy", target_index)

			defender["health"] = max(0, int(defender["health"]) - damage)

			if not target_mods.has("burning"):
				target_mods.append("burning")
			defender["modifiers"] = target_mods

			_show_floating_burn_damage("enemy", target_index, damage)
			await _animate_hit("enemy", target_index)

			combat_log.append_text("%s takes %d fire damage (%d HP left)\n" % [
				defender["name"], damage, defender["health"]
			])

			_update_card_from_unit("player", ready_index)
			_update_card_from_unit("enemy", target_index)
			_update_atb_bars()
			_update_target_lines()
			_clear_target_buttons()

			if int(defender["health"]) <= 0:
				await _handle_unit_death("enemy", target_index)

			if _all_dead(enemy_units):
				_end_battle(true)
				return

			await get_tree().create_timer(0.2).timeout
			_finish_unit_action("player", ready_index)
func _process(delta: float) -> void:
	if battle_over:
		return

	if battle_paused:
		_update_target_lines()
		_update_atb_bars()
		return

	if action_in_progress:
		_update_target_lines()
		_update_atb_bars()
		return

	if _all_dead(enemy_units):
		_end_battle(true)
		return

	if _all_dead(player_units):
		_end_battle(false)
		return

	_fill_atb_for_side(player_units, "player", delta)
	if battle_over or action_in_progress:
		_update_target_lines()
		_update_atb_bars()
		return

	_fill_atb_for_side(enemy_units, "enemy", delta)
	_update_target_lines()
	_update_atb_bars()
func _fill_atb_for_side(units: Array, side: String, delta: float) -> void:
	for i in range(units.size()):
		var unit = units[i]

		if int(unit["health"]) <= 0:
			continue

		if not bool(unit["is_ready"]):
			unit["atb"] += float(unit["speed"]) * delta * BATTLE_SPEED_SCALE

			if unit["atb"] >= float(unit["atb_max"]):
				unit["atb"] = float(unit["atb_max"])
				unit["is_ready"] = true
				unit["ready_time"] = 0.0

				if side == "player":
					combat_log.append_text("%s is ready.\n" % unit["name"])
				else:
					action_in_progress = true
					call_deferred("_auto_enemy_action", i)
					return
		else:
			if side == "player":
				unit["ready_time"] += delta
				if unit["ready_time"] >= PLAYER_AUTO_ACTION_DELAY:
					action_in_progress = true
					call_deferred("_auto_player_action", i)
					return
func _on_unit_ready(side: String, index: int) -> void:
	if battle_over:
		return

	ready_side = side
	ready_index = index

	if side == "enemy":
		action_in_progress = true
		call_deferred("_auto_enemy_action", index)
		return

	combat_log.append_text("%s ready!\n" % player_units[index]["name"])
	battle_paused_for_input = true

	var actor = player_units[index]
	var instinct_id = str(actor.get("instinct_id", ""))

	attack_button.disabled = false
	defend_button.disabled = false
	instinct_button.disabled = instinct_id == ""

	turn_info_label.text = "%s is ready" % actor["name"]
	combat_log.append_text("\n%s is ready.\n" % actor["name"])
func _finish_unit_action(side: String, index: int) -> void:
	var units = player_units if side == "player" else enemy_units

	if index < 0 or index >= units.size():
		return

	var used_instinct_this_action := bool(units[index].get("used_instinct_this_action", false))
	var cooldown_remaining := int(units[index].get("instinct_cooldown_remaining", 0))

	if used_instinct_this_action:
		units[index]["instinct_cooldown_remaining"] = INSTINCT_COOLDOWN_TURNS
		units[index]["used_instinct_this_action"] = false
	else:
		if cooldown_remaining > 0:
			units[index]["instinct_cooldown_remaining"] = max(0, cooldown_remaining - 1)

	if side == "player":
		units[index]["queued_action"] = ""

	units[index]["atb"] = 0.0
	units[index]["is_ready"] = false
	units[index]["ready_time"] = 0.0
	units[index]["is_defending"] = false if side == "enemy" else units[index]["is_defending"]

	if side == "player":
		battle_paused_for_input = false
		ready_side = ""
		ready_index = -1

	if side == "player" and manual_selected_player_index == index:
		manual_selected_player_index = -1
		selected_action = ""

	action_in_progress = false

	attack_button.disabled = true
	defend_button.disabled = true
	instinct_button.disabled = true
	instinct_button.text = "Instinct"
	_clear_target_buttons()
	_refresh_cards_light()
func _on_pause_pressed() -> void:
	_set_battle_paused_state(not battle_paused)

	if not battle_paused:
		manual_selected_player_index = -1
		selected_action = ""
		attack_button.disabled = true
		defend_button.disabled = true
		instinct_button.disabled = true
		instinct_button.text = "Instinct"
		pending_player_click_index = -1
		pending_drag_started = false
		drag_assigning = false
		drag_start_player_index = -1
		drag_hover_enemy_index = -1
		_clear_target_buttons()
		_refresh_visual_units()
	else:
		_refresh_visual_units()
func _auto_player_action(index: int) -> void:
	if battle_over:
		action_in_progress = false
		return

	if index < 0 or index >= player_units.size():
		action_in_progress = false
		return

	if int(player_units[index]["health"]) <= 0:
		_finish_unit_action("player", index)
		return

	if not bool(player_units[index]["is_ready"]):
		action_in_progress = false
		return

	var skipped := await _resolve_pre_action_statuses("player", index)
	if skipped:
		_finish_unit_action("player", index)
		return

	if index < 0 or index >= player_units.size():
		action_in_progress = false
		return

	if int(player_units[index]["health"]) <= 0:
		return

	var queued_action := str(player_units[index].get("queued_action", ""))
	var cooldown_remaining := _get_instinct_cooldown_remaining(player_units[index])

	# If cooldown is active, clear any stale queued instinct and fall back to attack.
	if cooldown_remaining > 0 and queued_action != "":
		player_units[index]["queued_action"] = ""
		queued_action = ""

	if queued_action == "taunt":
		await _perform_player_taunt_from_index(index)
		return

	if queued_action == "ignite" or queued_action == "burn" or queued_action == "oil" or queued_action == "freeze" or queued_action == "poison":
		var queued_target_index: int = int(player_units[index].get("queued_target_index", -1))
		if queued_target_index >= 0 and queued_target_index < enemy_units.size() and int(enemy_units[queued_target_index]["health"]) > 0:
			await _perform_player_targeted_instinct_from_index(index, queued_target_index, queued_action)
			return
		else:
			player_units[index]["queued_action"] = ""

	var target_index: int = int(player_units[index].get("queued_target_index", -1))

	if target_index < 0 or target_index >= enemy_units.size() or int(enemy_units[target_index]["health"]) <= 0:
		target_index = _get_random_alive_index(enemy_units)
		if target_index == -1:
			_end_battle(true)
			return

	await _perform_player_attack_from_index(index, target_index)
func _perform_enemy_attack_from_index(attacker_index: int, target_index: int) -> void:
	if attacker_index < 0 or attacker_index >= enemy_units.size():
		return
	if target_index < 0 or target_index >= player_units.size():
		return

	var attacker = enemy_units[attacker_index]
	var defender = player_units[target_index]

	if int(attacker["health"]) <= 0 or int(defender["health"]) <= 0:
		return

	combat_log.append_text("%s attacks %s\n" % [attacker["name"], defender["name"]])

	await _animate_attack("enemy", attacker_index, "player", target_index)

	var damage := int(attacker["attack"])
	if bool(defender["is_defending"]):
		damage = int(ceil(float(damage) * 0.5))
	var defender_was_taunting := bool(defender.get("is_taunting", false))
	defender["health"] = max(0, int(defender["health"]) - damage)
	defender["is_defending"] = false
	
	_show_floating_damage("player", target_index, damage)
	await _animate_hit("player", target_index)
	if defender_was_taunting:
		defender["is_taunting"] = false
		var defender_mods: Array = defender.get("modifiers", []).duplicate()
		defender_mods.erase("taunt")
		defender["modifiers"] = defender_mods
	combat_log.append_text("%s takes %d damage (%d HP left)\n" % [
		defender["name"], damage, defender["health"]
	])

	_update_card_from_unit("enemy", attacker_index)
	_update_card_from_unit("player", target_index)
	_update_atb_bars()
	_update_target_lines()

	if int(defender["health"]) <= 0:
		await _handle_unit_death("player", target_index)

	if _all_dead(player_units):
		_end_battle(false)
		return

	await get_tree().create_timer(0.2).timeout
	_finish_unit_action("enemy", attacker_index)
func _perform_player_attack(target_index: int) -> void:
	if ready_side != "player":
		return
	if ready_index < 0 or ready_index >= player_units.size():
		return
	if target_index < 0 or target_index >= enemy_units.size():
		return

	action_in_progress = true
func _on_player_card_pressed(index: int) -> void:
	if battle_over:
		return
	if action_in_progress:
		return
	if index < 0 or index >= player_units.size():
		return

	var unit = player_units[index]
	if int(unit["health"]) <= 0:
		return

	battle_paused = true
	pause_button.text = "Resume"
	_update_pause_dim()

	manual_selected_player_index = index
	selected_action = "queue_attack"

	drag_assigning = true
	drag_start_player_index = index
	drag_hover_enemy_index = -1
	drag_mouse_local = get_local_mouse_position()

	attack_button.disabled = false
	defend_button.disabled = false
	instinct_button.disabled = str(unit.get("instinct_id", "")) == ""

	turn_info_label.text = "Drag to an enemy for %s" % unit["name"]
	combat_log.append_text("%s selected.\n" % unit["name"])

	_refresh_visual_units()
	_update_target_lines()
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_pause_pressed()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		drag_mouse_local = get_local_mouse_position()

		if pending_player_click_index != -1 and not drag_assigning:
			var drag_distance := pending_drag_start_pos.distance_to(drag_mouse_local)
			if drag_distance >= DRAG_START_DISTANCE:
				pending_drag_started = true
				_begin_drag_assignment(pending_player_click_index)

		if drag_assigning:
			_update_target_lines()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if drag_assigning:
				_finish_drag_target_assignment()
				get_viewport().set_input_as_handled()

			pending_player_click_index = -1
			pending_drag_started = false
func _finish_drag_target_assignment() -> void:
	if drag_start_player_index == -1:
		drag_assigning = false
		drag_start_player_index = -1
		drag_hover_enemy_index = -1
		_update_target_lines()
		return

	var assigning_player_index := drag_start_player_index
	var release_enemy_index := _get_enemy_index_under_mouse()
	var had_valid_assignment := false

	if release_enemy_index >= 0 and release_enemy_index < enemy_units.size():
		if int(enemy_units[release_enemy_index]["health"]) > 0:
			var attacker = player_units[assigning_player_index]
			var defender = enemy_units[release_enemy_index]

			player_units[assigning_player_index]["queued_target_index"] = release_enemy_index
			had_valid_assignment = true

			if selected_action == "queue_instinct":
				var instinct_id := str(attacker.get("instinct_id", ""))
				player_units[assigning_player_index]["queued_action"] = instinct_id
				combat_log.append_text("%s will use %s on %s.\n" % [
					attacker["name"],
					_get_instinct_button_text(attacker),
					defender["name"]
				])
				turn_info_label.text = "%s will %s %s" % [
					attacker["name"],
					_get_instinct_button_text(attacker),
					defender["name"]
				]
			else:
				player_units[assigning_player_index]["queued_action"] = ""
				combat_log.append_text("%s will focus %s.\n" % [attacker["name"], defender["name"]])
				turn_info_label.text = "%s will target %s" % [attacker["name"], defender["name"]]

	drag_assigning = false
	drag_start_player_index = -1
	drag_hover_enemy_index = -1
	selected_action = ""

	# Keep the acting unit selected after assignment so the player can press Oil/Ignite/etc.
	if had_valid_assignment:
		manual_selected_player_index = assigning_player_index
	else:
		manual_selected_player_index = -1

	_refresh_selected_unit_buttons()
	_refresh_visual_units()
	_update_target_lines()
func _get_holder_center_local(side: String, index: int) -> Vector2:
	var holder = _get_holder_node(side, index)
	if holder == null:
		return Vector2.ZERO

	var global_center = holder.get_global_position() + (holder.size / 2.0)
	return global_center - global_position
func _build_line_overlay() -> void:
	line_layer = Node2D.new()
	line_layer.z_index = 500
	add_child(line_layer)
	move_child(line_layer, get_child_count() - 1)

	drag_line = Line2D.new()
	drag_line.width = 5.0
	drag_line.default_color = Color(0.4, 0.9, 1.0, 0.95)
	drag_line.visible = false
	line_layer.add_child(drag_line)
func _update_target_lines() -> void:
	if line_layer == null:
		return

	for child in line_layer.get_children():
		if child != drag_line:
			child.queue_free()

	for i in range(player_units.size()):
		var unit = player_units[i]
		if int(unit["health"]) <= 0:
			continue

		# Hide the persistent line for the unit currently being reassigned.
		if drag_assigning and i == drag_start_player_index:
			continue

		var target_index: int = int(unit.get("queued_target_index", -1))
		if target_index < 0 or target_index >= enemy_units.size():
			continue
		if int(enemy_units[target_index]["health"]) <= 0:
			continue

		var start_pos = _get_holder_center_local("player", i)
		var end_pos = _get_holder_center_local("enemy", target_index)

		var line := Line2D.new()
		line.width = 4.0
		line.default_color = Color(0.9, 0.85, 0.3, 0.85)
		line.points = PackedVector2Array([start_pos, end_pos])
		line_layer.add_child(line)

	if drag_assigning and drag_start_player_index != -1:
		var start_pos = _get_holder_center_local("player", drag_start_player_index)
		var end_pos = drag_mouse_local

		drag_line.points = PackedVector2Array([start_pos, end_pos])
		drag_line.visible = true
	else:
		drag_line.visible = false
		drag_line.points = PackedVector2Array()
func _get_enemy_index_under_mouse() -> int:
	var mouse_global := get_global_mouse_position()

	for i in range(enemy_row.get_child_count()):
		if i >= enemy_units.size():
			continue
		if int(enemy_units[i]["health"]) <= 0:
			continue

		var holder = enemy_row.get_child(i)
		if holder == null:
			continue

		var rect := Rect2(holder.get_global_position(), holder.size)
		if rect.has_point(mouse_global):
			return i

	return -1
func _on_player_card_button_down(index: int) -> void:
	if battle_over:
		return
	if action_in_progress:
		return
	if index < 0 or index >= player_units.size():
		return

	var unit = player_units[index]
	if int(unit["health"]) <= 0:
		return

	_select_player_card(index)

	pending_player_click_index = index
	pending_drag_started = false
	pending_drag_start_pos = get_local_mouse_position()
func _build_pause_dim() -> void:
	pause_dim = ColorRect.new()
	pause_dim.anchor_left = 0.0
	pause_dim.anchor_top = 0.0
	pause_dim.anchor_right = 1.0
	pause_dim.anchor_bottom = 1.0
	pause_dim.offset_left = 0
	pause_dim.offset_top = 0
	pause_dim.offset_right = 0
	pause_dim.offset_bottom = 0
	pause_dim.color = Color(0, 0, 0, 0.28)
	pause_dim.visible = false
	pause_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pause_dim)
func _update_atb_bars() -> void:
	for i in range(player_units.size()):
		var card = _get_card_node("player", i)
		if card != null and card.has_method("set_atb"):
			card.set_atb(
				float(player_units[i]["atb"]),
				float(player_units[i]["atb_max"]),
				bool(player_units[i]["is_ready"])
			)

	for i in range(enemy_units.size()):
		var card = _get_card_node("enemy", i)
		if card != null and card.has_method("set_atb"):
			card.set_atb(
				float(enemy_units[i]["atb"]),
				float(enemy_units[i]["atb_max"]),
				bool(enemy_units[i]["is_ready"])
			)
func _update_battle_ui_visibility() -> void:
	if battle_ui == null:
		return

	battle_ui.visible = battle_paused and not battle_over
func _get_player_intent_text(index: int) -> String:
	if index < 0 or index >= player_units.size():
		return ""

	var unit = player_units[index]
	if int(unit["health"]) <= 0:
		return "DEAD"

	if bool(unit.get("is_taunting", false)):
		return "TAUNTING"

	if bool(unit.get("is_defending", false)):
		return "DEFEND"

	var instinct_id := str(unit.get("instinct_id", ""))
	var queued_action := str(unit.get("queued_action", ""))
	var target_index: int = int(unit.get("queued_target_index", -1))
	var cooldown := _get_instinct_cooldown_remaining(unit)

	if cooldown > 0:
		return "COOLDOWN: %d" % cooldown

	if queued_action == "taunt":
		return "QUEUED: TAUNT"

	if queued_action == "ignite" or queued_action == "burn" or queued_action == "oil" or queued_action == "freeze" or queued_action == "poison":
		if target_index >= 0 and target_index < enemy_units.size() and int(enemy_units[target_index]["health"]) > 0:
			return "QUEUED: %s %s" % [
				queued_action.capitalize(),
				enemy_units[target_index]["name"]
			]
		return "QUEUED: %s" % queued_action.capitalize()

	if bool(unit.get("is_ready", false)):
		return "READY: ATTACK"

	if target_index >= 0 and target_index < enemy_units.size() and int(enemy_units[target_index]["health"]) > 0:
		return "TARGET: %s" % enemy_units[target_index]["name"]

	return "AUTO: ATTACK"
func _get_enemy_intent_text(index: int) -> String:
	if index < 0 or index >= enemy_units.size():
		return ""

	var unit = enemy_units[index]
	if int(unit["health"]) <= 0:
		return "DEAD"

	var instinct_id := str(unit.get("instinct_id", ""))
	if instinct_id == "ignite":
		return "IGNITE"

	return "ATTACK"
func _update_card_from_unit(side: String, index: int) -> void:
	var card = _get_card_node(side, index)
	if card == null:
		return

	var units = player_units if side == "player" else enemy_units
	if index < 0 or index >= units.size():
		return

	var unit = units[index]
	var src = unit["source_monster"]
	var copy = src.duplicate(true)
	copy.health = int(unit["health"])
	copy.attack = int(unit["attack"])
	copy.modifiers = unit.get("modifiers", []).duplicate()

	var intent_text := ""
	if battle_over:
		intent_text = ""
	elif side == "player":
		intent_text = _get_player_intent_text(index)
	else:
		intent_text = _get_enemy_intent_text(index)

	if card.has_method("set_combat_mode"):
		card.set_combat_mode(not battle_over)

	if card.has_method("set_combat_ui"):
		card.set_combat_ui(not battle_over)

	if card.has_method("update_combat_snapshot"):
		card.update_combat_snapshot(
			copy,
			intent_text,
			bool(unit["is_ready"]),
			float(unit["atb"]),
			float(unit["atb_max"])
		)
	else:
		if card.has_method("setup"):
			card.setup(copy)

	# Force intent text every time, even on the live-combat snapshot path.
	if card.has_method("set_intent_text"):
		card.set_intent_text(intent_text)

	if card.has_method("set_atb"):
		card.set_atb(
			float(unit["atb"]),
			float(unit["atb_max"]),
			bool(unit["is_ready"])
		)

	if int(unit["health"]) <= 0:
		card.modulate = Color(1, 1, 1, 0.35)
	else:
		card.modulate = Color(1, 1, 1, 1)
func _refresh_cards_light() -> void:
	for i in range(player_units.size()):
		_update_card_from_unit("player", i)

	for i in range(enemy_units.size()):
		_update_card_from_unit("enemy", i)

	_update_atb_bars()
	_update_target_lines()
func _perform_player_taunt_from_index(attacker_index: int) -> void:
	if attacker_index < 0 or attacker_index >= player_units.size():
		action_in_progress = false
		return

	if int(player_units[attacker_index]["health"]) <= 0:
		_finish_unit_action("player", attacker_index)
		return

	player_units[attacker_index]["used_instinct_this_action"] = true
	player_units[attacker_index]["queued_action"] = ""
	player_units[attacker_index]["is_taunting"] = true

	var attacker = player_units[attacker_index]

	combat_log.append_text("%s uses Taunt!\n" % attacker["name"])

	var attacker_mods: Array = attacker.get("modifiers", []).duplicate()
	if not attacker_mods.has("taunt"):
		attacker_mods.append("taunt")
	attacker["modifiers"] = attacker_mods

	_update_card_from_unit("player", attacker_index)
	_update_atb_bars()
	_update_target_lines()

	await get_tree().create_timer(0.2).timeout
	_finish_unit_action("player", attacker_index)
func _get_instinct_button_text(unit: Dictionary) -> String:
	var instinct_id := str(unit.get("instinct_id", ""))

	match instinct_id:
		"taunt":
			return "Taunt"
		"ignite":
			return "Ignite"
		"oil":
			return "Oil"
		"freeze":
			return "Freeze"
		"burn":
			return "Burn"
		"poison":
			return "Poison"
		"":
			return "Instinct"
		_:
			return instinct_id.replace("_", " ").capitalize()
func _select_player_card(index: int) -> void:
	if battle_over:
		return
	if action_in_progress:
		return
	if index < 0 or index >= player_units.size():
		return

	var unit = player_units[index]
	if int(unit["health"]) <= 0:
		return

	battle_paused = true
	pause_button.text = "Resume"
	_update_pause_dim()
	_update_battle_ui_visibility()

	manual_selected_player_index = index
	selected_action = ""
	drag_assigning = false
	drag_start_player_index = -1
	drag_hover_enemy_index = -1

	attack_button.disabled = false
	defend_button.disabled = false

	var instinct_id := str(unit.get("instinct_id", ""))
	var cooldown := _get_instinct_cooldown_remaining(unit)

	instinct_button.text = _get_instinct_button_display_text(unit)
	instinct_button.disabled = instinct_id == "" or cooldown > 0

	turn_info_label.text = "Choose action for %s" % unit["name"]
	combat_log.append_text("%s selected.\n" % unit["name"])

	_refresh_cards_light()
	_update_target_lines()
func _begin_drag_assignment(index: int) -> void:
	if index < 0 or index >= player_units.size():
		return

	var unit = player_units[index]
	if int(unit["health"]) <= 0:
		return

	if manual_selected_player_index != index:
		_select_player_card(index)

	selected_action = "queue_attack"
	drag_assigning = true
	drag_start_player_index = index
	drag_hover_enemy_index = -1
	drag_mouse_local = get_local_mouse_position()

	turn_info_label.text = "Drag to an enemy for %s" % unit["name"]
	_update_target_lines()
func _set_battle_paused_state(paused: bool) -> void:
	battle_paused = paused

	if pause_button != null:
		pause_button.text = "Resume" if battle_paused else "Pause"

	_update_pause_dim()
	_update_battle_ui_visibility()
	
func _unit_has_modifier(unit: Dictionary, modifier_id: String) -> bool:
	var mods: Array = unit.get("modifiers", [])
	return mods.has(modifier_id)


func _add_modifier_to_unit(unit: Dictionary, modifier_id: String) -> void:
	var mods: Array = unit.get("modifiers", []).duplicate()
	if not mods.has(modifier_id):
		mods.append(modifier_id)
	unit["modifiers"] = mods


func _remove_modifier_from_unit(unit: Dictionary, modifier_id: String) -> void:
	var mods: Array = unit.get("modifiers", []).duplicate()
	mods.erase(modifier_id)
	unit["modifiers"] = mods
func _resolve_pre_action_statuses(side: String, index: int) -> bool:
	var units = player_units if side == "player" else enemy_units

	if index < 0 or index >= units.size():
		return true

	var unit = units[index]
	if int(unit["health"]) <= 0:
		return true

	var skipped := false

	if _unit_has_modifier(unit, "burning"):
		var burn_damage := 1
		unit["health"] = max(0, int(unit["health"]) - burn_damage)

		combat_log.append_text("%s takes %d burn damage (%d HP left)\n" % [
			unit["name"], burn_damage, unit["health"]
		])

		_show_floating_burn_damage(side, index, burn_damage)
		_update_card_from_unit(side, index)
		_update_atb_bars()
		_update_target_lines()

		if int(unit["health"]) <= 0:
			await _handle_unit_death(side, index)
			return true

		await get_tree().create_timer(0.18).timeout

	if _unit_has_modifier(unit, "frozen"):
		combat_log.append_text("%s is frozen and loses the turn!\n" % unit["name"])
		_show_floating_skip(side, index, "FROZEN")

		_remove_modifier_from_unit(unit, "frozen")
		_update_card_from_unit(side, index)
		_update_atb_bars()
		_update_target_lines()

		await get_tree().create_timer(0.25).timeout
		skipped = true
	
	if _unit_has_modifier(unit, "poisoned"):
		var poison_damage := 1
		unit["health"] = max(0, int(unit["health"]) - poison_damage)

		combat_log.append_text("%s takes %d poison damage (%d HP left)\n" % [
			unit["name"], poison_damage, unit["health"]
		])

		_show_floating_poison_damage(side, index, poison_damage)
		_update_card_from_unit(side, index)
		_update_atb_bars()
		_update_target_lines()

		if int(unit["health"]) <= 0:
			await _handle_unit_death(side, index)
			return true

		await get_tree().create_timer(0.18).timeout

	return skipped
	
func _perform_player_targeted_instinct_from_index(attacker_index: int, target_index: int, instinct_id: String) -> void:
	if attacker_index < 0 or attacker_index >= player_units.size():
		action_in_progress = false
		return
	if target_index < 0 or target_index >= enemy_units.size():
		action_in_progress = false
		return

	if int(player_units[attacker_index]["health"]) <= 0 or int(enemy_units[target_index]["health"]) <= 0:
		_finish_unit_action("player", attacker_index)
		return

	player_units[attacker_index]["used_instinct_this_action"] = true
	player_units[attacker_index]["queued_action"] = ""

	var attacker = player_units[attacker_index]
	var defender = enemy_units[target_index]

	match instinct_id:
		"ignite", "burn":
			var damage := 2
			if _unit_has_modifier(defender, "greased"):
				damage += 3

			combat_log.append_text("%s uses %s on %s\n" % [
				attacker["name"],
				instinct_id.capitalize(),
				defender["name"]
			])

			await _animate_attack("player", attacker_index, "enemy", target_index)

			defender["health"] = max(0, int(defender["health"]) - damage)
			_add_modifier_to_unit(defender, "burning")

			_show_floating_burn_damage("enemy", target_index, damage)
			await _animate_hit("enemy", target_index)

			combat_log.append_text("%s takes %d fire damage (%d HP left)\n" % [
				defender["name"], damage, defender["health"]
			])

		"oil":
			combat_log.append_text("%s uses Oil on %s\n" % [attacker["name"], defender["name"]])

			await _animate_attack("player", attacker_index, "enemy", target_index)

			_add_modifier_to_unit(defender, "greased")

			combat_log.append_text("%s is greased!\n" % defender["name"])

		"freeze":
			combat_log.append_text("%s uses Freeze on %s\n" % [attacker["name"], defender["name"]])

			await _animate_attack("player", attacker_index, "enemy", target_index)

			_add_modifier_to_unit(defender, "frozen")

			combat_log.append_text("%s is frozen!\n" % defender["name"])
			_show_floating_skip("enemy", target_index, "FROZEN")

		"poison":
			combat_log.append_text("%s uses Poison on %s\n" % [attacker["name"], defender["name"]])

			await _animate_attack("player", attacker_index, "enemy", target_index)

			_add_modifier_to_unit(defender, "poisoned")

			combat_log.append_text("%s is poisoned!\n" % defender["name"])
			_show_floating_poison_damage("enemy", target_index, 0)

	_update_card_from_unit("player", attacker_index)
	_update_card_from_unit("enemy", target_index)
	_update_atb_bars()
	_update_target_lines()
	_clear_target_buttons()

	if int(defender["health"]) <= 0:
		await _handle_unit_death("enemy", target_index)

	if _all_dead(enemy_units):
		_end_battle(true)
		return

	await get_tree().create_timer(0.2).timeout
	_finish_unit_action("player", attacker_index)
func _refresh_selected_unit_buttons() -> void:
	if manual_selected_player_index < 0 or manual_selected_player_index >= player_units.size():
		attack_button.disabled = true
		defend_button.disabled = true
		instinct_button.disabled = true
		instinct_button.text = "Instinct"
		return

	var unit = player_units[manual_selected_player_index]
	var instinct_id := str(unit.get("instinct_id", ""))
	var cooldown := _get_instinct_cooldown_remaining(unit)

	attack_button.disabled = false
	defend_button.disabled = false
	instinct_button.text = _get_instinct_button_display_text(unit)
	instinct_button.disabled = instinct_id == "" or cooldown > 0
