extends Control

const STARTER_OFFER_COUNT := 4
const EXTRA_STARTER_IDS: Array[String] = [
	"razor_mite" # Rosssie
]

@onready var title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var help_label: Label = $CenterContainer/PanelContainer/VBoxContainer/HelpLabel
@onready var offer_grid: GridContainer = $CenterContainer/PanelContainer/VBoxContainer/OfferGrid
@onready var start_button: Button = $CenterContainer/PanelContainer/VBoxContainer/StartButton

var monster_card_scene = preload("res://scenes/monster_card.tscn")
var starter_offer: Array[MonsterData] = []

func _ready() -> void:
	title_label.text = "Choose 3 Monsters"
	help_label.text = "Click 3 monsters to build your starting team."

	GameState.clear_starter_team()
	starter_offer = _build_random_unique_starter_offer(_build_starter_offer_pool(), STARTER_OFFER_COUNT)

	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	_render_offer()
	offer_grid.add_theme_constant_override("h_separation", 28)
	offer_grid.add_theme_constant_override("v_separation", 28)

func _build_starter_offer_pool() -> Array[MonsterData]:
	var offer_pool: Array[MonsterData] = GameState.build_starter_offer()

	for monster_id in EXTRA_STARTER_IDS:
		var monster: MonsterData = GameState.get_monster_by_id(monster_id)
		if monster != null:
			offer_pool.append(monster)

	return offer_pool

func _build_random_unique_starter_offer(offer_pool: Array[MonsterData], offer_count: int) -> Array[MonsterData]:
	var unique_offer: Array[MonsterData] = []
	var seen_ids := {}

	for monster in offer_pool:
		if monster == null:
			continue

		var id := _monster_id(monster)
		if id == "" or seen_ids.has(id):
			continue

		seen_ids[id] = true
		unique_offer.append(monster)

	unique_offer.shuffle()

	var picked_offer: Array[MonsterData] = []
	for i in range(min(offer_count, unique_offer.size())):
		picked_offer.append(unique_offer[i])

	return picked_offer

func _render_offer() -> void:
	for child in offer_grid.get_children():
		child.queue_free()

	for i in range(starter_offer.size()):
		var monster: MonsterData = starter_offer[i]
		var selected := _is_selected(monster)

		var card = monster_card_scene.instantiate()
		card.custom_minimum_size = Vector2(170, 260)
		card.setup(monster, "starter", i)
		card.pressed.connect(_on_card_pressed.bind(i))

		if card.has_method("set_selected"):
			card.set_selected(selected)

		offer_grid.add_child(card)

	_update_help_and_button()

func _on_card_pressed(index: int) -> void:
	if index < 0 or index >= starter_offer.size():
		return

	var clicked: MonsterData = starter_offer[index]
	var clicked_id := _monster_id(clicked)

	var existing_index := _selected_index_by_id(clicked_id)
	if existing_index >= 0:
		GameState.selected_starter_team.remove_at(existing_index)
	else:
		if GameState.selected_starter_team.size() >= 3:
			return
		GameState.selected_starter_team.append(GameState.clone_monster(clicked))

	_render_offer()


func _update_help_and_button() -> void:
	var count := GameState.selected_starter_team.size()
	help_label.text = "Selected %d / 3" % count
	start_button.disabled = count != 3


func _is_selected(monster: MonsterData) -> bool:
	return _selected_index_by_id(_monster_id(monster)) >= 0


func _selected_index_by_id(id: String) -> int:
	for i in range(GameState.selected_starter_team.size()):
		if _monster_id(GameState.selected_starter_team[i]) == id:
			return i
	return -1


func _monster_id(monster: MonsterData) -> String:
	var value = monster.get("id")
	if value == null:
		return ""
	return str(value)


func _on_start_pressed() -> void:
	if GameState.selected_starter_team.size() != 3:
		return

	GameState.begin_cave_run_with_starters(GameState.selected_starter_team)
	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")
