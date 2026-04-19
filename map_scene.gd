extends Control

@onready var title_label: Label = $MainVBox/TitleLabel
@onready var roster_label: Label = $MainVBox/RosterLabel
@onready var roster_row: HBoxContainer = $MainVBox/RosterRow
@onready var team_label: Label = $MainVBox/TeamLabel
@onready var team_row: HBoxContainer = $MainVBox/TeamRow

@onready var cave_button: Button = $MainVBox/ZoneButtons/CaveButton
@onready var forest_button: Button = $MainVBox/ZoneButtons/ForestButton
@onready var crypt_button: Button = $MainVBox/ZoneButtons/CryptButton
var monster_card_scene = preload("res://scenes/monster_card.tscn")

func _ready() -> void:
	title_label.text = "Choose Your Expedition"
	cave_button.text = "Cave (Lv 1+)"
	forest_button.text = "Forest (Lv 10+)"
	crypt_button.text = "Crypt (Lv 20+)"

	cave_button.pressed.connect(_on_zone_pressed.bind("cave", 1))
	forest_button.pressed.connect(_on_zone_pressed.bind("forest", 10))
	crypt_button.pressed.connect(_on_zone_pressed.bind("crypt", 20))

	_refresh_meta_ui()

func _make_monster_card_entry(monster: MonsterData, button_text: String, pressed_callback: Callable, setup_index: int) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(160, 240)

	var card = monster_card_scene.instantiate()
	card.custom_minimum_size = Vector2(150, 180)

	# Use "map" first. If your monster_card script only supports known locations,
	# change "map" to "board" in both helper functions.
	card.setup(monster, "map", setup_index)

	# Prevent drag/drop behavior on the map screen
	if card is BaseButton:
		card.disabled = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	wrapper.add_child(card)

	var action_button := Button.new()
	action_button.text = button_text
	action_button.custom_minimum_size = Vector2(150, 36)
	action_button.pressed.connect(pressed_callback)
	wrapper.add_child(action_button)

	return wrapper


func _make_disabled_monster_card_entry(monster: MonsterData, label_text: String, setup_index: int) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(160, 240)

	var card = monster_card_scene.instantiate()
	card.custom_minimum_size = Vector2(150, 180)
	card.setup(monster, "map", setup_index)

	if card is BaseButton:
		card.disabled = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	wrapper.add_child(card)

	var info_label := Label.new()
	info_label.text = label_text
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrapper.add_child(info_label)

	return wrapper
func _refresh_meta_ui() -> void:
	roster_label.text = "Saved Monsters"
	team_label.text = "Expedition Team (%d / 3)   Total Level: %d" % [
		GameState.selected_roster_indexes.size(),
		GameState.get_selected_team_total_level()
	]

	for c in roster_row.get_children():
		c.queue_free()

	for c in team_row.get_children():
		c.queue_free()

	for i in range(GameState.saved_monsters.size()):
		var monster: MonsterData = GameState.saved_monsters[i]

		if i in GameState.selected_roster_indexes:
			var entry = _make_disabled_monster_card_entry(monster, "In Team", i)
			roster_row.add_child(entry)
		else:
			var entry = _make_monster_card_entry(
				monster,
				"Add to Team",
				_on_add_monster_to_team.bind(i),
				i
			)
			roster_row.add_child(entry)

	for index in GameState.selected_roster_indexes:
		if index < 0 or index >= GameState.saved_monsters.size():
			continue

		var monster: MonsterData = GameState.saved_monsters[index]

		var entry = _make_monster_card_entry(
			monster,
			"Remove",
			_on_remove_monster_from_team.bind(index),
			index
		)
		team_row.add_child(entry)

func _on_add_monster_to_team(index: int) -> void:
	GameState.add_roster_monster_to_team(index)
	_refresh_meta_ui()


func _on_remove_monster_from_team(index: int) -> void:
	GameState.remove_roster_monster_from_team(index)
	_refresh_meta_ui()


func _on_zone_pressed(location_id: String, required_total_level: int) -> void:
	# First-run test: allow Cave even with no saved monsters yet
	if GameState.saved_monsters.is_empty():
		if location_id != "cave":
			title_label.text = "Beat Cave and extract a monster first."
			return

		GameState.clear_selected_team()
		GameState.start_new_run_from_map("cave")
		get_tree().change_scene_to_file("res://scenes/run_scene.tscn")
		return

	# Normal flow once you have extracted monsters
	if GameState.selected_roster_indexes.is_empty():
		title_label.text = "Pick at least one monster."
		return

	if GameState.get_selected_team_total_level() < required_total_level:
		title_label.text = "Need team total level %d." % required_total_level
		return

	GameState.start_new_run_from_map(location_id)
	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")
