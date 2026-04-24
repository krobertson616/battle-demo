extends Node

# Keeps enemy cards from visually overlapping in arena_scene.
# Volatile Conductor uses a wider presentation, so his holder is wider and the
# card is centered inside that space. This keeps the gaps on both sides even.

const DEFAULT_ENEMY_SEPARATION := 34
const CONDUCTOR_ENEMY_SEPARATION := 34
const DEFAULT_HOLDER_WIDTH := 185
const CONDUCTOR_HOLDER_WIDTH := 245

@onready var arena: Control = get_parent() as Control
@onready var enemy_row: HBoxContainer = arena.get_node("MarginContainer/VBoxContainer/EnemyRow")

func _process(_delta: float) -> void:
	if arena == null or not is_instance_valid(arena):
		return
	if enemy_row == null or not is_instance_valid(enemy_row):
		return

	var has_conductor := _enemy_team_has_volatile_conductor()
	var separation := CONDUCTOR_ENEMY_SEPARATION if has_conductor else DEFAULT_ENEMY_SEPARATION
	enemy_row.add_theme_constant_override("separation", separation)

	for holder in enemy_row.get_children():
		if not (holder is Control):
			continue

		var control := holder as Control
		var card := _get_first_card_child(control)
		if card == null:
			control.custom_minimum_size.x = DEFAULT_HOLDER_WIDTH
			continue

		var holder_width := DEFAULT_HOLDER_WIDTH
		if _is_volatile_conductor_card(card):
			holder_width = CONDUCTOR_HOLDER_WIDTH

		control.custom_minimum_size.x = holder_width
		_center_card_in_holder(card, holder_width)

func _center_card_in_holder(card: Control, holder_width: float) -> void:
	var card_width := card.size.x
	if card_width <= 0.0:
		card_width = card.custom_minimum_size.x
	if card_width <= 0.0:
		card_width = DEFAULT_HOLDER_WIDTH

	card.position.x = max(0.0, (holder_width - card_width) / 2.0)

func _enemy_team_has_volatile_conductor() -> bool:
	var visual_enemy_team = arena.get("visual_enemy_team")
	if typeof(visual_enemy_team) != TYPE_ARRAY:
		return false

	for monster in visual_enemy_team:
		if _is_volatile_conductor_data(monster):
			return true

	return false

func _get_first_card_child(holder: Control) -> Control:
	for child in holder.get_children():
		if child is Control:
			return child as Control
	return null

func _is_volatile_conductor_card(card: Control) -> bool:
	var data = card.get("_monster_data")
	return _is_volatile_conductor_data(data)

func _is_volatile_conductor_data(data) -> bool:
	if data == null:
		return false

	if data is Dictionary:
		var id := str(data.get("id", ""))
		var display_name := str(data.get("display_name", data.get("name", ""))).to_lower()
		return id == "volatile_conductor" or display_name.contains("volatile conductor")

	var id_value = data.get("id")
	var name_value = data.get("display_name")
	var id := "" if id_value == null else str(id_value)
	var display_name := "" if name_value == null else str(name_value).to_lower()
	return id == "volatile_conductor" or display_name.contains("volatile conductor")
