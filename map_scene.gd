extends Control

@onready var title_label: Label = $TitleLabel
@onready var cave_button: Button = $CaveButton
@onready var forest_button: Button = $ForestButton
@onready var crypt_button: Button = $CryptButton

func _ready() -> void:
	title_label.text = "Choose Your Destination"

	cave_button.pressed.connect(_on_location_pressed.bind("cave"))
	forest_button.pressed.connect(_on_location_pressed.bind("forest"))
	crypt_button.pressed.connect(_on_location_pressed.bind("crypt"))

func _on_location_pressed(location_id: String) -> void:
	var player_team := GameState.build_player_team_from_board()
	if player_team.is_empty():
		get_tree().change_scene_to_file("res://scenes/run_scene.tscn")
		return

	GameState.select_map_location(location_id)
	GameState.pending_player_team = player_team
	GameState.pending_enemy_team = GameState.build_enemy_team_for_current_node()
	get_tree().change_scene_to_file("res://scenes/arena_scene.tscn")
