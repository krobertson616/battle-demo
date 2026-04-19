extends PanelContainer
signal card_sold(card_type: String, source_type: String, source_index: int)

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1000
	move_to_front()
	_set_children_mouse_ignore(self)
	print("SELL STRIP READY:", self)

func _set_children_mouse_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_ignore(child)

func enable_drop_zone() -> void:
	print("SELL STRIP ENABLE")
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1000
	move_to_front()

func disable_drop_zone() -> void:
	print("SELL STRIP DISABLE")
	visible = false

func _can_drop_data(_pos, data) -> bool:
	print("SELL STRIP CAN DROP?", data)

	if typeof(data) != TYPE_DICTIONARY:
		return false

	var card_type: String = String(data.get("card_type", ""))
	var source_type: String = String(data.get("source_type", ""))

	if card_type == "monster":
		return source_type == "hand" or source_type == "board"

	if card_type == "instinct":
		return source_type == "hand"

	return false

func _drop_data(_pos, data) -> void:
	print("SELL STRIP DROP:", data)

	if typeof(data) != TYPE_DICTIONARY:
		return

	var card_type: String = String(data.get("card_type", ""))
	var source_type: String = String(data.get("source_type", ""))
	var source_index: int = int(data.get("source_index", -1))

	card_sold.emit(card_type, source_type, source_index)
