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


func _ready() -> void:
	#print("ARENA selected_location =", GameState.selected_location)
	#print("ARENA active_node_type =", GameState.active_node_type)
	_set_background()
	reward_overlay.visible = false
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

	_render_teams()
	call_deferred("_run_combat")

func _render_teams() -> void:
	for c in enemy_row.get_children():
		c.queue_free()

	for c in player_row.get_children():
		c.queue_free()

	for monster in visual_enemy_team:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)

		var card = monster_card_scene.instantiate()
		card.setup(monster)
		card.disabled = true
		card.position = Vector2.ZERO

		holder.add_child(card)
		enemy_row.add_child(holder)

	for monster in visual_player_team:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)

		var card = monster_card_scene.instantiate()
		card.setup(monster)
		card.disabled = true
		card.position = Vector2.ZERO

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
