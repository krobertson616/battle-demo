extends Control

const BOARD_SIZE := 6
const SHOP_SIZE := 4
const HAND_SIZE := 6


var item_pool: Array = []

@onready var top_bar: Label = $MarginContainer/VBoxContainer/TopBarLabel
@onready var shop_row: HBoxContainer = $MarginContainer/VBoxContainer/ShopSection/ShopRow
@onready var board_row: HBoxContainer = $MarginContainer/VBoxContainer/BoardRow
@onready var reroll_btn: Button = $MarginContainer/VBoxContainer/ShopSection/RerollButton
@onready var start_btn: Button = $MarginContainer/VBoxContainer/StartCombatButton
@onready var hand_row: HBoxContainer = $MarginContainer/VBoxContainer/HandRow
@onready var sell_strip = $SellStrip

var monster_card_scene = preload("res://scenes/monster_card.tscn")
var board_slot_scene = preload("res://scenes/board_slot.tscn")
var instinct_card_scene = preload("res://scenes/instinct_card.tscn")


func _ready() -> void:
	item_pool = _create_item_pool()
	sell_strip.card_sold.connect(_on_card_sold_to_shop)
	shop_row.card_sold.connect(_on_card_sold_to_shop)
	GameState.sell_strip_ref = sell_strip

	reroll_btn.pressed.connect(_reroll)
	start_btn.pressed.connect(_start_combat)

	_apply_pending_combat_result()

	if not GameState.run_started:
		GameState.gold = 99
		GameState.health = 10
		GameState.round_num = 1
		GameState.max_board_slots = 3
		GameState.board_monsters = [null, null, null, null, null, null]
		GameState.hand_monsters = []
		GameState.shop_monsters = []
		GameState.run_started = true
		GameState.build_first_test_run()
		GameState.map_nodes = GameState.build_test_map()
		GameState.current_node_id = 0
		GameState.selected_next_node_id = -1
		GameState.hand_cards.clear()
		
		
	if GameState.shop_monsters.is_empty():
		roll_shop()
		
	refresh_ui()
	if GameState.round_num == 1 and GameState.pending_result.is_empty():
		add_log("Run started.")


func _apply_pending_combat_result() -> void:
	if GameState.pending_result.is_empty():
		return

	var combat_log = GameState.pending_result.get("log", [])
	var player_won: bool = GameState.pending_result.get("player_won", false)

	_apply_combat_damage_to_board()

	for line in combat_log:
		add_log(str(line))

	if player_won:
		add_log("[color=green]You win![/color]")
		GameState.gold += 3
		for survivor in GameState.pending_result.get("player_survivors", []):
			var slot_index := int(survivor.get("slot_index", -1))
			if slot_index >= 0 and slot_index < BOARD_SIZE:
				var m: MonsterData = GameState.board_monsters[slot_index]
				if m != null:
					GameState.grant_monster_xp(m, 1)
					add_log("%s gained 1 XP." % m.display_name)

		var cleared_encounter_id := GameState.get_current_encounter_id()
		if cleared_encounter_id == "elite_1":
			GameState.max_board_slots = 4
			add_log("[color=yellow]A new board slot unlocked![/color]")

		GameState.current_encounter_index += 1
		print("Advanced to encounter index: ", GameState.current_encounter_index)
	else:
		add_log("[color=red]You lose![/color]")
		GameState.health -= 2
		GameState.gold += 2

	GameState.round_num += 1

	if GameState.health <= 0:
		add_log("[b][color=red]Run Over[/color][/b]")
		start_btn.disabled = true
		reroll_btn.disabled = true

	roll_shop()

	GameState.pending_result = {}
	GameState.pending_player_team = []
	GameState.pending_enemy_team = []

func roll_shop() -> void:
	GameState.shop_monsters.clear()
	GameState.shop_items.clear()

	for i in range(3):
		var template: MonsterData = GameState.shop_pool.pick_random()
		GameState.shop_monsters.append(GameState.clone_monster(template))

	GameState.shop_items.append(item_pool.pick_random())

func refresh_ui() -> void:
	top_bar.text = "Round %d   Gold: %d   Health: %d   Area: %s" % [
	GameState.round_num,
	GameState.gold,
	GameState.health,
	GameState.selected_location_label if GameState.selected_location_label != "" else "None"
]

	for c in shop_row.get_children():
		c.queue_free()

	for c in board_row.get_children():
		c.queue_free()
		
	for c in hand_row.get_children():
		c.queue_free()


# Shop
	# Shop monsters
	for i in range(3):
		var m = null
		if i < GameState.shop_monsters.size():
			m = GameState.shop_monsters[i]

		if m != null:
			var card = monster_card_scene.instantiate()
			card.setup(m, "shop", i)
			card.modifier_changed.connect(refresh_ui)
			card.pressed.connect(_buy.bind(i))
			shop_row.add_child(card)
		else:
			var slot := PanelContainer.new()
			slot.custom_minimum_size = Vector2(150, 180)
			shop_row.add_child(slot)

	# Shop item slot
	var item = null
	if GameState.shop_items.size() > 0:
		item = GameState.shop_items[0]

	if item != null:
		var button := Button.new()
		button.text = "%s\nCost: %d" % [item.display_name, item.cost]
		button.custom_minimum_size = Vector2(150, 180)
		button.pressed.connect(_buy_item.bind(0))
		shop_row.add_child(button)
	else:
		var item_slot := PanelContainer.new()
		item_slot.custom_minimum_size = Vector2(150, 180)
		shop_row.add_child(item_slot)
	

	# Hand
	# Hand
	for i in range(GameState.hand_cards.size()):
		var entry = GameState.hand_cards[i]
		var card_type: String = String(entry.get("card_type", ""))

		if card_type == "monster":
			var m = entry.get("monster")
			if m == null:
				continue

			var card = monster_card_scene.instantiate()
			card.setup(m, "hand", i)
			card.modifier_changed.connect(refresh_ui)
			hand_row.add_child(card)

		elif card_type == "instinct":
			var instinct_item: ItemData = entry.get("item")
			if instinct_item == null:
				continue

			var card := Button.new()
			card.text = "%s\nCost: %d\n%s" % [
				instinct_item.display_name,
				instinct_item.cost,
				instinct_item.description
			]
			card.custom_minimum_size = Vector2(150, 180)

			card.set_script(load("res://scripts/instinct_card.gd"))
			card.setup(instinct_item, "hand", i)

			hand_row.add_child(card)
	# Board
	for i in range(GameState.max_board_slots):
		var slot = board_slot_scene.instantiate()
		slot.slot_index = i
		slot.custom_minimum_size = Vector2(150, 180)

		slot.card_dropped.connect(_on_card_dropped_to_board)
		slot.instinct_dropped.connect(_on_instinct_dropped_to_board)

		board_row.add_child(slot)

		var m = GameState.board_monsters[i]
		if m != null:
			var card = monster_card_scene.instantiate()
			card.setup(m, "board", i)
			card.modifier_changed.connect(refresh_ui)
			card.instinct_dropped_on_card.connect(_on_instinct_dropped_to_board)
			card.monster_dropped_on_card.connect(_on_card_dropped_to_board)
			card.board_swap_requested.connect(_on_board_swap_requested)
			slot.center_container.add_child(card)

	reroll_btn.text = "Reroll (1)"
	start_btn.text = "Start Combat"
func _on_board_swap_requested(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= BOARD_SIZE:
		return
	if to_index < 0 or to_index >= BOARD_SIZE:
		return
	if from_index >= GameState.max_board_slots or to_index >= GameState.max_board_slots:
		return
	if from_index == to_index:
		return

	var temp = GameState.board_monsters[from_index]
	GameState.board_monsters[from_index] = GameState.board_monsters[to_index]
	GameState.board_monsters[to_index] = temp

	refresh_ui()
func _buy(i: int) -> void:
	if i < 0 or i >= GameState.shop_monsters.size():
		return

	var m = GameState.shop_monsters[i]

	if GameState.gold < m.cost:
		add_log("Not enough gold.")
		return

	if GameState.hand_cards.size() >= HAND_SIZE:
		add_log("Hand full.")
		return

	GameState.gold -= m.cost
	GameState.hand_monsters.append(m)
	GameState.hand_cards.append({
		"card_type": "monster",
		"monster": m
	})
	GameState.shop_monsters.remove_at(i)


	print("HAND CARDS AFTER MONSTER BUY: ", GameState.hand_cards)
	add_log("Bought %s." % m.display_name)
	refresh_ui()

func _sell(i: int) -> void:
	if i < 0 or i >= BOARD_SIZE:
		return

	var m = GameState.board_monsters[i]
	if m == null:
		return

	GameState.return_monster_instincts_to_hand(m)
	GameState.board_monsters[i] = null
	GameState.gold += 1

	add_log("Sold %s." % m.display_name)
	refresh_ui()

func _reroll() -> void:
	if GameState.gold < 1:
		add_log("Not enough gold to reroll.")
		return

	GameState.gold -= 1
	roll_shop()
	refresh_ui()
	add_log("Shop rerolled.")

func _start_combat() -> void:
	var encounter_id := GameState.get_current_encounter_id()
	print("Starting encounter: ", encounter_id)

	var player_team: Array = []
	for i in range(BOARD_SIZE):
		var m = GameState.board_monsters[i]
		if m != null:
			m.set_meta("board_slot_index", i)
			player_team.append(m)
	if player_team.is_empty():
		add_log("Need at least one unit.")
		return

	if encounter_id == "":
		print("No more encounters. Run complete.")
		return

	GameState.pending_player_team = player_team
	GameState.pending_enemy_team = GameState.build_enemy_team_for_encounter(encounter_id)
	GameState.pending_result = {}

	get_tree().change_scene_to_file("res://scenes/arena_scene.tscn")
func add_log(t: String) -> void:
	# Temporary: keep combat logs out of the Output panel
	pass
func check_for_evolution() -> void:
	# Evolution is XP-only now.
	return
func _play_from_hand(i: int) -> void:
	if i < 0 or i >= GameState.hand_cards.size():
		return

	var entry = GameState.hand_cards[i]
	if String(entry.get("card_type", "")) != "monster":
		add_log("Only monster cards can be played to the board.")
		return

	var empty_index := -1

	for idx in range(GameState.max_board_slots):
		if GameState.board_monsters[idx] == null:
			empty_index = idx
			break

	if empty_index == -1:
		add_log("Board full.")
		return

	var m: MonsterData = entry.get("monster")
	if m == null:
		return

	GameState.hand_cards.remove_at(i)

	# Keep old array in sync for now
	var old_index := GameState.hand_monsters.find(m)
	if old_index != -1:
		GameState.hand_monsters.remove_at(old_index)

	GameState.board_monsters[empty_index] = m

	refresh_ui()

func _on_card_dropped_to_board(source_type: String, source_index: int, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= BOARD_SIZE:
		return
	if slot_index >= GameState.max_board_slots:
		add_log("That slot is locked.")
		return

	# From hand -> place or feed duplicate XP
	if source_type == "hand":
		if source_index < 0 or source_index >= GameState.hand_cards.size():
			return

		var entry = GameState.hand_cards[source_index]
		if String(entry.get("card_type", "")) != "monster":
			add_log("Only monster cards can be placed on the board.")
			return

		var m: MonsterData = entry.get("monster")
		if m == null:
			return

		var target: MonsterData = GameState.board_monsters[slot_index]
		var old_index := -1

		# Feed duplicate instead of placing
		if target != null and GameState.can_feed_monster_to_target(m, target):
			GameState.grant_monster_xp(target, 2)
			add_log("%s fed into %s for XP!" % [m.display_name, target.display_name])

			GameState.hand_cards.remove_at(source_index)

			old_index = GameState.hand_monsters.find(m)
			if old_index != -1:
				GameState.hand_monsters.remove_at(old_index)

			refresh_ui()
			await get_tree().process_frame

			var card_node = _get_board_card_node(slot_index)
			_show_floating_xp_over_card(card_node, 2)

			return

		# Occupied by a different monster
		if target != null:
			add_log("That slot is occupied.")
			return

		# Normal placement
		GameState.hand_cards.remove_at(source_index)

		old_index = GameState.hand_monsters.find(m)
		if old_index != -1:
			GameState.hand_monsters.remove_at(old_index)

		GameState.board_monsters[slot_index] = m

	# From board -> swap
	elif source_type == "board":
		if source_index < 0 or source_index >= BOARD_SIZE:
			return
		if source_index >= GameState.max_board_slots:
			return

		var temp = GameState.board_monsters[slot_index]
		GameState.board_monsters[slot_index] = GameState.board_monsters[source_index]
		GameState.board_monsters[source_index] = temp

	refresh_ui()
func _on_card_sold_to_shop(source_type: String, source_index: int, dragged_monster: MonsterData = null) -> void:
	print("SELL TRIGGERED: ", source_type, " ", source_index)

	if source_type == "hand":
		var m: MonsterData = dragged_monster

		if m == null:
			if source_index < 0 or source_index >= GameState.hand_cards.size():
				return

			var fallback_entry = GameState.hand_cards[source_index]
			if String(fallback_entry.get("card_type", "")) != "monster":
				add_log("Only monster cards can be sold for now.")
				return

			m = fallback_entry.get("monster")

		if m == null:
			return

		var remove_index := -1
		for i in range(GameState.hand_cards.size()):
			var entry = GameState.hand_cards[i]
			if String(entry.get("card_type", "")) == "monster" and entry.get("monster") == m:
				remove_index = i
				break

		if remove_index == -1:
			return

		GameState.return_monster_instincts_to_hand(m)
		GameState.hand_cards.remove_at(remove_index)

		var old_index := GameState.hand_monsters.find(m)
		if old_index != -1:
			GameState.hand_monsters.remove_at(old_index)

		GameState.gold += 1
		add_log("Sold %s." % m.display_name)
		refresh_ui()
		return

	if source_type == "board":
		if source_index < 0 or source_index >= BOARD_SIZE:
			return

		var m = GameState.board_monsters[source_index]
		if m == null:
			return

		GameState.return_monster_instincts_to_hand(m)
		GameState.board_monsters[source_index] = null
		GameState.gold += 1
		add_log("Sold %s." % m.display_name)
		refresh_ui()
		return
func _exit_tree() -> void:
	if GameState.sell_strip_ref == sell_strip:
		GameState.sell_strip_ref = null
func _apply_combat_damage_to_board() -> void:
	var survivors: Array = GameState.pending_result.get("player_survivors", [])

	var survivor_map := {}

	for survivor in survivors:
		survivor_map[survivor["slot_index"]] = survivor

	for i in range(BOARD_SIZE):
		var m = GameState.board_monsters[i]
		if m == null:
			continue

		if survivor_map.has(i):
			var survivor = survivor_map[i]
			m.health = int(survivor["health"])
			m.max_health = int(survivor["max_health"])
			GameState.board_monsters[i] = m
		else:
			GameState.return_monster_instincts_to_hand(m)
			GameState.board_monsters[i] = null
func _create_item_pool() -> Array:
	var pool: Array = [
		_make_item("healing_herb", "Healing Herb", 1, "heal", 3)
	]

	for instinct in GameState.get_instinct_shop_pool():
		pool.append(GameState.instinct_dict_to_item(instinct))

	return pool
func _make_item(id: String, display_name: String, cost: int, effect_type: String, amount: int) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	item.cost = cost
	item.item_kind = "consumable"
	item.effect_type = effect_type
	item.amount = amount
	return item

func _make_instinct_item(
	id: String,
	display_name: String,
	cost: int,
	instinct_type: String,
	instinct_rule: String,
	description: String
) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	item.cost = cost
	item.item_kind = "instinct"
	item.instinct_type = instinct_type
	item.instinct_rule = instinct_rule
	item.description = description
	return item
func _buy_item(i: int) -> void:
	if i < 0 or i >= GameState.shop_items.size():
		return

	var item: ItemData = GameState.shop_items[i]

	if GameState.gold < item.cost:
		add_log("Not enough gold.")
		return

	GameState.gold -= item.cost

	if item.item_kind == "instinct":
		if GameState.hand_cards.size() >= HAND_SIZE:
			add_log("Hand full.")
			return

		GameState.hand_cards.append({
			"card_type": "instinct",
			"item": item
		})
		GameState.shop_items.remove_at(i)
		add_log("Bought %s into hand." % item.display_name)
		print("HAND CARDS AFTER INSTINCT BUY: ", GameState.hand_cards)
		refresh_ui()
		return

	await _apply_item_effect(item)

	GameState.shop_items.remove_at(i)

	add_log("Bought %s." % item.display_name)
	refresh_ui()
	
func _apply_item_effect(item: ItemData) -> void:
	if item.effect_type == "heal":
		for i in range(BOARD_SIZE):
			var m = GameState.board_monsters[i]
			if m == null:
				continue

			var old_health: int = m.health
			m.health = min(m.max_health, m.health + item.amount)

			var healed_amount: int = m.health - old_health
			if healed_amount > 0:
				refresh_ui()
				await get_tree().process_frame

				var card = _get_board_card_node(i)
				_show_floating_heal_over_card(card, healed_amount)

		add_log("Your team healed for up to %d." % item.amount)
		
func _show_floating_heal_over_card(card: Control, amount: int) -> void:
	if card == null:
		return

	var label := Label.new()
	label.text = "+%d" % amount

	label.add_theme_font_size_override("font_size", 32)
	label.modulate = Color(0.2, 1.0, 0.2, 1)

	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)

	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(label)

	var card_center = card.get_global_position() + (card.size / 2.0)
	var local_pos = card_center - global_position
	label.position = local_pos + Vector2(-20, -40)

	var tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -60), 0.6)
	tween.parallel().tween_property(label, "modulate", Color(0.2, 1.0, 0.2, 0), 0.6)

	tween.finished.connect(func():
		label.queue_free()
	)
func _show_floating_xp_over_card(card: Control, amount: int) -> void:
	if card == null:
		return

	var label := Label.new()
	label.text = "+%d XP" % amount

	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color(0.7, 0.4, 1.0, 1)

	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 5)

	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(label)

	var card_center = card.get_global_position() + (card.size / 2.0)
	var local_pos = card_center - global_position
	label.position = local_pos + Vector2(-28, -20)

	var tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -50), 0.55)
	tween.parallel().tween_property(label, "modulate", Color(0.7, 0.4, 1.0, 0), 0.55)

	tween.finished.connect(func():
		label.queue_free()
	)
func _get_board_card_node(slot_index: int) -> Control:
	if slot_index < 0 or slot_index >= board_row.get_child_count():
		return null

	var slot = board_row.get_child(slot_index)
	if slot == null:
		return null

	if slot.get_child_count() == 0:
		return null

	return slot.get_child(0)
	
func _on_instinct_dropped_to_board(source_index: int, slot_index: int, source_type: String) -> void:
	if slot_index < 0 or slot_index >= BOARD_SIZE:
		return

	var target_monster: MonsterData = GameState.board_monsters[slot_index]
	if target_monster == null:
		add_log("Drop instincts onto a creature.")
		return

	var instinct_dict: Dictionary = {}

	# Dragging from hand instinct card
	if source_type == "hand":
		if source_index < 0 or source_index >= GameState.hand_cards.size():
			return

		var entry = GameState.hand_cards[source_index]
		if String(entry.get("card_type", "")) != "instinct":
			return

		var item: ItemData = entry.get("item")
		if item == null:
			return

		instinct_dict = {
	"id": item.id,
	"name": item.display_name,
	"description": item.description,
	"type": item.instinct_type,
	"rule": item.instinct_rule,
	"value": item.instinct_value
}

		var success := GameState.add_instinct_to_monster(target_monster, instinct_dict)
		if not success:
			add_log("%s already has that instinct." % target_monster.display_name)
			return

		GameState.hand_cards.remove_at(source_index)
		add_log("%s attached to %s." % [item.display_name, target_monster.display_name])
		refresh_ui()
		return

	# Moving instinct from one board monster to another
	if source_type == "board_instinct":
		if source_index < 0 or source_index >= BOARD_SIZE:
			return

		var source_monster: MonsterData = GameState.board_monsters[source_index]
		if source_monster == null:
			return

		if source_monster == target_monster:
			return

		if source_monster.instincts.is_empty():
			return

		var inst = source_monster.instincts[0]
		if typeof(inst) != TYPE_DICTIONARY:
			return

		instinct_dict = inst

		if not GameState.can_add_instinct_to_monster(target_monster, instinct_dict):
			add_log("%s already has that instinct." % target_monster.display_name)
			return

		var removed = GameState.remove_instinct_from_monster(source_monster, String(instinct_dict.get("id", "")))
		if removed.is_empty():
			return

		target_monster.instincts.append(removed)
		add_log("%s moved from %s to %s." % [
			String(removed.get("name", "Instinct")),
			source_monster.display_name,
			target_monster.display_name
		])
		refresh_ui()
func _get_current_board_count() -> int:
	var count := 0
	for m in GameState.board_monsters:
		if m != null:
			count += 1
	return count
