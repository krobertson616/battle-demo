extends PanelContainer

signal card_sold(source_type: String, source_index: int, monster: MonsterData)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 310
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(1, 0, 0, 0.0)


func enable_drop_zone() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color(1, 0, 0, 0.12)

func disable_drop_zone() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(1, 0, 0, 0.0)

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

	card_sold.emit(
	data["source_type"],
	data["source_index"],
	data.get("monster", null)
)
