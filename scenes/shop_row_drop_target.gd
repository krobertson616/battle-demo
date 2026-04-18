extends HBoxContainer

signal card_sold(source_type: String, source_index: int)

func _can_drop_data(_at_position: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false

	if not data.has("source_type"):
		return false

	return data["source_type"] == "hand" or data["source_type"] == "board"

func _drop_data(_at_position: Vector2, data) -> void:
	if not data.has("source_type"):
		return

	if not data.has("source_index"):
		return

	card_sold.emit(data["source_type"], data["source_index"])
