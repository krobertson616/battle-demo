extends Control

@onready var play_button = $PlayButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/starter_select.tscn")
