extends Node

# Demo tuning layer used while we are playtesting the first real slice.
# Keeps the run short/intentionally ordered and scales active run cards to a
# larger combat number range without rewriting every monster/enemy definition yet.

const COMBAT_SCALE: int = 3
const DEMO_RUN_ENCOUNTERS: Array[String] = [
	"cave_1",
	"cave_2",
	"event_crystal_infusion",
	"cave_3",
	"event_instinct_shop",
	"cave_elite_1",
	"event_ancient_camp",
	"cave_boss_1"
]

func _ready() -> void:
	call_deferred("_apply_demo_tuning")
	set_process(true)

func _process(_delta: float) -> void:
	_apply_demo_tuning()

func _apply_demo_tuning() -> void:
	if not is_instance_valid(GameState):
		return

	_force_demo_encounter_order()
	_scale_live_run_cards()
	_scale_live_items()

func _force_demo_encounter_order() -> void:
	if _encounter_order_matches():
		return

	var old_encounter_id := ""
	if GameState.has_method("get_current_encounter_id"):
		old_encounter_id = GameState.get_current_encounter_id()

	GameState.run_encounters = DEMO_RUN_ENCOUNTERS.duplicate()

	var preserved_index := DEMO_RUN_ENCOUNTERS.find(old_encounter_id)
	if preserved_index >= 0:
		GameState.current_encounter_index = preserved_index
	else:
		GameState.current_encounter_index = clampi(
			int(GameState.current_encounter_index),
			0,
			max(0, DEMO_RUN_ENCOUNTERS.size() - 1)
		)

func _encounter_order_matches() -> bool:
	if GameState.run_encounters.size() != DEMO_RUN_ENCOUNTERS.size():
		return false

	for i in range(DEMO_RUN_ENCOUNTERS.size()):
		if String(GameState.run_encounters[i]) != DEMO_RUN_ENCOUNTERS[i]:
			return false

	return true

func _scale_live_run_cards() -> void:
	_scale_monster_array(GameState.selected_starter_team)
	_scale_monster_array(GameState.board_monsters)
	_scale_monster_array(GameState.hand_monsters)
	_scale_monster_array(GameState.shop_monsters)
	_scale_hand_card_monsters(GameState.hand_cards)

func _scale_monster_array(monsters: Array) -> void:
	for monster in monsters:
		_scale_monster(monster)

func _scale_hand_card_monsters(cards: Array) -> void:
	for entry in cards:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if String(entry.get("card_type", "")) == "monster":
			_scale_monster(entry.get("monster"))

func _scale_monster(monster) -> void:
	if monster == null:
		return
	if not (monster is MonsterData):
		return
	if monster.has_meta("demo_combat_scaled"):
		return

	var old_max_health: int = max(1, int(monster.max_health))
	var health_ratio: float = clampf(float(monster.health) / float(old_max_health), 0.0, 1.0)

	monster.attack = max(0, int(monster.attack) * COMBAT_SCALE)
	monster.max_health = max(1, int(monster.max_health) * COMBAT_SCALE)
	monster.health = clampi(int(round(float(monster.max_health) * health_ratio)), 1, int(monster.max_health))
	monster.set_meta("demo_combat_scaled", true)

func _scale_live_items() -> void:
	_scale_item_array(GameState.shop_items)

	for entry in GameState.hand_cards:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if String(entry.get("card_type", "")) == "instinct":
			_scale_item(entry.get("item"))

func _scale_item_array(items: Array) -> void:
	for item in items:
		_scale_item(item)

func _scale_item(item) -> void:
	if item == null:
		return
	if not (item is ItemData):
		return
	if item.has_meta("demo_combat_scaled"):
		return

	# Scale fixed item/instinct numbers so bonus damage/heal values still matter
	# in the larger health/damage range.
	if int(item.amount) > 0:
		item.amount = int(item.amount) * COMBAT_SCALE
	if int(item.instinct_value) > 0:
		item.instinct_value = int(item.instinct_value) * COMBAT_SCALE

	item.set_meta("demo_combat_scaled", true)
