extends Node

# Keeps enemy cards from visually overlapping in arena_scene.
# Volatile Conductor stays visually anchored in the middle while Greaselings
# appear to his left and Firelings appear to his right.

const DEFAULT_ENEMY_SEPARATION: int = 34
const DEFAULT_HOLDER_WIDTH: float = 185.0
const CONDUCTOR_SIDE_PADDING: float = 30.0

@onready var arena: Control = get_parent() as Control
@onready var enemy_row: HBoxContainer = arena.get_node("MarginContainer/VBoxContainer/EnemyRow")

func _process(_delta: float) -> void:
	if arena == null or not is_instance_valid(arena):
		return
	if enemy_row == null or not is_instance_valid(enemy_row):
		return

	enemy_row.add_theme_constant_override("separation", DEFAULT_ENEMY_SEPARATION)
	_apply_even_conductor_spacing()

func _apply_even_conductor_spacing() -> void:
	var conductor_holder: Control = null
	var conductor_card: Control = null
	var conductor_index: int = -1

	for i in range(enemy_row.get_child_count()):
		var holder: Control = enemy_row.get_child(i) as Control
		if holder == null:
			continue

		var card: Control = _get_first_card_child(holder)
		if card == null:
			holder.custom_minimum_size.x = DEFAULT_HOLDER_WIDTH
			continue

		if _is_volatile_conductor_card(card):
			conductor_holder = holder
			conductor_card = card
			conductor_index = i
		else:
			holder.custom_minimum_size.x = DEFAULT_HOLDER_WIDTH
			card.position.x = 0.0

	if conductor_holder == null or conductor_card == null or conductor_index == -1:
		return

	var left_count: int = conductor_index
	var right_count: int = enemy_row.get_child_count() - conductor_index - 1

	var slot_span: float = DEFAULT_HOLDER_WIDTH + float(DEFAULT_ENEMY_SEPARATION)
	var left_span: float = float(left_count) * slot_span
	var right_span: float = float(right_count) * slot_span
	var side_difference: float = absf(left_span - right_span)

	var conductor_card_width: float = _get_card_width(conductor_card)
	var conductor_holder_width: float = conductor_card_width + side_difference + (CONDUCTOR_SIDE_PADDING * 2.0)
	var card_x: float = (conductor_holder_width + right_span - left_span - conductor_card_width) / 2.0

	conductor_holder.custom_minimum_size.x = conductor_holder_width
	conductor_card.position.x = maxf(0.0, card_x)

func _get_card_width(card: Control) -> float:
	if card.size.x > 0.0:
		return card.size.x
	if card.custom_minimum_size.x > 0.0:
		return card.custom_minimum_size.x
	return DEFAULT_HOLDER_WIDTH

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
		var id: String = str(data.get("id", ""))
		var display_name: String = str(data.get("display_name", data.get("name", ""))).to_lower()
		return id == "volatile_conductor" or display_name.contains("volatile conductor")

	var id_value = data.get("id")
	var name_value = data.get("display_name")
	var id: String = "" if id_value == null else str(id_value)
	var display_name: String = "" if name_value == null else str(name_value).to_lower()
	return id == "volatile_conductor" or display_name.contains("volatile conductor")
