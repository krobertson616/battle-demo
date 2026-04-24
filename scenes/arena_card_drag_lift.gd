extends Node

# Visual drag/lift layer for arena cards.
# The existing ArenaScene targeting logic still decides what happens on drop.
# This script makes the player card feel like it leaves the table while dragging.

const DRAG_START_DISTANCE := 8.0
const LIFT_SCALE := Vector2(1.08, 1.08)
const LIFT_ALPHA := 0.22
const SNAP_BACK_TIME := 0.14
const DROP_FADE_TIME := 0.10
const MAX_TILT_DEGREES := 7.0

@onready var arena: Control = get_parent() as Control
@onready var player_row: HBoxContainer = arena.get_node("MarginContainer/VBoxContainer/PlayerRow")
@onready var enemy_row: HBoxContainer = arena.get_node("MarginContainer/VBoxContainer/EnemyRow")

var _pressed := false
var _dragging := false
var _source_card: Control = null
var _source_modulate := Color.WHITE
var _press_mouse_pos := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _lifted_card: Control = null
var _last_mouse_pos := Vector2.ZERO

func _ready() -> void:
	set_process(true)
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_press(event.position)
		else:
			_end_press(event.position)
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.position)

func _process(_delta: float) -> void:
	if _dragging:
		_update_lifted_card(get_viewport().get_mouse_position())
		return

	if not _pressed or _source_card == null or not is_instance_valid(_source_card):
		return

	var mouse_pos := get_viewport().get_mouse_position()
	if mouse_pos.distance_to(_press_mouse_pos) >= DRAG_START_DISTANCE:
		_start_lift(mouse_pos)

func _begin_press(mouse_pos: Vector2) -> void:
	if _dragging:
		return

	var card := _get_player_card_under_point(mouse_pos)
	if card == null:
		return

	_pressed = true
	_source_card = card
	_source_modulate = card.modulate
	_press_mouse_pos = mouse_pos
	_last_mouse_pos = mouse_pos
	_grab_offset = mouse_pos - card.get_global_rect().position

func _handle_mouse_motion(mouse_pos: Vector2) -> void:
	if _dragging:
		_update_lifted_card(mouse_pos)
		_last_mouse_pos = mouse_pos

func _start_lift(mouse_pos: Vector2) -> void:
	if _source_card == null or not is_instance_valid(_source_card):
		_reset_drag_state()
		return

	_pressed = false
	_dragging = true

	_source_modulate = _source_card.modulate
	var faded := _source_modulate
	faded.a = LIFT_ALPHA
	_source_card.modulate = faded

	_lifted_card = _source_card.duplicate() as Control
	if _lifted_card == null:
		_reset_drag_state()
		return

	_lifted_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lifted_card.focus_mode = Control.FOCUS_NONE
	_set_children_mouse_ignore(_lifted_card)
	_lifted_card.top_level = true
	_lifted_card.z_index = 5000
	_lifted_card.pivot_offset = _source_card.size / 2.0
	_lifted_card.scale = LIFT_SCALE
	_lifted_card.modulate = Color(1, 1, 1, 0.96)
	_lifted_card.rotation_degrees = 0.0

	arena.add_child(_lifted_card)
	_update_lifted_card(mouse_pos)

func _update_lifted_card(mouse_pos: Vector2) -> void:
	if _lifted_card == null or not is_instance_valid(_lifted_card):
		return

	_lifted_card.global_position = mouse_pos - _grab_offset

	var x_speed := mouse_pos.x - _last_mouse_pos.x
	_lifted_card.rotation_degrees = clamp(x_speed * 0.22, -MAX_TILT_DEGREES, MAX_TILT_DEGREES)
	_lifted_card.scale = LIFT_SCALE

func _end_press(mouse_pos: Vector2) -> void:
	if not _pressed and not _dragging:
		return

	if _dragging:
		_finish_lift(mouse_pos)
	else:
		_reset_drag_state()

func _finish_lift(mouse_pos: Vector2) -> void:
	var released_on_enemy := _get_enemy_card_under_point(mouse_pos) != null

	if released_on_enemy:
		_fade_out_lifted_card()
		_restore_source_card()
		_reset_drag_state(false)
	else:
		_snap_lifted_card_back()

func _snap_lifted_card_back() -> void:
	if _lifted_card == null or not is_instance_valid(_lifted_card):
		_restore_source_card()
		_reset_drag_state(false)
		return

	if _source_card == null or not is_instance_valid(_source_card):
		_fade_out_lifted_card()
		_reset_drag_state(false)
		return

	var card_to_free := _lifted_card
	var target_pos := _source_card.get_global_rect().position
	_lifted_card = null

	var tween := create_tween()
	tween.tween_property(card_to_free, "global_position", target_pos, SNAP_BACK_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_to_free, "scale", Vector2.ONE, SNAP_BACK_TIME)
	tween.parallel().tween_property(card_to_free, "rotation_degrees", 0.0, SNAP_BACK_TIME)
	tween.finished.connect(func():
		if is_instance_valid(card_to_free):
			card_to_free.queue_free()
		_restore_source_card()
		_reset_drag_state(false)
	)

func _fade_out_lifted_card() -> void:
	if _lifted_card == null or not is_instance_valid(_lifted_card):
		return

	var card_to_free := _lifted_card
	_lifted_card = null

	var tween := create_tween()
	tween.tween_property(card_to_free, "modulate", Color(1, 1, 1, 0.0), DROP_FADE_TIME)
	tween.parallel().tween_property(card_to_free, "scale", Vector2(1.14, 1.14), DROP_FADE_TIME)
	tween.finished.connect(func():
		if is_instance_valid(card_to_free):
			card_to_free.queue_free()
	)

func _restore_source_card() -> void:
	if _source_card != null and is_instance_valid(_source_card):
		_source_card.modulate = _source_modulate

func _reset_drag_state(restore_source: bool = true) -> void:
	if restore_source:
		_restore_source_card()

	_pressed = false
	_dragging = false
	_source_card = null
	_press_mouse_pos = Vector2.ZERO
	_grab_offset = Vector2.ZERO
	_last_mouse_pos = Vector2.ZERO

func _get_player_card_under_point(point: Vector2) -> Control:
	return _get_card_under_point_in_row(player_row, point)

func _get_enemy_card_under_point(point: Vector2) -> Control:
	return _get_card_under_point_in_row(enemy_row, point)

func _get_card_under_point_in_row(row: HBoxContainer, point: Vector2) -> Control:
	if row == null or not is_instance_valid(row):
		return null

	for i in range(row.get_child_count()):
		var holder := row.get_child(i) as Control
		if holder == null:
			continue

		var card := _get_first_card_child(holder)
		if card != null and card.get_global_rect().has_point(point):
			return card

	return null

func _get_first_card_child(holder: Control) -> Control:
	for child in holder.get_children():
		if child is Control and child.name == "MonsterCard":
			return child as Control

	if holder.get_child_count() > 0 and holder.get_child(0) is Control:
		return holder.get_child(0) as Control

	return null

func _set_children_mouse_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			control.focus_mode = Control.FOCUS_NONE
		_set_children_mouse_ignore(child)
