extends Control

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var help_label: Label = $CenterContainer/VBoxContainer/HelpLabel
@onready var offer_grid: GridContainer = $CenterContainer/VBoxContainer/OfferGrid
@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton

var monster_card_scene = preload("res://scenes/monster_card.tscn")
var starter_offer: Array[MonsterData] = []

func _ready() -> void:
	title_label.text = "Choose 3 Monsters"
	help_label.text = "Click 3 monsters to build your starting team."

	GameState.clear_starter_team()
	starter_offer = GameState.build_starter_offer()

	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)

	_render_offer()


func _render_offer() -> void:
	for child in offer_grid.get_children():
		child.queue_free()

	for i in range(starter_offer.size()):
		var monster: MonsterData = starter_offer[i]
		var selected := _is_selected(monster)

		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(190, 280)
		frame.add_theme_stylebox_override("panel", _make_frame_style(selected))

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		frame.add_child(margin)

		var card = monster_card_scene.instantiate()
		card.custom_minimum_size = Vector2(170, 260)
		card.setup(monster, "starter", i)
		card.pressed.connect(_on_card_pressed.bind(i))

		if selected:
			card.modulate = Color(0.90, 0.94, 1.0, 1.0)
		else:
			card.modulate = Color(1, 1, 1, 1)

		margin.add_child(card)
		offer_grid.add_child(frame)

	_update_help_and_button()


func _make_frame_style(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.set_border_width_all(4)

	if selected:
		sb.bg_color = Color(0.73, 0.80, 0.90, 0.30)   # light grey-blue
		sb.border_color = Color(0.74, 0.82, 0.95, 1.0)
	else:
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color(0.25, 0.25, 0.25, 0.45)

	return sb


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
