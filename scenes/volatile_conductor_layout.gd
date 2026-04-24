extends Node

# Keeps Volatile Conductor's summons visually grouped around him.
# Greaselings are sorted to his left. Firelings are sorted to his right.

@onready var arena: Control = get_parent() as Control

var _last_signature := ""
var _refresh_queued := false

func _process(_delta: float) -> void:
	if arena == null or not is_instance_valid(arena):
		return

	if bool(arena.get("battle_over")):
		return

	# Do not shift indexes in the middle of an animation/action.
	if bool(arena.get("action_in_progress")):
		return

	var enemy_units = arena.get("enemy_units")
	var visual_enemy_team = arena.get("visual_enemy_team")
	if typeof(enemy_units) != TYPE_ARRAY or typeof(visual_enemy_team) != TYPE_ARRAY:
		return

	var signature := _build_signature(enemy_units)
	if signature == _last_signature:
		return

	_last_signature = signature
	_sort_volatile_conductor_group(enemy_units, visual_enemy_team)

func _sort_volatile_conductor_group(enemy_units: Array, visual_enemy_team: Array) -> void:
	var has_conductor := false
	for unit in enemy_units:
		if _is_conductor(unit):
			has_conductor = true
			break

	if not has_conductor:
		return

	var old_enemy_units := enemy_units.duplicate()
	var old_visuals := visual_enemy_team.duplicate()
	var new_enemy_units := _build_sorted_units(old_enemy_units)

	if _same_order(old_enemy_units, new_enemy_units):
		return

	_remap_player_enemy_targets(old_enemy_units, new_enemy_units)

	enemy_units.clear()
	for unit in new_enemy_units:
		enemy_units.append(unit)

	visual_enemy_team.clear()
	for unit in new_enemy_units:
		var old_index := old_enemy_units.find(unit)
		if old_index >= 0 and old_index < old_visuals.size():
			visual_enemy_team.append(old_visuals[old_index])

	arena.set("enemy_units", enemy_units)
	arena.set("visual_enemy_team", visual_enemy_team)

	_queue_refresh()

func _build_sorted_units(units: Array) -> Array:
	var greaselings: Array = []
	var conductors: Array = []
	var firelings: Array = []
	var others_left: Array = []
	var others_right: Array = []
	var found_conductor := false

	for unit in units:
		if _is_conductor(unit):
			found_conductor = true
			conductors.append(unit)
		elif _is_greaseling(unit):
			greaselings.append(unit)
		elif _is_fireling(unit):
			firelings.append(unit)
		elif found_conductor:
			others_right.append(unit)
		else:
			others_left.append(unit)

	var sorted: Array = []
	sorted.append_array(others_left)
	sorted.append_array(greaselings)
	sorted.append_array(conductors)
	sorted.append_array(firelings)
	sorted.append_array(others_right)
	return sorted

func _remap_player_enemy_targets(old_order: Array, new_order: Array) -> void:
	var player_units = arena.get("player_units")
	if typeof(player_units) != TYPE_ARRAY:
		return

	for player_unit in player_units:
		if typeof(player_unit) != TYPE_DICTIONARY:
			continue
		if str(player_unit.get("queued_target_side", "enemy")) != "enemy":
			continue

		var old_index := int(player_unit.get("queued_target_index", -1))
		if old_index < 0 or old_index >= old_order.size():
			continue

		var target_unit = old_order[old_index]
		var new_index := new_order.find(target_unit)
		if new_index != -1:
			player_unit["queued_target_index"] = new_index

func _queue_refresh() -> void:
	if _refresh_queued:
		return

	_refresh_queued = true
	call_deferred("_refresh_arena_cards")

func _refresh_arena_cards() -> void:
	_refresh_queued = false
	if arena != null and is_instance_valid(arena) and arena.has_method("_render_teams"):
		arena.call("_render_teams")

func _same_order(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false

	for i in range(a.size()):
		if a[i] != b[i]:
			return false

	return true

func _build_signature(units: Array) -> String:
	var parts: Array[String] = []
	for unit in units:
		parts.append("%s:%s" % [_get_unit_id(unit), str(unit.get("health", 0))])
	return "|".join(parts)

func _is_conductor(unit) -> bool:
	var id := _get_unit_id(unit)
	var name := _get_unit_name(unit).to_lower()
	return id == "volatile_conductor" or name.contains("volatile conductor")

func _is_greaseling(unit) -> bool:
	var id := _get_unit_id(unit)
	var name := _get_unit_name(unit).to_lower()
	return id == "greaseling" or name.contains("greaseling")

func _is_fireling(unit) -> bool:
	var id := _get_unit_id(unit)
	var name := _get_unit_name(unit).to_lower()
	return id == "fireling" or name.contains("fireling")

func _get_unit_id(unit) -> String:
	if typeof(unit) != TYPE_DICTIONARY:
		return ""

	if unit.has("id"):
		return str(unit.get("id", ""))

	var source = unit.get("source_monster", null)
	if source == null:
		return ""

	if source is Dictionary:
		return str(source.get("id", ""))

	var id_value = source.get("id")
	if id_value == null:
		return ""

	return str(id_value)

func _get_unit_name(unit) -> String:
	if typeof(unit) != TYPE_DICTIONARY:
		return ""

	if unit.has("name"):
		return str(unit.get("name", ""))

	if unit.has("display_name"):
		return str(unit.get("display_name", ""))

	var source = unit.get("source_monster", null)
	if source == null:
		return ""

	if source is Dictionary:
		return str(source.get("display_name", source.get("name", "")))

	var name_value = source.get("display_name")
	if name_value == null:
		return ""

	return str(name_value)
