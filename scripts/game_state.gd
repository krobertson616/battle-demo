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

var saved_monsters: Array[MonsterData] = []
var bosses_cleared_this_run: int = 0
var pending_extract_count: int = 0

var selected_roster_indexes: Array[int] = []
var current_run_background_path: String = ""

var starter_offer_ids: Array[String] = [
	"golem",       # Pebble
	"slime",        # Sheni
	"imp",         # Imp
	"mossmender",  # healer
	"fang_adder",  # poison
	"frost_wisp"   # control
]

var selected_starter_team: Array[MonsterData] = []


func _ready() -> void:
	randomize()
	_build_monster_pools()

func _build_monster_pools() -> void:
	all_monsters.clear()
	shop_pool.clear()
	enemy_pool.clear()

	all_monsters = [
		# Existing base roster
# Base roster
_make("wolf", "Sheni", "Fang", 1, 2, 5, "alpha_wolf"),
_make("imp", "Kandel", "Ember", 1, 3, 4, "fireling"),
_make("slime", "Skillet", "Slime", 1, 1, 5, "superslime"),
_make("golem", "Pebble", "Stone", 1, 1, 8, "stone_guardian"),

# Evolutions
_make("alpha_wolf", "Shen-Zi", "Fang", 3, 4, 7, "none"),
_make("fireling", "Fireling", "Ember", 2, 4, 5, "none"),
_make("superslime", "King Slime", "Slime", 1, 2, 8, "none"),
_make("stone_guardian", "Guardian", "Stone", 3, 2, 11, "none"),

# New base shop creatures
_make("mossmender", "Loomi", "Grove", 1, 1, 6, "elder_mossmender"),
_make("fang_adder", "Platty", "Venom", 1, 2, 5, "venom_maw"),
_make("razor_mite", "Rosssie", "Skitter", 1, 1, 4, "razor_horror"),
_make("frost_wisp", "Brram", "Frost", 1, 1, 6, "icebound_seer"),

# New evolutions
_make("elder_mossmender", "Elder Mossmender", "Grove", 4, 2, 9, "none"),
_make("venom_maw", "Venom Maw", "Venom", 4, 3, 7, "none"),
_make("razor_horror", "Razor Horror", "Skitter", 4, 2, 6, "none"),
_make("icebound_seer", "Icebound Seer", "Frost", 4, 2, 8, "none"),
	]

	shop_pool = [
		get_monster_by_id("wolf"),
		get_monster_by_id("imp"),
		get_monster_by_id("slime"),
		get_monster_by_id("golem"),
		get_monster_by_id("mossmender"),
		get_monster_by_id("fang_adder"),
		get_monster_by_id("razor_mite"),
		get_monster_by_id("frost_wisp"),
	]

	enemy_pool = [
		get_monster_by_id("wolf"),
		get_monster_by_id("imp"),
		get_monster_by_id("slime"),
		get_monster_by_id("golem"),
		get_monster_by_id("mossmender"),
		get_monster_by_id("fang_adder"),
		get_monster_by_id("razor_mite"),
		get_monster_by_id("frost_wisp"),
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
	m.modifier_slots = get_upgrade_slot_count_for_level(1)

	if id == "golem":
		m.modifiers.append("taunt")

	if id == "stone_guardian":
		m.modifiers.append("taunt")

	if id == "wolf":
		m.modifiers.append("pack_hunter")

	if id == "alpha_wolf":
		m.modifiers.append("pack_hunter")

	if id == "imp":
		m.modifiers.append("burn")

	if id == "fireling":
		m.modifiers.append("burn")

	if id == "slime":
		m.modifiers.append("oil")

	if id == "superslime":
		m.modifiers.append("oil")

	if id == "mossmender":
		m.modifiers.append("heal")

	if id == "elder_mossmender":
		m.modifiers.append("heal")

	if id == "fang_adder":
		m.modifiers.append("poison")

	if id == "venom_maw":
		m.modifiers.append("poison")

	if id == "razor_mite":
		m.modifiers.append("windfury")

	if id == "razor_horror":
		m.modifiers.append("windfury")

	if id == "frost_wisp":
		m.modifiers.append("freeze")

	if id == "icebound_seer":
		m.modifiers.append("freeze")
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
	if id == "mossmender":
		m.set_meta("texture", load("res://assets/mossmender.png"))
	if id == "elder_mossmender":
		m.set_meta("texture", load("res://assets/mossmender.png"))
	if id == "fang_adder":
		m.set_meta("texture", load("res://assets/spider.png"))
	if id == "venom_maw":
		m.set_meta("texture", load("res://assets/spider.png"))
	if id == "razor_mite":
		m.set_meta("texture", load("res://assets/CaveRaptor.png"))
	if id == "razor_horror":
		m.set_meta("texture", load("res://assets/CaveRaptor.png"))
	if id == "frost_wisp":
		m.set_meta("texture", load("res://assets/chillmoth.png"))
	if id == "icebound_seer":
		m.set_meta("texture", load("res://assets/chillmoth.png"))

	return m
func build_first_test_run() -> void:
	run_encounters = [
		"cave_boss_1",
		"cave_1",
		"cave_2",
		"event_crystal_infusion",
		"cave_3",
		"cave_4",
		"event_instinct_shop",
		"cave_5",
		"cave_elite_1",
		"event_ancient_camp",
		"cave_6",
		"event_strange_totem",
		"cave_7",
	]
	current_encounter_index = 0
	current_encounter_index = 0
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
	m.level = template.level
	m.xp = template.xp

	if template.has_meta("texture"):
		m.set_meta("texture", template.get_meta("texture"))

	return m
func save_monster_to_roster(monster: MonsterData) -> void:
	if monster == null:
		return

	var saved_copy := clone_monster(monster)

	# If this monster came from the roster, overwrite the old entry
	if monster.has_meta("source_roster_index"):
		var source_index := int(monster.get_meta("source_roster_index"))
		if source_index >= 0 and source_index < saved_monsters.size():
			saved_monsters[source_index] = saved_copy
			return

	# Otherwise it's a brand new monster, so add it
	saved_monsters.append(saved_copy)
func reset_run_for_new_attempt() -> void:
	run_started = false

	pending_player_team = []
	pending_enemy_team = []
	pending_result = {}

	board_monsters = [null, null, null, null, null, null]
	hand_monsters = []
	shop_monsters = []
	hand_cards = []
	shop_items = []

	clear_selected_location()

	current_encounter_index = 0
	current_node_id = 0
	selected_next_node_id = -1

	bosses_cleared_this_run = 0
	pending_extract_count = 0
func can_add_modifier(monster: MonsterData, modifier_id: String) -> bool:
	if monster == null:
		return false

	if monster.modifier_slots <= 0:
		return false

	if get_used_upgrade_slots(monster) >= monster.modifier_slots:
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
	if not can_add_instinct(monster, instinct):
		return false

	var instincts_array: Array = monster.instincts
	instincts_array.append(instinct)
	monster.instincts = instincts_array
	return true
func get_instinct_shop_pool() -> Array:
	return [
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
			"id": "target_burning",
			"name": "Scorch Hunter",
			"description": "Attack burning enemies first",
			"type": "targeting",
			"rule": "burning",
			"cost": 1
		},
		{
			"shop_type": "instinct",
			"id": "target_poisoned",
			"name": "Venom Hunter",
			"description": "Attack poisoned enemies first",
			"type": "targeting",
			"rule": "poisoned",
			"cost": 1
		},
		{
			"shop_type": "instinct",
			"id": "target_frozen",
			"name": "Frost Hunter",
			"description": "Attack frozen enemies first",
			"type": "targeting",
			"rule": "frozen",
			"cost": 1
		},
		{
			"shop_type": "instinct",
			"id": "thick_hide",
			"name": "Thick Hide",
			"description": "Takes 1 less damage from attacks",
			"type": "passive",
			"rule": "reduce_damage",
			"value": 1,
			"cost": 1
		},
		{
			"shop_type": "instinct",
			"id": "spiked_shell",
			"name": "Spiked Shell",
			"description": "When hit by an attack, deal 1 damage back",
			"type": "passive",
			"rule": "thorns_on_hit",
			"value": 1,
			"cost": 1
		},
		{
			"shop_type": "instinct",
			"id": "blood_rush",
			"name": "Blood Rush",
			"description": "When this kills an enemy, gain +1 attack",
			"type": "passive",
			"rule": "gain_attack_on_kill",
			"value": 1,
			"cost": 1
		},
		{
			"shop_type": "instinct",
			"id": "kindling",
			"name": "Kindling",
			"description": "Deal +1 damage to greased enemies",
			"type": "passive",
			"rule": "bonus_vs_greased",
			"value": 1,
			"cost": 1
		},
		{
			"shop_type": "instinct",
			"id": "wildfire",
			"name": "Wildfire",
			"description": "After damaging a burning enemy, gain +1 attack this combat",
			"type": "passive",
			"rule": "gain_attack_on_burning_hit",
			"value": 1,
			"cost": 1
		},
		{
			"shop_type": "instinct",
			"id": "slick_strikes",
			"name": "Slick Strikes",
			"description": "First successful attack each combat also applies greased",
			"type": "passive",
			"rule": "first_hit_grease",
			"value": 1,
			"cost": 1
		},
		{
			"shop_type": "instinct",
			"id": "venom_fang",
			"name": "Venom Fang",
			"description": "Deal +1 damage to poisoned enemies",
			"type": "passive",
			"rule": "bonus_vs_poisoned",
			"value": 1,
			"cost": 1
		},
		{
			"shop_type": "instinct",
			"id": "shatter_instinct",
			"name": "Shatter Instinct",
			"description": "Deal +2 damage to frozen enemies",
			"type": "passive",
			"rule": "bonus_vs_frozen",
			"value": 2,
			"cost": 1
		},
		{
			"shop_type": "instinct",
			"id": "prune_instinct",
			"name": "Prune Instinct",
			"description": "Drag onto a creature to destroy one instinct on it.",
			"type": "utility",
			"rule": "remove_instinct",
			"value": 1,
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
	item.instinct_value = int(instinct.get("value", 0))
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

		"cave_3":
			return [
				create_enemy("spider"),
				create_enemy("slime")
			]

		"cave_4":
			return [
				create_enemy("moth"),
				create_enemy("bat")
			]

		"cave_5":
			return [
				create_enemy("tank"),
				create_enemy("spider"),
				create_enemy("bat")
			]

		"cave_elite_1":
			return [
				create_enemy("tank"),
				create_enemy("shaman"),
				create_enemy("raptor")
			]

		"cave_6":
			return [
				create_enemy("slime"),
				create_enemy("moth"),
				create_enemy("raptor")
			]

		"cave_7":
			return [
				create_enemy("tank"),
				create_enemy("spider"),
				create_enemy("shaman")
			]

		"cave_boss_1":
			return [
				create_enemy("volatile_conductor")
			]

		_:
			return build_dummy_enemy_team()
func create_enemy(type: String) -> Dictionary:
	match type:
		"slime":
			return {
				"id": "slime",
				"display_name": "Cave Slime",
				"attack": 1,
				"health": 8,
				"max_health": 8,
				"tribe": "Slime",
				"modifiers": ["oil"],
				"equipped_modifiers": [],
				"instincts": [],
				"texture": load("res://assets/caveslime.png")
			}

		"bat":
			return {
				"id": "bat",
				"display_name": "Ember Bat",
				"attack": 2,
				"health": 5,
				"max_health": 5,
				"tribe": "Beast",
				"modifiers": ["burn"],
				"equipped_modifiers": [],
				"instincts": [],
				"texture": load("res://assets/cavebat.png")
			}

		"spider":
			return {
				"id": "spider",
				"display_name": "Fang Spider",
				"attack": 2,
				"health": 7,
				"max_health": 7,
				"tribe": "Venom",
				"modifiers": ["poison"],
				"equipped_modifiers": [],
				"instincts": [],
				"texture": load("res://assets/spider.png")
			}

		"moth":
			return {
				"id": "moth",
				"display_name": "Chill Moth",
				"attack": 1,
				"health": 8,
				"max_health": 8,
				"tribe": "Frost",
				"modifiers": ["freeze"],
				"equipped_modifiers": [],
				"instincts": [],
				"texture": load("res://assets/chillmoth.png")
			}

		"raptor":
			return {
				"id": "raptor",
				"display_name": "Cave Raptor",
				"attack": 2,
				"health": 5,
				"max_health": 5,
				"tribe": "Skitter",
				"modifiers": ["windfury"],
				"equipped_modifiers": [],
				"instincts": [],
				"texture": load("res://assets/CaveRaptor.png")
			}

		"shaman":
			return {
				"id": "shaman",
				"display_name": "Cave Shaman",
				"attack": 1,
				"health": 9,
				"max_health": 9,
				"tribe": "Grove",
				"modifiers": ["heal"],
				"equipped_modifiers": [],
				"instincts": [],
				"texture": load("res://assets/mossmender.png")
			}

		"tank":
			return {
				"id": "tank",
				"display_name": "Stone Guard",
				"attack": 1,
				"health": 14,
				"max_health": 14,
				"tribe": "Construct",
				"modifiers": ["taunt"],
				"equipped_modifiers": [],
				"instincts": [],
				"texture": load("res://assets/rockmonster.png")
			}

		"boss":
			return {
				"id": "boss",
				"display_name": "Cave Brute",
				"attack": 4,
				"health": 28,
				"max_health": 28,
				"tribe": "Beast",
				"modifiers": [],
				"equipped_modifiers": [],
				"instincts": [],
				"texture": load("res://assets/cryptlord.png")
			}
		"volatile_conductor":
			return {
				"id": "volatile_conductor",
				"display_name": "Volatile Conductor",
				"attack": 2,
				"health": 64,
				"max_health": 64,
				"tribe": "Boss",
				"modifiers": [],
				"equipped_modifiers": [],
				"instincts": [],
				"texture": load("res://assets/cryptlord.png")
			}

		"fireling":
			return {
				"id": "fireling",
				"display_name": "Fireling",
				"attack": 0,
				"health": 4,
				"max_health": 4,
				"tribe": "Ember",
				"modifiers": [],
				"equipped_modifiers": [],
				"instincts": [],
				"texture": load("res://assets/cavebat.png")
			}

		"greaseling":
			return {
				"id": "greaseling",
				"display_name": "Greaseling",
				"attack": 0,
				"health": 3,
				"max_health": 3,
				"tribe": "Slime",
				"modifiers": [],
				"equipped_modifiers": [],
				"instincts": [],
				"texture": load("res://assets/caveslime.png")
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
func get_xp_needed_for_next_level(current_level: int) -> int:
	match current_level:
		1:
			return 2
		2:
			return 3
		3:
			return 4
		4:
			return 5
		5:
			return 6
		6:
			return 7
		7:
			return 8
		8:
			return 9
		9:
			return 10
		10:
			return 11
		11:
			return 12
		_:
			return 999

func grant_monster_xp(monster: MonsterData, amount: int) -> void:
	if monster == null:
		return

	monster.xp += amount

	while monster.level < 12:
		var needed := get_xp_needed_for_next_level(monster.level)
		if monster.xp < needed:
			break

		monster.xp -= needed
		monster.level += 1
		monster.modifier_slots = get_upgrade_slot_count_for_level(monster.level)
		monster.attack += 1
		monster.max_health += 1
		monster.health = min(monster.max_health, monster.health + 1)

		if monster.level == 10:
			_try_evolve_monster(monster)
			
func _try_evolve_monster(monster: MonsterData) -> void:
	if monster == null:
		return

	if monster.evolves_to_id == "" or monster.evolves_to_id == "none":
		return

	var evolved_template := get_monster_by_id(monster.evolves_to_id)
	if evolved_template == null:
		return

	var old_attack := monster.attack
	var old_max_health := monster.max_health
	var old_health := monster.health
	var old_xp := monster.xp
	var old_level := monster.level
	var old_instincts := monster.instincts.duplicate()
	var old_equipped := monster.equipped_modifiers.duplicate()

	monster.id = evolved_template.id
	monster.display_name = evolved_template.display_name
	monster.tribe = evolved_template.tribe
	monster.cost = evolved_template.cost
	monster.evolves_to_id = evolved_template.evolves_to_id
	monster.modifiers = evolved_template.modifiers.duplicate()
	monster.modifier_slots = get_upgrade_slot_count_for_level(old_level)

	# Keep progression and attachments
	monster.instincts = old_instincts
	monster.equipped_modifiers = old_equipped
	monster.level = old_level
	monster.modifier_slots = get_upgrade_slot_count_for_level(monster.level)
	monster.xp = old_xp

	# Never let evolution feel like a downgrade
	monster.attack = max(old_attack, evolved_template.attack) + 1
	monster.max_health = max(old_max_health, evolved_template.max_health) + 1
	monster.health = max(old_health, monster.max_health)

	if evolved_template.has_meta("texture"):
		monster.set_meta("texture", evolved_template.get_meta("texture"))
		
func can_feed_monster_to_target(feeder: MonsterData, target: MonsterData) -> bool:
	if feeder == null or target == null:
		return false

	# Same form can always feed
	if feeder.id == target.id:
		return true

	# Lower form can feed directly into its next evolution
	if feeder.evolves_to_id == target.id:
		return true

	return false


func add_roster_monster_to_team(index: int) -> bool:
	if index < 0 or index >= saved_monsters.size():
		return false
	if index in selected_roster_indexes:
		return false
	if selected_roster_indexes.size() >= 3:
		return false

	selected_roster_indexes.append(index)
	return true


func remove_roster_monster_from_team(index: int) -> void:
	selected_roster_indexes.erase(index)


func clear_selected_team() -> void:
	selected_roster_indexes.clear()


func get_selected_team_total_level() -> int:
	var total := 0
	for index in selected_roster_indexes:
		if index >= 0 and index < saved_monsters.size():
			total += saved_monsters[index].level
	return total


func get_selected_team_clones() -> Array[MonsterData]:
	var team: Array[MonsterData] = []
	for index in selected_roster_indexes:
		if index >= 0 and index < saved_monsters.size():
			team.append(clone_monster(saved_monsters[index]))
	return team


func start_new_run_from_map(location_id: String) -> void:
	selected_location = location_id

	match location_id:
		"cave":
			selected_location_label = "Cave"
		"forest":
			selected_location_label = "Forest"
		"crypt":
			selected_location_label = "Crypt"
		_:
			selected_location_label = location_id.capitalize()

	gold = 3
	health = 10
	round_num = 1
	max_board_slots = 3

	board_monsters = [null, null, null, null, null, null]
	hand_monsters = []
	shop_monsters = []
	hand_cards = []
	shop_items = []
	var prune_instinct := get_instinct_dict_by_id("prune_instinct")
	if not prune_instinct.is_empty():
		add_instinct_reward_to_hand(prune_instinct)
	pending_player_team = []
	pending_enemy_team = []
	pending_result = {}

	bosses_cleared_this_run = 0
	pending_extract_count = 0

	build_first_test_run()
	current_encounter_index = 0
	run_started = true

	for i in range(min(selected_roster_indexes.size(), board_monsters.size())):
		var roster_index := selected_roster_indexes[i]
		if roster_index < 0 or roster_index >= saved_monsters.size():
			continue

		if location_id != "cave":
			var starters := get_selected_team_clones()
			for starter_idx in range(min(starters.size(), board_monsters.size())):
				board_monsters[starter_idx] = starters[starter_idx]
		if location_id == "cave":
			var cave_background_paths := [
				"res://assets/cave/cave.png",
				"res://assets/cave/cave2.png",
				"res://assets/cave/cave3.png",
				"res://assets/cave/cave4.png",
				"res://assets/cave/cave5.png",
				"res://assets/cave/cave6.png",

			]
			current_run_background_path = cave_background_paths.pick_random()
		else:
			current_run_background_path = ""

func end_run_to_map() -> void:
	run_started = false

	board_monsters = [null, null, null, null, null, null]
	hand_monsters = []
	shop_monsters = []
	hand_cards = []
	shop_items = []

	pending_player_team = []
	pending_enemy_team = []
	pending_result = {}

	current_encounter_index = 0
	bosses_cleared_this_run = 0
	pending_extract_count = 0

	clear_selected_location()
	
func build_instinct_reward_choices(count: int = 3) -> Array:
	var pool: Array = get_instinct_shop_pool().duplicate(true)
	pool.shuffle()

	var picks: Array = []
	while picks.size() < count and not pool.is_empty():
		picks.append(pool.pop_back())

	return picks


func add_instinct_reward_to_hand(instinct: Dictionary) -> void:
	var item := instinct_dict_to_item(instinct)
	hand_cards.append({
		"card_type": "instinct",
		"item": item
	})
func get_upgrade_slot_count_for_level(level: int) -> int:
	var safe_level: int = int(max(1, level))

	if safe_level >= 10:
		return 3
	elif safe_level >= 5:
		return 2
	else:
		return 1

func get_used_upgrade_slots(monster: MonsterData) -> int:
	if monster == null:
		return 0

	return monster.equipped_modifiers.size() + monster.instincts.size()


func can_add_instinct(monster: MonsterData, instinct: Dictionary) -> bool:
	if monster == null:
		return false

	if get_used_upgrade_slots(monster) >= monster.modifier_slots:
		return false

	for existing in monster.instincts:
		if typeof(existing) != TYPE_DICTIONARY:
			continue

		var existing_type := String(existing.get("type", ""))
		var existing_rule := String(existing.get("rule", ""))

		if existing_type == String(instinct.get("type", "")) and existing_rule == String(instinct.get("rule", "")):
			return false

	return true
func is_event_encounter(encounter_id: String) -> bool:
	return encounter_id.begins_with("event_")


func get_board_monster_entries() -> Array:
	var entries: Array = []

	for i in range(min(board_monsters.size(), max_board_slots)):
		var monster: MonsterData = board_monsters[i]
		if monster != null:
			entries.append({
				"slot_index": i,
				"monster": monster
			})

	return entries


func heal_all_board_monsters_full() -> void:
	for i in range(min(board_monsters.size(), max_board_slots)):
		var monster: MonsterData = board_monsters[i]
		if monster == null:
			continue
		monster.health = monster.max_health


func grant_board_monster_slot(slot_index: int, amount: int = 1) -> bool:
	if slot_index < 0 or slot_index >= board_monsters.size():
		return false

	var monster: MonsterData = board_monsters[slot_index]
	if monster == null:
		return false

	monster.modifier_slots = min(3, monster.modifier_slots + amount)
	return true


func grant_board_monster_attack(slot_index: int, amount: int = 1) -> bool:
	if slot_index < 0 or slot_index >= board_monsters.size():
		return false

	var monster: MonsterData = board_monsters[slot_index]
	if monster == null:
		return false

	monster.attack += amount
	return true


func grant_board_monster_health(slot_index: int, amount: int = 2) -> bool:
	if slot_index < 0 or slot_index >= board_monsters.size():
		return false

	var monster: MonsterData = board_monsters[slot_index]
	if monster == null:
		return false

	monster.max_health += amount
	monster.health = min(monster.max_health, monster.health + amount)
	return true


func add_random_instinct_reward_to_hand() -> Dictionary:
	var picks: Array = build_instinct_reward_choices(1)
	if picks.is_empty():
		return {}

	var instinct: Dictionary = picks[0]
	add_instinct_reward_to_hand(instinct)
	return instinct
func remove_instinct_from_monster(monster: MonsterData, instinct_id: String) -> Dictionary:
	if monster == null:
		return {}

	var instincts_array: Array = monster.instincts

	for i in range(instincts_array.size()):
		var inst = instincts_array[i]

		if typeof(inst) == TYPE_DICTIONARY:
			var inst_dict: Dictionary = inst
			if String(inst_dict.get("id", "")) == instinct_id:
				var removed: Dictionary = inst_dict.duplicate(true)
				instincts_array.remove_at(i)
				monster.instincts = instincts_array
				return removed

	return {}
	
func get_instinct_dict_by_id(instinct_id: String) -> Dictionary:
	for instinct in get_instinct_shop_pool():
		if String(instinct.get("id", "")) == instinct_id:
			return instinct.duplicate(true)
	return {}
func build_starter_offer() -> Array[MonsterData]:
	var offer: Array[MonsterData] = []
	for id in starter_offer_ids:
		var template := get_monster_by_id(id)
		if template != null:
			offer.append(clone_monster(template))
	return offer

func clear_starter_team() -> void:
	selected_starter_team.clear()
func begin_cave_run_with_starters(team: Array[MonsterData]) -> void:
	var chosen_team: Array[MonsterData] = team.duplicate()

	reset_run_for_new_attempt()
	start_new_run_from_map("cave")

	selected_starter_team.clear()
	hand_monsters.clear()
	hand_cards.clear()

	for monster in chosen_team:
		var copy: MonsterData = clone_monster(monster)
		selected_starter_team.append(copy)
		hand_monsters.append(copy)
		hand_cards.append({
			"card_type": "monster",
			"monster": copy
		})
