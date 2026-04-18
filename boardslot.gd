extends PanelContainer

@onready var center_container: CenterContainer = $CenterContainer

signal card_dropped(source_type: String, source_index: int, slot_index: int)
signal instinct_dropped(source_index: int, slot_index: int)

@export var slot_index: int = -1

func _can_drop_data(_at_position: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false

	if not data.has("source_type"):
		return false

	var source_type: String = String(data.get("source_type", ""))
	var card_type: String = String(data.get("card_type", "monster"))

	var valid := false

	# Monster cards from hand/board
	if card_type == "monster":
		valid = (source_type == "hand" or source_type == "board")

	# Instinct cards only from hand
	elif card_type == "instinct":
		valid = (source_type == "hand")

	if valid:
		modulate = Color(1, 1, 1, 0.9)

	return valid

func _drop_data(_at_position: Vector2, data) -> void:
	modulate = Color(1, 1, 1, 1)

	if not data.has("source_index"):
		return

	if not data.has("source_type"):
		return

	var source_type: String = String(data.get("source_type", ""))
	var source_index: int = int(data.get("source_index", -1))
	var card_type: String = String(data.get("card_type", "monster"))

	if card_type == "instinct":
		instinct_dropped.emit(source_index, slot_index)
		return

	card_dropped.emit(source_type, source_index, slot_index)

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		modulate = Color(1, 1, 1, 1)
