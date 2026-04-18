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
	GameState.select_map_location(location_id)
	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")
