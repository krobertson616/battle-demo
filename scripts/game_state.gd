extends Node

var pending_player_team: Array = []
var pending_enemy_team: Array = []
var pending_result: Dictionary = {}

var gold: int = 3
var health: int = 10
var round_num: int = 1
var board_monsters: Array = []
var hand_monsters: Array = []
var shop_monsters: Array = []
var hand_instincts: Array = []
var hand_cards: Array = []
var run_started: bool = false
var sell_strip_ref = null
var shop_items: Array = []

var map_nodes: Array = []
var current_node_id: int = -1
var selected_next_node_id: int = -1
var active_node_type: String = ""
var auto_start_combat_from_map: bool = false
var run_nodes = []
var current_node_index: int = 0
var run_encounters: Array = []
var current_encounter_index: int = 0

var all_monsters: Array[MonsterData] = []
var shop_pool: Array[MonsterData] = []
var enemy_pool: Array[MonsterData] = []
var selected_location: String = ""
var selected_location_label: String = ""
var max_board_slots: int = 3

func _ready() -> void:
	randomize()
	_build_monster_pools()

func _build_monster_pools() -> void:
	all_monsters.clear()
	shop_pool.clear()
	enemy_pool.clear()

	all_monsters = [
		_make("wolf", "Sheni", "Fang", 1, 2, 2, "alpha_wolf"),
		_make("imp", "Imp", "Ember", 1, 50, 50, "fireling"),
		_make("slime", "Slime", "Slime", 1, 1, 3, "superslime"),
		_make("superslime", "Super Slime", "Slime", 1, 1, 3, "none"),
		_make("alpha_wolf", "Shen-Zi", "Fang", 3, 3, 3, "none"),
		_make("fireling", "Fireling", "Ember", 2, 2, 2, "none"),
		_make("golem", "Pebble Golem", "Stone", 1, 1, 4, "stone_guardian"),
		_make("stone_guardian", "Stone Guardian", "Stone", 3, 2, 7, "none"),
	]

	shop_pool = [
		get_monster_by_id("wolf"),
		get_monster_by_id("imp"),
		get_monster_by_id("slime"),
		get_monster_by_id("golem")
	]

	enemy_pool = [
		get_monster_by_id("wolf"),
		get_monster_by_id("imp"),
		get_monster_by_id("slime"),
		get_monster_by_id("golem")
	]

func _make(id: String, display_name: String, tribe: String, cost: int, atk: int, hp: int, evolves_to_id: String) -> MonsterData:
	var m := MonsterData.new()
	m.id = id
	m.display_name = display_name
	m.tribe = tribe
	m.cost = cost
	m.attack = atk
	m.health = hp
	m.max_health = hp
	m.evolves_to_id = evolves_to_id

	m.modifiers = []
	m.instincts = []
	m.equipped_modifiers = []
	m.modifier_slots = 0

	if id == "golem":
		m.modifiers.append("taunt")
	

	if id == "stone_guardian":
		m.modifiers.append("taunt")
	

	if id == "wolf":
		m.modifiers.append("pack_hunter")

	if id == "imp":
		m.modifiers.append("burn")

	if id == "slime":
		m.modifiers.append("oil")

	if id == "alpha_wolf":
		m.modifiers.append("pack_hunter")

	if id == "fireling":
		m.modifiers.append("burn")

	if id == "superslime":
		m.modifiers.append("oil")

	if id == "wolf":
		m.set_meta("texture", load("res://assets/shen.png"))
	if id == "imp":
		m.set_meta("texture", load("res://assets/imp.png"))
	if id == "fireling":
		m.set_meta("texture", load("res://assets/impking.png"))
	if id == "alpha_wolf":
		m.set_meta("texture", load("res://assets/alphashen.png"))
	if id == "slime":
		m.set_meta("texture", load("res://assets/slime.png"))
	if id == "golem":
		m.set_meta("texture", load("res://assets/golem.png"))
	if id == "stone_guardian":
		m.set_meta("texture", load("res://assets/stoneguardian.png"))
	if id == "superslime":
		m.set_meta("texture", load("res://assets/slimeking.png"))

	return m
func build_first_test_run() -> void:
	run_encounters = [
		"cave_1",
		"cave_2",
		"forest_1",
		"elite_1",
		"crypt_1",
		"boss_1",
	]
	current_encounter_index = 0
func get_current_encounter_id() -> String:
	if current_encounter_index < 0 or current_encounter_index >= run_encounters.size():
		return ""
	return String(run_encounters[current_encounter_index])
func get_monster_by_id(monster_id: String) -> MonsterData:
	for m in all_monsters:
		if m.id == monster_id:
			return m
	return null

func clone_monster(template: MonsterData) -> MonsterData:
	var m := MonsterData.new()
	m.id = template.id
	m.display_name = template.display_name
	m.tribe = template.tribe
	m.cost = template.cost
	m.attack = template.attack
	m.health = template.health
	m.max_health = template.max_health
	m.evolves_to_id = template.evolves_to_id
	m.modifiers = template.modifiers.duplicate()
	m.instincts = template.instincts.duplicate()
	m.modifier_slots = template.modifier_slots
	m.equipped_modifiers = template.equipped_modifiers.duplicate()

	if template.has_meta("texture"):
		m.set_meta("texture", template.get_meta("texture"))

	return m

func can_add_modifier(monster: MonsterData, modifier_id: String) -> bool:
	if monster.modifier_slots <= 0:
		return false

	if monster.equipped_modifiers.size() >= monster.modifier_slots:
		return false

	if modifier_id in monster.equipped_modifiers:
		return false

	return true

func add_equipped_modifier(monster: MonsterData, modifier_id: String) -> bool:
	if not can_add_modifier(monster, modifier_id):
		return false

	monster.equipped_modifiers.append(modifier_id)
	return true

func build_test_map() -> Array:
	return [
		{"id": 0, "type": "start",   "row": 0, "col": 0, "next": [1, 2], "completed": true},
		{"id": 1, "type": "combat",  "row": 1, "col": 0, "next": [3],    "completed": false},
		{"id": 2, "type": "combat",  "row": 1, "col": 1, "next": [4],    "completed": false},
		{"id": 3, "type": "shop",    "row": 2, "col": 0, "next": [5],    "completed": false},
		{"id": 4, "type": "combat",  "row": 2, "col": 1, "next": [5],    "completed": false},
		{"id": 5, "type": "elite",   "row": 3, "col": 0, "next": [6],    "completed": false},
		{"id": 6, "type": "boss",    "row": 4, "col": 0, "next": [],     "completed": false}
	]

func get_map_node(node_id: int) -> Dictionary:
	for node in map_nodes:
		if int(node["id"]) == node_id:
			return node
	return {}

func can_travel_to_node(node_id: int) -> bool:
	var current = get_map_node(current_node_id)
	if current.is_empty():
		return false
	return node_id in current["next"]

func travel_to_node(node_id: int) -> bool:
	if not can_travel_to_node(node_id):
		return false

	current_node_id = node_id

	for i in range(map_nodes.size()):
		if int(map_nodes[i]["id"]) == node_id:
			map_nodes[i]["completed"] = true
			active_node_type = String(map_nodes[i]["type"])
			break

	return true

func build_player_team_from_board() -> Array:
	var team: Array = []

	for i in range(board_monsters.size()):
		var monster = board_monsters[i]
		if monster != null:
			team.append(monster)

	return team

func clear_pending_combat() -> void:
	pending_player_team = []
	pending_enemy_team = []
	pending_result = {}

func build_enemy_team_for_current_node() -> Array:
	var team: Array = []
	var team_size := _get_enemy_team_size()

	for i in range(team_size):
		var template: MonsterData = _pick_enemy_for_location()
		var enemy: MonsterData = clone_monster(template)
		enemy.id = "enemy_%s_%d" % [enemy.id, i]

		if active_node_type == "elite":
			enemy.attack += 1
			enemy.health += 2
			enemy.max_health = enemy.health
		elif active_node_type == "boss":
			enemy.attack += 3
			enemy.health += 5
			enemy.max_health = enemy.health

		team.append(enemy)

	return team
func _pick_enemy_for_location() -> MonsterData:
	var pool: Array[MonsterData] = []

	match selected_location:
		"cave":
			pool = [
				get_monster_by_id("golem"),
				get_monster_by_id("slime")
			]
		"forest":
			pool = [
				get_monster_by_id("wolf"),
				get_monster_by_id("slime")
			]
		"crypt":
			pool = [
				get_monster_by_id("imp"),
				get_monster_by_id("golem")
			]
		_:
			pool = enemy_pool

	return pool.pick_random()
func _get_enemy_team_size() -> int:
	match active_node_type:
		"elite":
			return min(4, 2 + int(round_num / 2))
		"boss":
			return 5
		_:
			if round_num <= 1:
				return 2
			elif round_num <= 3:
				return 3
			elif round_num <= 5:
				return 4
			else:
				return 5

func _get_enemy_pool_for_round() -> Array:
	var pool: Array = []

	if round_num <= 1:
		for monster in enemy_pool:
			if monster.id in ["slime", "imp", "golem"]:
				pool.append(monster)
				pool.append(monster)
	elif round_num <= 3:
		for monster in enemy_pool:
			pool.append(monster)
	else:
		for monster in enemy_pool:
			pool.append(monster)
			pool.append(monster)

	return pool
func select_map_location(location_id: String) -> void:
	selected_location = location_id

	match location_id:
		"cave":
			selected_location_label = "Cave"
			active_node_type = "combat"
		"forest":
			selected_location_label = "Forest"
			active_node_type = "combat"
		"crypt":
			selected_location_label = "Crypt"
			active_node_type = "elite"
		_:
			selected_location_label = ""
			active_node_type = ""

func clear_selected_location() -> void:
	selected_location = ""
	selected_location_label = ""
	active_node_type = ""
func add_instinct_to_monster(monster: MonsterData, instinct: Dictionary) -> bool:
	if monster == null:
		return false

	var instincts_array: Array = monster.instincts

	for existing in instincts_array:
		if typeof(existing) != TYPE_DICTIONARY:
			continue

		var existing_type := String(existing.get("type", ""))
		var existing_rule := String(existing.get("rule", ""))

		if existing_type == String(instinct.get("type", "")) and existing_rule == String(instinct.get("rule", "")):
			return false

	instincts_array.append(instinct)
	monster.instincts = instincts_array
	return true
func get_instinct_shop_pool() -> Array:
	return [
		{
			"shop_type": "instinct",
			"id": "target_highest_health",
			"name": "Hunter Instinct",
			"description": "Attack the highest health enemy",
			"type": "targeting",
			"rule": "highest_health",
			"cost": 1
		},
		{
			"shop_type": "instinct",
			"id": "target_lowest_health",
			"name": "Execute Instinct",
			"description": "Attack the lowest health enemy",
			"type": "targeting",
			"rule": "lowest_health",
			"cost": 1
		},
		{
			"shop_type": "instinct",
			"id": "target_front",
			"name": "Front Instinct",
			"description": "Attack the front enemy",
			"type": "targeting",
			"rule": "front",
			"cost": 1
		}
	]
func add_instinct_to_hand(item: ItemData) -> void:
	hand_instincts.append(item)
func build_first_run():
	run_nodes = [
		{"type": "combat", "id": "cave_1"},
		{"type": "combat", "id": "cave_2"},
		{"type": "reward", "id": "reward_1"},
		{"type": "elite", "id": "elite_cave"},
		{"type": "campfire"},
		{"type": "combat", "id": "forest_1"},
		{"type": "shop"},
		{"type": "boss", "id": "midboss"},
		{"type": "combat", "id": "crypt_1"},
		{"type": "reward", "id": "reward_2"},
		{"type": "boss", "id": "final_boss"},
	]
	current_node_index = 0
func instinct_dict_to_item(instinct: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.id = String(instinct.get("id", "instinct"))
	item.display_name = String(instinct.get("name", "Instinct"))
	item.cost = 1
	item.item_kind = "instinct"
	item.instinct_type = String(instinct.get("type", ""))
	item.instinct_rule = String(instinct.get("rule", ""))
	item.description = String(instinct.get("description", ""))
	return item


func return_monster_instincts_to_hand(monster: MonsterData) -> void:
	if monster == null:
		return

	for inst in monster.instincts:
		if typeof(inst) != TYPE_DICTIONARY:
			continue

		var item := instinct_dict_to_item(inst)
		hand_cards.append({
			"card_type": "instinct",
			"item": item
		})

	monster.instincts.clear()
func build_enemy_team_for_encounter(encounter_id: String) -> Array:
	match encounter_id:

		"cave_1":
			return [
				create_enemy("slime"),
				create_enemy("slime")
			]

		"cave_2":
			return [
				create_enemy("slime"),
				create_enemy("bat")
			]

		"forest_1":
			return [
				create_enemy("bat"),
				create_enemy("bat")
			]

		"elite_1":
			return [
				create_enemy("tank"),
				create_enemy("bat"),
				create_enemy("bat")
			]

		"crypt_1":
			return [
				create_enemy("slime"),
				create_enemy("tank")
			]

		"boss_1":
			return [
				create_enemy("boss")
			]

		_:
			return build_dummy_enemy_team()

func create_enemy(type: String) -> Dictionary:
	match type:

		"slime":
			return {
				"id": "slime",
				"display_name": "Slime",
				"attack": 2,
				"health": 3,
				"max_health": 3,
				"tribe": "Slime",
				"modifiers": [],
				"equipped_modifiers": [],
				"instincts": []
			}

		"bat":
			return {
				"id": "bat",
				"display_name": "Bat",
				"attack": 3,
				"health": 2,
				"max_health": 2,
				"tribe": "Beast",
				"modifiers": [],
				"equipped_modifiers": [],
				"instincts": []
			}

		"tank":
			return {
				"id": "tank",
				"display_name": "Stone Guard",
				"attack": 1,
				"health": 6,
				"max_health": 6,
				"tribe": "Construct",
				"modifiers": ["taunt"],
				"equipped_modifiers": [],
				"instincts": []
			}

		"boss":
			return {
				"id": "boss",
				"display_name": "Cave Brute",
				"attack": 5,
				"health": 12,
				"max_health": 12,
				"tribe": "Beast",
				"modifiers": [],
				"equipped_modifiers": [],
				"instincts": []
			}

	return {}
	
func build_dummy_enemy_team() -> Array:
	var team: Array = []

	team.append({
		"id": "enemy_slime",
		"display_name": "Enemy Slime",
		"attack": 2,
		"health": 3,
		"max_health": 3,
		"tribe": "Slime",
		"modifiers": [],
		"equipped_modifiers": [],
		"instincts": []
	})

	team.append({
		"id": "enemy_bat",
		"display_name": "Enemy Bat",
		"attack": 1,
		"health": 2,
		"max_health": 2,
		"tribe": "Bat",
		"modifiers": [],
		"equipped_modifiers": [],
		"instincts": []
	})

	return team
