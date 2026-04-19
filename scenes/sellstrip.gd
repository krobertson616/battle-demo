extends PanelContainer
signal card_sold(card_type: String, source_type: String, source_index: int)

func enable_drop_zone() -> void:
	visible = true

func disable_drop_zone() -> void:
	visible = false

func _can_drop_data(_pos, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false

	var card_type: String = String(data.get("card_type", ""))
	var source_type: String = String(data.get("source_type", ""))

	if source_type != "hand" and source_type != "board":
		return false

	if card_type == "monster":
		return source_type == "hand" or source_type == "board"

	if card_type == "instinct":
		return source_type == "hand"

	return false

func _drop_data(_pos, data) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return

	var card_type: String = String(data.get("card_type", ""))
	var source_type: String = String(data.get("source_type", ""))
	var source_index: int = int(data.get("source_index", -1))

	card_sold.emit(card_type, source_type, source_index)
