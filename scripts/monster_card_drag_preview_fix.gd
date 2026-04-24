extends "res://monster_card.gd"

var _preview_card_scene: PackedScene = preload("res://scenes/monster_card.tscn")

func _get_drag_data(_at_position: Vector2):
	if source_type != "hand" and source_type != "board":
		return null

	if is_instance_valid(GameState.sell_strip_ref):
		GameState.sell_strip_ref.enable_drop_zone()

	var preview_root := Control.new()
	preview_root.custom_minimum_size = Vector2(1, 1)
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview_card = _preview_card_scene.instantiate()
	preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_card.modulate = Color(1, 1, 1, 0.92)
	preview_card.self_modulate = Color(1, 1, 1, 1)
	preview_card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	preview_card.position = Vector2(-CARD_WIDTH / 2.0, -CARD_HEIGHT * 0.42)

	preview_root.add_child(preview_card)

	if preview_card.has_method("setup"):
		preview_card.setup(_monster_data, "", -1)
	if preview_card.has_method("set_combat_mode"):
		preview_card.set_combat_mode(_combat_mode)
	if preview_card.has_method("_apply_data"):
		preview_card.call("_apply_data")

	set_drag_preview(preview_root)

	return {
		"card_type": "monster",
		"source_type": source_type,
		"source_index": source_index,
		"monster": _monster_data
	}
