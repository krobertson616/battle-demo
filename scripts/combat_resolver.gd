class_name CombatResolver
extends RefCounted

const GREASED_MISS_CHANCE := 0.25
static func _roll_greased_miss(attacker: Dictionary) -> bool:
	return _has_modifier(attacker, "greased") and randf() < GREASED_MISS_CHANCE
static func _get_next_living_index(units: Array, start_index: int) -> int:
	if units.is_empty():
		return -1

	var size: int = units.size()

	for offset in range(size):
		var idx: int = (start_index + offset) % size
		if int(units[idx]["health"]) > 0:
			return idx

	return -1


static func _has_other_living_tribe_ally(units: Array, self_index: int, tribe_name: String) -> bool:
	for i in range(units.size()):
		if i == self_index:
			continue
		if int(units[i]["health"]) > 0 and String(units[i]["tribe"]) == tribe_name:
			return true
	return false


static func _get_all_modifiers(unit: Dictionary) -> Array:
	var result: Array = []

	if unit.has("modifiers"):
		for mod in unit["modifiers"]:
			result.append(String(mod))

	if unit.has("equipped_modifiers"):
		for mod in unit["equipped_modifiers"]:
			result.append(String(mod))

	return result


static func _has_modifier(unit: Dictionary, modifier_id: String) -> bool:
	var all_mods: Array = _get_all_modifiers(unit)

	for mod in all_mods:
		if mod == modifier_id:
			return true

	return false


static func _get_living_indices_with_modifier(units: Array, modifier_id: String) -> Array:
	var valid: Array = []

	for i in range(units.size()):
		if int(units[i]["health"]) > 0 and _has_modifier(units[i], modifier_id):
			valid.append(i)

	return valid


static func _get_random_living_index(units: Array) -> int:
	var living_indices: Array = []

	for i in range(units.size()):
		if int(units[i]["health"]) > 0:
			living_indices.append(i)

	if living_indices.is_empty():
		return -1

	return living_indices[randi() % living_indices.size()]


static func _get_highest_health_living_index(units: Array) -> int:
	var best_index := -1
	var best_hp := -1

	for i in range(units.size()):
		var hp := int(units[i]["health"])
		if hp <= 0:
			continue

		if best_index == -1 or hp > best_hp:
			best_index = i
			best_hp = hp

	return best_index


static func _get_lowest_health_living_index(units: Array) -> int:
	var best_index := -1
	var best_hp := 999999

	for i in range(units.size()):
		var hp := int(units[i]["health"])
		if hp <= 0:
			continue

		if best_index == -1 or hp < best_hp:
			best_index = i
			best_hp = hp

	return best_index


static func _get_first_living_index(units: Array) -> int:
	for i in range(units.size()):
		if int(units[i]["health"]) > 0:
			return i
	return -1


static func _get_last_living_index(units: Array) -> int:
	for i in range(units.size() - 1, -1, -1):
		if int(units[i]["health"]) > 0:
			return i
	return -1


static func _get_target_index(attacker: Dictionary, units: Array) -> int:
	# 1. Taunt overrides all instincts
	var taunt_indices: Array = _get_living_indices_with_modifier(units, "taunt")
	if not taunt_indices.is_empty():
		var taunt_pick: int = taunt_indices[randi() % taunt_indices.size()]
		# print("[TARGET] ", attacker.get("name", "Unknown"), " forced to hit taunt target at index ", taunt_pick)
		return taunt_pick

	# 2. Check attacker's instincts
	if attacker.has("instincts"):
		# print("[TARGET] Attacker: ", attacker.get("name", "Unknown"))
		# print("[TARGET] Instincts: ", attacker.get("instincts", []))

		for instinct in attacker["instincts"]:
			if typeof(instinct) == TYPE_DICTIONARY:
				var instinct_dict: Dictionary = instinct
				var instinct_type: String = String(instinct_dict.get("type", ""))
				var rule: String = String(instinct_dict.get("rule", ""))

				if instinct_type == "targeting":
					var chosen_index := -1

					match rule:
						"highest_health":
							chosen_index = _get_highest_health_living_index(units)
						"lowest_health":
							chosen_index = _get_lowest_health_living_index(units)
						"front":
							chosen_index = _get_first_living_index(units)
						"back":
							chosen_index = _get_last_living_index(units)
						"random":
							chosen_index = _get_random_living_index(units)

					if chosen_index != -1:
						# print("[TARGET] ", attacker.get("name", "Unknown"), " used instinct rule: ", rule, " -> target index ", chosen_index)
						return chosen_index

			elif typeof(instinct) == TYPE_STRING:
				var instinct_str: String = String(instinct)
				var chosen_index := -1

				match instinct_str:
					"target_highest_health":
						chosen_index = _get_highest_health_living_index(units)
					"target_lowest_health":
						chosen_index = _get_lowest_health_living_index(units)
					"target_front":
						chosen_index = _get_first_living_index(units)
					"target_back":
						chosen_index = _get_last_living_index(units)

				if chosen_index != -1:
					# print("[TARGET] ", attacker.get("name", "Unknown"), " used legacy instinct: ", instinct_str, " -> target index ", chosen_index)
					return chosen_index

	# 3. Fallback
	var random_index := _get_random_living_index(units)
	# print("[TARGET] ", attacker.get("name", "Unknown"), " used fallback random target index ", random_index)
	return random_index


static func resolve_combat(player_team: Array, enemy_team: Array) -> Dictionary:
	var log_lines: Array[String] = []
	var p_units: Array = []
	var e_units: Array = []
	var events: Array = []

	for i in range(player_team.size()):
		var m = player_team[i]
		p_units.append({
			"name": m.display_name,
			"attack": m.attack,
			"health": m.health,
			"max_health": m.max_health,
			"tribe": m.tribe,
			"slot_index": i,
			"id": m.id,
			"modifiers": m.modifiers.duplicate(),
			"equipped_modifiers": m.equipped_modifiers.duplicate(),
			"instincts": m.instincts.duplicate()
		})

	for i in range(enemy_team.size()):
		var m = enemy_team[i]
		e_units.append({
			"name": m.display_name,
			"attack": m.attack,
			"health": m.health,
			"max_health": m.max_health,
			"tribe": m.tribe,
			"id": m.id,
			"modifiers": m.modifiers.duplicate(),
			"equipped_modifiers": m.equipped_modifiers.duplicate(),
			"instincts": m.instincts.duplicate()
		})

	var p_turn_index: int = 0
	var e_turn_index: int = 0
	var player_turn: bool = (randi() % 2 == 0)

	while not p_units.is_empty() and not e_units.is_empty():
		if player_turn:
			var p_attacker_index: int = _get_next_living_index(p_units, p_turn_index)
			if p_attacker_index == -1:
				break

			var p: Dictionary = p_units[p_attacker_index]
			var p_target_index: int = _get_target_index(p, e_units)

			if p_target_index == -1:
				break

			if _has_modifier(p, "regenerate"):
				var old_hp: int = int(p["health"])
				p["health"] = min(int(p["max_health"]), int(p["health"]) + 1)
				if int(p["health"]) > old_hp:
					log_lines.append("%s regenerates 1 health" % p["name"])

			var p_target: Dictionary = e_units[p_target_index]
			log_lines.append("%s attacks %s" % [p["name"], p_target["name"]])
			events.append({
				"type": "attack",
				"attacker_side": "player",
				"attacker_name": p["name"],
				"attacker_index": p_attacker_index,
				"target_side": "enemy",
				"target_name": p_target["name"],
				"target_index": p_target_index
			})

			if _roll_greased_miss(p):
				log_lines.append("%s slips and misses!" % p["name"])
				events.append({
					"type": "miss",
					"target_side": "enemy",
					"target_name": p_target["name"],
					"target_index": p_target_index
				})

				if not p_units.is_empty():
					var next_p_index: int = p_attacker_index + 1
					if next_p_index >= p_units.size():
						next_p_index = 0
					p_turn_index = next_p_index

				player_turn = false
				continue
			var damage_to_enemy: int = int(p["attack"])
			var burn_hit_enemy := false
			

			if _has_modifier(p, "burn"):
				damage_to_enemy += 1
				burn_hit_enemy = true

			if _has_modifier(p, "pack_hunter") and _has_other_living_tribe_ally(p_units, p_attacker_index, "Fang"):
				damage_to_enemy += 1

			if burn_hit_enemy and _has_modifier(p_target, "greased"):
				damage_to_enemy += 1

				if p_target.has("modifiers"):
					p_target["modifiers"].erase("greased")

				events.append({
					"type": "status_removed",
					"target_side": "enemy",
					"target_name": p_target["name"],
					"target_index": p_target_index,
					"status": "greased"
				})
				log_lines.append("%s ignites %s for +1 bonus damage" % [p["name"], p_target["name"]])

			p_target["health"] = max(0, int(p_target["health"]) - damage_to_enemy)
			if _has_modifier(p, "oil") and not _has_modifier(p_target, "greased"):
				if not p_target.has("modifiers"):
					p_target["modifiers"] = []

				p_target["modifiers"].append("greased")
				log_lines.append("%s coats %s in oil" % [p["name"], p_target["name"]])

				events.append({
					"type": "status_applied",
					"target_side": "enemy",
					"target_name": p_target["name"],
					"target_index": p_target_index,
					"status": "greased"
				})
			log_lines.append("%s takes %d damage" % [p_target["name"], damage_to_enemy])

			events.append({
				"type": "damage",
				"target_side": "enemy",
				"target_name": p_target["name"],
				"target_index": p_target_index,
				"amount": damage_to_enemy,
				"remaining_hp": p_target["health"]
			})

			for i in range(e_units.size() - 1, -1, -1):
				if int(e_units[i]["health"]) <= 0:
					log_lines.append("%s dies" % e_units[i]["name"])
					events.append({
						"type": "death",
						"side": "enemy",
						"name": e_units[i]["name"],
						"target_index": i
					})
					e_units.remove_at(i)

			if not p_units.is_empty():
				var next_p_index: int = p_attacker_index + 1
				if next_p_index >= p_units.size():
					next_p_index = 0
				p_turn_index = next_p_index

			player_turn = false

		else:
			var e_attacker_index: int = _get_next_living_index(e_units, e_turn_index)
			if e_attacker_index == -1:
				break

			var e: Dictionary = e_units[e_attacker_index]
			var e_target_index: int = _get_target_index(e, p_units)

			if e_target_index == -1:
				break

			if _has_modifier(e, "regenerate"):
				var old_hp: int = int(e["health"])
				e["health"] = min(int(e["max_health"]), int(e["health"]) + 1)
				if int(e["health"]) > old_hp:
					log_lines.append("%s regenerates 1 health" % e["name"])

			var e_target: Dictionary = p_units[e_target_index]
			log_lines.append("%s attacks %s" % [e["name"], e_target["name"]])
			events.append({
				"type": "attack",
				"attacker_side": "enemy",
				"attacker_name": e["name"],
				"attacker_index": e_attacker_index,
				"target_side": "player",
				"target_name": e_target["name"],
				"target_index": e_target_index
			})

			if _roll_greased_miss(e):
				log_lines.append("%s slips and misses!" % e["name"])
				events.append({
					"type": "miss",
					"target_side": "player",
					"target_name": e_target["name"],
					"target_index": e_target_index
				})

				if not e_units.is_empty():
					var next_e_index: int = e_attacker_index + 1
					if next_e_index >= e_units.size():
						next_e_index = 0
					e_turn_index = next_e_index

				player_turn = true
				continue
			var damage_to_player: int = int(e["attack"])
			var burn_hit_player := false

			if _has_modifier(e, "pack_hunter") and _has_other_living_tribe_ally(e_units, e_attacker_index, "Fang"):
				damage_to_player += 1

			if _has_modifier(e, "burn"):
				damage_to_player += 1
				burn_hit_player = true

			if burn_hit_player and _has_modifier(e_target, "greased"):
				damage_to_player += 1

				if e_target.has("modifiers"):
					e_target["modifiers"].erase("greased")

				events.append({
					"type": "status_removed",
					"target_side": "player",
					"target_name": e_target["name"],
					"target_index": e_target_index,
					"status": "greased"
				})

				log_lines.append("%s ignites %s for +1 bonus damage" % [e["name"], e_target["name"]])

			e_target["health"] = max(0, int(e_target["health"]) - damage_to_player)
			if _has_modifier(e, "oil") and not _has_modifier(e_target, "greased"):
				if not e_target.has("modifiers"):
					e_target["modifiers"] = []

				e_target["modifiers"].append("greased")
				log_lines.append("%s coats %s in oil" % [e["name"], e_target["name"]])

				events.append({
					"type": "status_applied",
					"target_side": "player",
					"target_name": e_target["name"],
					"target_index": e_target_index,
					"status": "greased"
				})
			log_lines.append("%s takes %d damage" % [e_target["name"], damage_to_player])

			events.append({
				"type": "damage",
				"target_side": "player",
				"target_name": e_target["name"],
				"target_index": e_target_index,
				"amount": damage_to_player,
				"remaining_hp": e_target["health"]
			})

			for i in range(p_units.size() - 1, -1, -1):
				if int(p_units[i]["health"]) <= 0:
					log_lines.append("%s dies" % p_units[i]["name"])
					events.append({
						"type": "death",
						"side": "player",
						"name": p_units[i]["name"],
						"target_index": i
					})
					p_units.remove_at(i)

			if not e_units.is_empty():
				var next_e_index: int = e_attacker_index + 1
				if next_e_index >= e_units.size():
					next_e_index = 0
				e_turn_index = next_e_index

			player_turn = true

	return {
		"player_won": e_units.is_empty(),
		"log": log_lines,
		"events": events,
		"player_survivors": p_units
	}
