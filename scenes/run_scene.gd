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

@onready var post_boss_panel: PanelContainer = $PostBossPanel
@onready var boss_choice_label: Label = $PostBossPanel/VBoxContainer/BossChoiceLabel
@onready var extract_choices_row: HBoxContainer = $PostBossPanel/VBoxContainer/ExtractChoicesRow
@onready var continue_deeper_button: Button = $PostBossPanel/VBoxContainer/ContinueDeeperButton

@onready var starter_panel: PanelContainer = $StarterPanel
@onready var starter_choices_row: HBoxContainer = $StarterPanel/VBoxContainer/StarterChoicesRow


@onready var event_overlay: CenterContainer = $EventOverlay
@onready var event_panel: PanelContainer = $EventOverlay/EventPanel
@onready var event_background: TextureRect = $EventOverlay/EventBackground
@onready var event_title_label: Label = $EventOverlay/EventPanel/VBoxContainer/EventTitleLabel
@onready var event_body_label: Label = $EventOverlay/EventPanel/VBoxContainer/EventBodyLabel
@onready var event_choices_row: HBoxContainer = $EventOverlay/EventPanel/VBoxContainer/EventChoicesRow
@onready var event_targets_row: HBoxContainer = $EventOverlay/EventPanel/VBoxContainer/EventTargetsRow
@onready var remove_instinct_overlay: CenterContainer = $RemoveInstinctOverlay
@onready var remove_instinct_panel: PanelContainer = $RemoveInstinctOverlay/RemoveInstinctPanel
@onready var remove_instinct_title_label: Label = $RemoveInstinctOverlay/RemoveInstinctPanel/VBoxContainer/RemoveInstinctTitleLabel
@onready var remove_instinct_choices_row: HBoxContainer = $RemoveInstinctOverlay/RemoveInstinctPanel/VBoxContainer/RemoveInstinctChoicesRow
@onready var remove_instinct_cancel_button: Button = $RemoveInstinctOverlay/RemoveInstinctPanel/VBoxContainer/RemoveInstinctCancelButton

var monster_card_scene = preload("res://scenes/monster_card.tscn")
var board_slot_scene = preload("res://scenes/board_slot.tscn")
var instinct_card_scene = preload("res://scenes/instinct_card.tscn")
var extraction_picks_remaining: int = 0
var active_event_id: String = ""
var active_event_mode: String = ""
var pending_remove_instinct_hand_index: int = -1
var pending_remove_instinct_target_slot: int = -1

func _ready() -> void:
	sell_strip.card_sold.connect(_on_card_sold_to_shop)
	continue_deeper_button.pressed.connect(_on_continue_deeper_pressed)
	post_boss_panel.visible = false
	event_overlay.visible = false
	remove_instinct_overlay.visible = false
	remove_instinct_cancel_button.pressed.connect(_close_remove_instinct_overlay)
	
	GameState.sell_strip_ref = sell_strip

	reroll_btn.pressed.connect(_reroll)
	start_btn.pressed.connect(_start_combat)

	_apply_pending_combat_result()

	if GameState.board_monsters.is_empty():
		GameState.board_monsters = [null, null, null, null, null, null]
		
		
	if GameState.shop_monsters.is_empty():
		roll_shop()
		
	refresh_ui()
	_try_show_current_event()
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
		var was_boss := "boss" in cleared_encounter_id

		if cleared_encounter_id == "cave_elite_1":
			GameState.max_board_slots = 4
			add_log("[color=yellow]A new board slot unlocked![/color]")

		GameState.current_encounter_index += 1
		print("Advanced to encounter index: ", GameState.current_encounter_index)

		if was_boss:
			GameState.bosses_cleared_this_run += 1
			GameState.pending_extract_count = GameState.bosses_cleared_this_run
			_show_post_boss_panel()

	else:
		add_log("[color=red]You lose![/color]")
		GameState.health -= 2
		GameState.gold += 2

	GameState.round_num += 1

	if GameState.health <= 0:
		add_log("[b][color=red]Run Over[/color][/b]")
		GameState.end_run_to_map()
		get_tree().change_scene_to_file("res://map_scene.tscn")
		return

	roll_shop()

	GameState.pending_result = {}
	GameState.pending_player_team = []
	GameState.pending_enemy_team = []
func roll_shop() -> void:
	GameState.shop_monsters.clear()
	GameState.shop_items.clear()

	for i in range(4):
		var template: MonsterData = GameState.shop_pool.pick_random()
		GameState.shop_monsters.append(GameState.clone_monster(template))
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
	for i in range(4):
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

			var card = instinct_card_scene.instantiate()
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
	if encounter_id == "":
		print("No more encounters. Run complete.")
		return

	if GameState.is_event_encounter(encounter_id):
		_show_event(encounter_id)
		return
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
func _on_card_sold_to_shop(card_type: String, source_type: String, source_index: int) -> void:
	print("RUN SCENE SELL:", card_type, source_type, source_index)
	if source_index < 0:
		return

	if card_type == "instinct":
		if source_type != "hand":
			return
		if source_index >= GameState.hand_cards.size():
			return

		var entry = GameState.hand_cards[source_index]
		if String(entry.get("card_type", "")) != "instinct":
			return

		GameState.hand_cards.remove_at(source_index)
		add_log("Discarded instinct.")
		refresh_ui()
		return

	if card_type == "monster":
		if source_type == "board":
			_sell(source_index)
			return

		if source_type == "hand":
			if source_index >= GameState.hand_cards.size():
				return

			var entry = GameState.hand_cards[source_index]
			if String(entry.get("card_type", "")) != "monster":
				return

			var m = entry.get("monster")
			GameState.hand_cards.remove_at(source_index)
			GameState.hand_monsters.erase(m)
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
		if item.instinct_rule == "remove_instinct":
			if target_monster.instincts.is_empty():
				add_log("%s has no instincts to remove." % target_monster.display_name)
				return

			_show_remove_instinct_picker(source_index, slot_index)
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

func _show_post_boss_panel() -> void:
	extraction_picks_remaining = max(1, GameState.pending_extract_count)

	for c in extract_choices_row.get_children():
		c.queue_free()

	for i in range(BOARD_SIZE):
		var monster: MonsterData = GameState.board_monsters[i]
		if monster == null:
			continue

		var btn := Button.new()
		btn.text = "%s Lv.%d" % [monster.display_name, monster.level]
		btn.pressed.connect(_on_extract_monster_pressed.bind(i))
		extract_choices_row.add_child(btn)

	var can_go_deeper := true
	continue_deeper_button.disabled = false
	if can_go_deeper:
		boss_choice_label.text = "Boss down. Extract %d monster(s) or continue deeper." % extraction_picks_remaining
	else:
		boss_choice_label.text = "Boss down. Pick %d monster(s) to extract." % extraction_picks_remaining

	continue_deeper_button.disabled = not can_go_deeper
	post_boss_panel.visible = true

	start_btn.disabled = true
	reroll_btn.disabled = true


func _on_extract_monster_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= BOARD_SIZE:
		return

	var monster: MonsterData = GameState.board_monsters[slot_index]
	if monster == null:
		return

	GameState.save_monster_to_roster(monster)
	add_log("[color=yellow]Extracted %s.[/color]" % monster.display_name)

	extraction_picks_remaining -= 1

	if extraction_picks_remaining <= 0:
		_finish_run_after_extraction()
		return

	GameState.board_monsters[slot_index] = null
	refresh_ui()
	_show_post_boss_panel()


func _on_continue_deeper_pressed() -> void:
	post_boss_panel.visible = false
	start_btn.disabled = false
	reroll_btn.disabled = false

	# TEST MODE:
	# If we beat the last encounter, loop back to the beginning
	if GameState.get_current_encounter_id() == "":
		GameState.current_encounter_index = 0
		add_log("[color=yellow]Looping run back to the start for testing.[/color]")
	else:
		add_log("You chose to continue deeper.")

func _finish_run_after_extraction() -> void:
	post_boss_panel.visible = false
	GameState.end_run_to_map()
	get_tree().change_scene_to_file("res://scenes/map_scene.tscn")
	
func _show_starter_panel() -> void:
	for c in starter_choices_row.get_children():
		c.queue_free()

	for i in range(GameState.saved_monsters.size()):
		var monster: MonsterData = GameState.saved_monsters[i]

		var btn := Button.new()
		btn.text = "%s Lv.%d" % [monster.display_name, monster.level]
		btn.pressed.connect(_on_starter_selected.bind(i))
		starter_choices_row.add_child(btn)

	starter_panel.visible = true
	start_btn.disabled = true
	reroll_btn.disabled = true


func _on_starter_selected(index: int) -> void:
	if index < 0 or index >= GameState.saved_monsters.size():
		return

	var chosen: MonsterData = GameState.clone_monster(GameState.saved_monsters[index])

	if GameState.board_monsters.size() < BOARD_SIZE:
		GameState.board_monsters = [null, null, null, null, null, null]

	GameState.board_monsters[0] = chosen

	starter_panel.visible = false
	start_btn.disabled = false
	reroll_btn.disabled = false

	add_log("Starting run with %s." % chosen.display_name)
	refresh_ui()
	
func _try_show_current_event() -> void:
	var encounter_id := GameState.get_current_encounter_id()
	if encounter_id == "":
		return
	if not GameState.is_event_encounter(encounter_id):
		return

	_show_event(encounter_id)


func _show_event(encounter_id: String) -> void:
	active_event_id = encounter_id
	active_event_mode = ""

	_set_event_background(encounter_id)
	event_overlay.visible = true
	start_btn.disabled = true
	reroll_btn.disabled = true

	for c in event_choices_row.get_children():
		c.queue_free()
	for c in event_targets_row.get_children():
		c.queue_free()

	match encounter_id:
		"event_crystal_infusion":
			event_title_label.text = "Crystal Infusion"
			event_body_label.text = "A humming crystal offers power to one of your creatures."

			_add_event_choice_button("Attack +1", func(): _show_event_targets("crystal_attack"))
			_add_event_choice_button("Health +2", func(): _show_event_targets("crystal_health"))
			_add_event_choice_button("XP +1", func(): _show_event_targets("crystal_xp"))

		"event_strange_totem":
			event_title_label.text = "Strange Totem"
			event_body_label.text = "The totem whispers of instinct and sacrifice."

			_add_event_choice_button("Draft 1 of 3", func(): _show_totem_draft())
			_add_event_choice_button("Gain 2 Gold", func():
				GameState.gold += 2
				add_log("The totem grants 2 gold.")
				_finish_event()
			)
			_add_event_choice_button("Random Instinct", func():
				var instinct := GameState.add_random_instinct_reward_to_hand()
				if instinct.is_empty():
					add_log("The totem fizzles.")
				else:
					add_log("You gained %s." % String(instinct.get("name", "Instinct")))
				_finish_event()
			)

		"event_ancient_camp":
			event_title_label.text = "Ancient Camp"
			event_body_label.text = "The camp still holds warmth, tools, and old training notes."

			_add_event_choice_button("Full Heal", func():
				GameState.heal_all_board_monsters_full()
				add_log("Your team rests and recovers.")
				_finish_event()
			)
			_add_event_choice_button("Gain +1 Slot", func(): _show_event_targets("camp_slot"))
			_add_event_choice_button("Gain +2 XP", func(): _show_event_targets("camp_xp"))
		"event_instinct_shop":
			event_title_label.text = "Instinct Broker"
			event_body_label.text = "A hooded trader offers rare instincts for gold."

			_show_event_instinct_shop()

	refresh_ui()

func _add_event_choice_button(text: String, callable_fn: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 90)
	btn.pressed.connect(callable_fn)
	event_choices_row.add_child(btn)


func _show_event_targets(mode: String) -> void:
	active_event_mode = mode

	for c in event_targets_row.get_children():
		c.queue_free()

	var entries := GameState.get_board_monster_entries()
	for entry in entries:
		var slot_index: int = int(entry.get("slot_index", -1))
		var monster: MonsterData = entry.get("monster")
		if monster == null:
			continue

		var btn := Button.new()
		btn.text = "%s Lv.%d" % [monster.display_name, monster.level]
		btn.custom_minimum_size = Vector2(170, 70)
		btn.pressed.connect(func(): _apply_event_target_choice(slot_index))
		event_targets_row.add_child(btn)


func _apply_event_target_choice(slot_index: int) -> void:
	var monster: MonsterData = GameState.board_monsters[slot_index]
	if monster == null:
		return

	match active_event_mode:
		"crystal_attack":
			GameState.grant_board_monster_attack(slot_index, 1)
			add_log("%s gained +1 attack." % monster.display_name)

		"crystal_health":
			GameState.grant_board_monster_health(slot_index, 2)
			add_log("%s gained +2 max health." % monster.display_name)

		"crystal_xp":
			GameState.grant_monster_xp(monster, 1)
			add_log("%s gained 1 XP." % monster.display_name)

		"camp_slot":
			if GameState.grant_board_monster_slot(slot_index, 1):
				add_log("%s gained +1 upgrade slot." % monster.display_name)

		"camp_xp":
			GameState.grant_monster_xp(monster, 2)
			add_log("%s gained 2 XP." % monster.display_name)

	_finish_event()


func _show_totem_draft() -> void:
	for c in event_choices_row.get_children():
		c.queue_free()
	for c in event_targets_row.get_children():
		c.queue_free()

	var picks: Array = GameState.build_instinct_reward_choices(3)

	for instinct in picks:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 110)
		btn.text = "%s\n%s" % [
			String(instinct.get("name", "Instinct")),
			String(instinct.get("description", ""))
		]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(func():
			GameState.add_instinct_reward_to_hand(instinct)
			add_log("You gained %s." % String(instinct.get("name", "Instinct")))
			_finish_event()
		)
		event_choices_row.add_child(btn)


func _finish_event() -> void:
	event_overlay.visible = false
	start_btn.disabled = false
	reroll_btn.disabled = false

	active_event_id = ""
	active_event_mode = ""

	GameState.current_encounter_index += 1
	refresh_ui()
func _set_event_background(encounter_id: String) -> void:
	match encounter_id:
		"event_crystal_infusion":
			event_background.texture = load("res://assets/cave/cave6.png")
		"event_strange_totem":
			event_background.texture = load("res://assets/cave/cave4.png")
		"event_ancient_camp":
			event_background.texture = load("res://assets/cave/cave5.png")
		_:
			event_background.texture = null
func _show_event_instinct_shop() -> void:
	for c in event_choices_row.get_children():
		c.queue_free()
	for c in event_targets_row.get_children():
		c.queue_free()

	var picks: Array = []
	var prune_instinct: Dictionary = GameState.get_instinct_dict_by_id("prune_instinct")
	if not prune_instinct.is_empty():
		picks.append(prune_instinct)

	var random_pool: Array = GameState.get_instinct_shop_pool().duplicate(true)
	random_pool = random_pool.filter(func(inst):
		return String(inst.get("id", "")) != "prune_instinct"
	)
	random_pool.shuffle()

	while picks.size() < 6 and not random_pool.is_empty():
		picks.append(random_pool.pop_back())

	var cost := 2

	for i in range(picks.size()):
		var instinct: Dictionary = picks[i]

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 110)
		btn.text = "%s (%dg)\n%s" % [
			String(instinct.get("name", "Instinct")),
			cost,
			String(instinct.get("description", ""))
		]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(func():
			_buy_event_instinct(instinct, cost, btn)
		)

		if i < 3:
			event_choices_row.add_child(btn)
		else:
			event_targets_row.add_child(btn)

	var leave_btn := Button.new()
	leave_btn.custom_minimum_size = Vector2(180, 70)
	leave_btn.text = "Leave"
	leave_btn.pressed.connect(_finish_event)
	event_targets_row.add_child(leave_btn)
func _buy_event_instinct(instinct: Dictionary, cost: int, btn: Button) -> void:
	if GameState.gold < cost:
		add_log("Not enough gold.")
		return

	if GameState.hand_cards.size() >= HAND_SIZE:
		add_log("Hand full.")
		return

	GameState.gold -= cost
	GameState.add_instinct_reward_to_hand(instinct)
	add_log("Bought %s." % String(instinct.get("name", "Instinct")))

	btn.disabled = true
	refresh_ui()
func _show_remove_instinct_picker(hand_index: int, slot_index: int) -> void:
	pending_remove_instinct_hand_index = hand_index
	pending_remove_instinct_target_slot = slot_index

	remove_instinct_overlay.visible = true
	start_btn.disabled = true
	reroll_btn.disabled = true

	for c in remove_instinct_choices_row.get_children():
		c.queue_free()

	var monster: MonsterData = GameState.board_monsters[slot_index]
	if monster == null:
		_close_remove_instinct_overlay()
		return

	remove_instinct_title_label.text = "Remove an instinct from %s" % monster.display_name

	for inst in monster.instincts:
		if typeof(inst) != TYPE_DICTIONARY:
			continue

		var inst_dict: Dictionary = inst
		var instinct_id: String = String(inst_dict.get("id", ""))
		var instinct_name: String = String(inst_dict.get("name", "Instinct"))
		var instinct_desc: String = String(inst_dict.get("description", ""))

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 100)
		btn.text = "%s\n%s" % [instinct_name, instinct_desc]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(func(): _apply_remove_instinct_choice(instinct_id))
		remove_instinct_choices_row.add_child(btn)


func _apply_remove_instinct_choice(instinct_id: String) -> void:
	if pending_remove_instinct_target_slot < 0 or pending_remove_instinct_target_slot >= BOARD_SIZE:
		_close_remove_instinct_overlay()
		return

	if pending_remove_instinct_hand_index < 0 or pending_remove_instinct_hand_index >= GameState.hand_cards.size():
		_close_remove_instinct_overlay()
		return

	var monster: MonsterData = GameState.board_monsters[pending_remove_instinct_target_slot]
	if monster == null:
		_close_remove_instinct_overlay()
		return

	var removed: Dictionary = GameState.remove_instinct_from_monster(monster, instinct_id)
	if removed.is_empty():
		_close_remove_instinct_overlay()
		return

	GameState.hand_cards.remove_at(pending_remove_instinct_hand_index)

	add_log("%s was destroyed on %s." % [
		String(removed.get("name", "Instinct")),
		monster.display_name
	])

	_close_remove_instinct_overlay()
	refresh_ui()


func _close_remove_instinct_overlay() -> void:
	remove_instinct_overlay.visible = false
	start_btn.disabled = false
	reroll_btn.disabled = false
	pending_remove_instinct_hand_index = -1
	pending_remove_instinct_target_slot = -1

	for c in remove_instinct_choices_row.get_children():
		c.queue_free()
