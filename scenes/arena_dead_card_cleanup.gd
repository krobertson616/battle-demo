extends Node

# Removes dead combatants from the arena rows so killed monsters disappear
# instead of remaining on the board as faded cards.

@onready var arena: Control = get_parent() as Control

var _refresh_queued := false

func _process(_delta: float) -> void:
	if arena == null or not is_instance_valid(arena):
		return

	if bool(arena.get("battle_over")):
		return

	# Let the current attack/hit/death animation finish before changing indexes.
	if bool(arena.get("action_in_progress")):
		return

	var removed_enemy_indexes := _remove_dead_from_side("enemy_units", "visual_enemy_team")
	var removed_player_indexes := _remove_dead_from_side("player_units", "visual_player_team")

	if removed_enemy_indexes.is_empty() and removed_player_indexes.is_empty():
		return

	_remap_enemy_target_indexes_after_removal(removed_enemy_indexes)
	_clamp_turn_cursors()
	_queue_refresh()

func _remove_dead_from_side(units_property: String, visuals_property: String) -> Array[int]:
	var units = arena.get(units_property)
	var visuals = arena.get(visuals_property)

	if typeof(units) != TYPE_ARRAY or typeof(visuals) != TYPE_ARRAY:
		return []

	var removed_indexes: Array[int] = []
	var max_count: int = max(units.size(), visuals.size())

	for i in range(max_count - 1, -1, -1):
		var unit = units[i] if i < units.size() else null
		var visual = visuals[i] if i < visuals.size() else null

		if not _is_dead(unit, visual):
			continue

		if i < units.size():
			units.remove_at(i)
		if i < visuals.size():
			visuals.remove_at(i)

		removed_indexes.append(i)

	arena.set(units_property, units)
	arena.set(visuals_property, visuals)
	removed_indexes.sort()
	return removed_indexes

func _is_dead(unit, visual) -> bool:
	if typeof(unit) == TYPE_DICTIONARY:
		if int(unit.get("health", 1)) <= 0:
			return true

	if visual != null:
		var visual_health = visual.get("health")
		if visual_health != null and int(visual_health) <= 0:
			return true

	return false

func _remap_enemy_target_indexes_after_removal(removed_enemy_indexes: Array[int]) -> void:
	if removed_enemy_indexes.is_empty():
		return

	var player_units = arena.get("player_units")
	var enemy_units = arena.get("enemy_units")

	if typeof(player_units) != TYPE_ARRAY or typeof(enemy_units) != TYPE_ARRAY:
		return

	for player_unit in player_units:
		if typeof(player_unit) != TYPE_DICTIONARY:
			continue
		if str(player_unit.get("queued_target_side", "enemy")) != "enemy":
			continue

		var old_target_index := int(player_unit.get("queued_target_index", -1))
		if old_target_index < 0:
			continue

		if removed_enemy_indexes.has(old_target_index):
			player_unit["queued_target_index"] = -1
			continue

		var shift := 0
		for removed_index in removed_enemy_indexes:
			if removed_index < old_target_index:
				shift += 1

		var new_target_index := old_target_index - shift
		if new_target_index >= enemy_units.size():
			new_target_index = enemy_units.size() - 1

		player_unit["queued_target_index"] = max(-1, new_target_index)

	arena.set("player_units", player_units)

func _clamp_turn_cursors() -> void:
	var player_units = arena.get("player_units")
	var enemy_units = arena.get("enemy_units")

	if typeof(player_units) == TYPE_ARRAY:
		arena.set("player_turn_cursor", clamp(int(arena.get("player_turn_cursor")), 0, max(0, player_units.size() - 1)))
		arena.set("current_player_index", clamp(int(arena.get("current_player_index")), -1, max(-1, player_units.size() - 1)))
		arena.set("manual_selected_player_index", clamp(int(arena.get("manual_selected_player_index")), -1, max(-1, player_units.size() - 1)))

	if typeof(enemy_units) == TYPE_ARRAY:
		arena.set("enemy_turn_cursor", clamp(int(arena.get("enemy_turn_cursor")), 0, max(0, enemy_units.size() - 1)))
		arena.set("current_enemy_index", clamp(int(arena.get("current_enemy_index")), -1, max(-1, enemy_units.size() - 1)))
		arena.set("drag_hover_enemy_index", clamp(int(arena.get("drag_hover_enemy_index")), -1, max(-1, enemy_units.size() - 1)))

func _queue_refresh() -> void:
	if _refresh_queued:
		return

	_refresh_queued = true
	call_deferred("_refresh_arena_cards")

func _refresh_arena_cards() -> void:
	_refresh_queued = false

	if arena == null or not is_instance_valid(arena):
		return

	if arena.has_method("_render_teams"):
		arena.call("_render_teams")
	if arena.has_method("_refresh_cards_light"):
		arena.call("_refresh_cards_light")
