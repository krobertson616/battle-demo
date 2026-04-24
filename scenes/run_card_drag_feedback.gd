extends Node

# Visual feedback layer for run_scene card dragging.
# Godot's built-in drag preview still handles the actual moving card and drop data.
# This script makes the source card fade/press down while dragging so it feels
# like the card was lifted off the table instead of leaving a full duplicate behind.

const DRAG_START_DISTANCE := 8.0
const SOURCE_DRAG_ALPHA := 0.18
const SOURCE_DRAG_SCALE := Vector2(0.96, 0.96)
const SNAP_RESTORE_TIME := 0.10

@onready var run_scene: Control = get_parent() as Control
@onready var hand_row: HBoxContainer = run_scene.get_node("MarginContainer/VBoxContainer/HandRow")
@onready var board_row: HBoxContainer = run_scene.get_node("MarginContainer/VBoxContainer/BoardRow")

var _pressed := false
var _dragging := false
var _source_card: Control = null
var _source_modulate := Color.WHITE
var _source_scale := Vector2.ONE
var _press_mouse_pos := Vector2.ZERO

func _ready() -> void:
	set_process(true)
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_press(event.position)
		else:
			_end_press()

func _process(_delta: float) -> void:
	if _dragging:
		if _source_card == null or not is_instance_valid(_source_card):
			_reset_state(false)
		return

	if not _pressed:
		return

	if _source_card == null or not is_instance_valid(_source_card):
		_reset_state(false)
		return

	var mouse_pos := get_viewport().get_mouse_position()
	if mouse_pos.distance_to(_press_mouse_pos) >= DRAG_START_DISTANCE:
		_start_source_lift_feedback()

func _begin_press(mouse_pos: Vector2) -> void:
	if _dragging:
		return

	var card := _get_draggable_card_under_point(mouse_pos)
	if card == null:
		return

	_pressed = true
	_dragging = false
	_source_card = card
	_source_modulate = card.modulate
	_source_scale = card.scale
	_press_mouse_pos = mouse_pos

func _start_source_lift_feedback() -> void:
	if _source_card == null or not is_instance_valid(_source_card):
		_reset_state(false)
		return

	_pressed = false
	_dragging = true

	var faded := _source_modulate
	faded.a = SOURCE_DRAG_ALPHA

	var tween := create_tween()
	tween.tween_property(_source_card, "modulate", faded, SNAP_RESTORE_TIME)
	tween.parallel().tween_property(_source_card, "scale", SOURCE_DRAG_SCALE, SNAP_RESTORE_TIME)

func _end_press() -> void:
	if _source_card != null and is_instance_valid(_source_card):
		_restore_source_card()

	_reset_state(false)

func _restore_source_card() -> void:
	if _source_card == null or not is_instance_valid(_source_card):
		return

	var card := _source_card
	var tween := create_tween()
	tween.tween_property(card, "modulate", _source_modulate, SNAP_RESTORE_TIME)
	tween.parallel().tween_property(card, "scale", _source_scale, SNAP_RESTORE_TIME)

func _reset_state(restore_source: bool = true) -> void:
	if restore_source and _source_card != null and is_instance_valid(_source_card):
		_source_card.modulate = _source_modulate
		_source_card.scale = _source_scale

	_pressed = false
	_dragging = false
	_source_card = null
	_source_modulate = Color.WHITE
	_source_scale = Vector2.ONE
	_press_mouse_pos = Vector2.ZERO

func _get_draggable_card_under_point(point: Vector2) -> Control:
	var hand_card := _get_card_under_point_in_row(hand_row, point)
	if hand_card != null:
		return hand_card

	return _get_card_under_point_in_board(point)

func _get_card_under_point_in_row(row: HBoxContainer, point: Vector2) -> Control:
	if row == null or not is_instance_valid(row):
		return null

	for child in row.get_children():
		if child is Control:
			var control := child as Control
			if _is_card_like(control) and control.get_global_rect().has_point(point):
				return control

	return null

func _get_card_under_point_in_board(point: Vector2) -> Control:
	if board_row == null or not is_instance_valid(board_row):
		return null

	for slot in board_row.get_children():
		var card := _find_card_like_child(slot)
		if card != null and card.get_global_rect().has_point(point):
			return card

	return null

func _find_card_like_child(node: Node) -> Control:
	for child in node.get_children():
		if child is Control and _is_card_like(child as Control):
			return child as Control

		var nested := _find_card_like_child(child)
		if nested != null:
			return nested

	return null

func _is_card_like(control: Control) -> bool:
	return control.has_method("_get_drag_data")
