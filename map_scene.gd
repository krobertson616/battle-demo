extends Control

@onready var title_label: Label = $MainVBox/TitleLabel
@onready var roster_label: Label = $MainVBox/RosterLabel
@onready var roster_row: HBoxContainer = $MainVBox/RosterRow
@onready var team_label: Label = $MainVBox/TeamLabel
@onready var team_row: HBoxContainer = $MainVBox/TeamRow

@onready var cave_button: Button = $MainVBox/ZoneButtons/CaveButton
@onready var forest_button: Button = $MainVBox/ZoneButtons/ForestButton
@onready var crypt_button: Button = $MainVBox/ZoneButtons/CryptButton

func _ready() -> void:
	title_label.text = "Choose Your Expedition"
	cave_button.text = "Cave (Lv 1+)"
	forest_button.text = "Forest (Lv 10+)"
	crypt_button.text = "Crypt (Lv 20+)"

	cave_button.pressed.connect(_on_zone_pressed.bind("cave", 1))
	forest_button.pressed.connect(_on_zone_pressed.bind("forest", 10))
	crypt_button.pressed.connect(_on_zone_pressed.bind("crypt", 20))

	_refresh_meta_ui()


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

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 180)
		btn.text = "%s\nLv.%d" % [monster.display_name, monster.level]

		if i in GameState.selected_roster_indexes:
			btn.text += "\n[In Team]"
			btn.disabled = true
		else:
			btn.pressed.connect(_on_add_monster_to_team.bind(i))

		roster_row.add_child(btn)

	for index in GameState.selected_roster_indexes:
		if index < 0 or index >= GameState.saved_monsters.size():
			continue

		var monster: MonsterData = GameState.saved_monsters[index]

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 180)
		btn.text = "%s\nLv.%d\n[Remove]" % [monster.display_name, monster.level]
		btn.pressed.connect(_on_remove_monster_from_team.bind(index))
		team_row.add_child(btn)


func _on_add_monster_to_team(index: int) -> void:
	GameState.add_roster_monster_to_team(index)
	_refresh_meta_ui()


func _on_remove_monster_from_team(index: int) -> void:
	GameState.remove_roster_monster_from_team(index)
	_refresh_meta_ui()


func _on_zone_pressed(location_id: String, required_total_level: int) -> void:
	if GameState.selected_roster_indexes.is_empty():
		title_label.text = "Pick at least one monster."
		return

	if GameState.get_selected_team_total_level() < required_total_level:
		title_label.text = "Need team total level %d." % required_total_level
		return

	GameState.start_new_run_from_map(location_id)
	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")
