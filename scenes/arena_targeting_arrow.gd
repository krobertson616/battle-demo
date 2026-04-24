extends Control

# Polished targeting arrow for arena_scene.
# It replaces the simple Line2D with a curved, layered arrow that feels closer
# to Hearthstone / MTG Arena while keeping the existing targeting logic intact.

const CURVE_STEPS := 32
const OUTER_WIDTH := 20.0
const GLOW_WIDTH := 14.0
const CORE_WIDTH := 6.0
const ARROW_LENGTH := 34.0
const ARROW_WIDTH := 22.0
const SOURCE_RING_RADIUS := 18.0
const TARGET_RING_RADIUS := 24.0

@onready var arena: Control = get_parent() as Control
@onready var player_row: HBoxContainer = arena.get_node("MarginContainer/VBoxContainer/PlayerRow")
@onready var enemy_row: HBoxContainer = arena.get_node("MarginContainer/VBoxContainer/EnemyRow")

var _pulse := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5000
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(true)

func _process(delta: float) -> void:
	_pulse += delta * 4.0
	_hide_old_line()
	queue_redraw()

func _draw() -> void:
	if arena == null or not is_instance_valid(arena):
		return

	if not bool(arena.get("drag_assigning")):
		return

	var start_index := int(arena.get("drag_start_player_index"))
	if start_index < 0:
		return

	var start_pos := _get_player_arrow_start(start_index)
	if start_pos == Vector2.INF:
		return

	var hover_enemy_index := int(arena.get("drag_hover_enemy_index"))
	var has_hover_target := hover_enemy_index >= 0
	var end_pos := _get_enemy_arrow_end(hover_enemy_index) if has_hover_target else _get_mouse_arrow_end()

	if end_pos == Vector2.INF:
		return

	var points := _build_curve_points(start_pos, end_pos)
	if points.size() < 2:
		return

	_draw_arrow_body(points, has_hover_target)
	_draw_arrow_head(points, has_hover_target)
	_draw_source_anchor(start_pos)

	if has_hover_target:
		_draw_target_anchor(end_pos)

func _hide_old_line() -> void:
	if arena == null or not is_instance_valid(arena):
		return

	var old_line = arena.get("drag_line")
	if old_line != null and is_instance_valid(old_line):
		old_line.visible = false

func _get_player_arrow_start(index: int) -> Vector2:
	var card := _get_card_in_row(player_row, index)
	if card == null:
		return Vector2.INF

	var rect := card.get_global_rect()
	var global_pos := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.18)
	return _global_to_local(global_pos)

func _get_enemy_arrow_end(index: int) -> Vector2:
	var card := _get_card_in_row(enemy_row, index)
	if card == null:
		return _get_mouse_arrow_end()

	var rect := card.get_global_rect()
	var global_pos := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.68)
	return _global_to_local(global_pos)

func _get_mouse_arrow_end() -> Vector2:
	var local_from_arena = arena.get("drag_mouse_local")
	if typeof(local_from_arena) == TYPE_VECTOR2:
		return _global_to_local(arena.global_position + local_from_arena)

	return _global_to_local(get_viewport().get_mouse_position())

func _global_to_local(global_pos: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_pos

func _get_card_in_row(row: HBoxContainer, index: int) -> Control:
	if row == null or not is_instance_valid(row):
		return null
	if index < 0 or index >= row.get_child_count():
		return null

	var holder := row.get_child(index) as Control
	if holder == null:
		return null

	for child in holder.get_children():
		if child is Control:
			return child as Control

	return null

func _build_curve_points(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var mid := start_pos.lerp(end_pos, 0.5)
	var vertical_distance := abs(start_pos.y - end_pos.y)
	var curve_lift := clamp(vertical_distance * 0.28 + 70.0, 70.0, 180.0)
	var side_pull := clamp((end_pos.x - start_pos.x) * 0.12, -60.0, 60.0)
	var control := mid + Vector2(side_pull, -curve_lift)

	for i in range(CURVE_STEPS + 1):
		var t := float(i) / float(CURVE_STEPS)
		points.append(_quadratic_bezier(start_pos, control, end_pos, t))

	return points

func _quadratic_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var ab := a.lerp(b, t)
	var bc := b.lerp(c, t)
	return ab.lerp(bc, t)

func _draw_arrow_body(points: PackedVector2Array, has_hover_target: bool) -> void:
	var glow_alpha := 0.64 if has_hover_target else 0.46
	var core_alpha := 1.0 if has_hover_target else 0.86

	# dark readable outline
	draw_polyline(points, Color(0.08, 0.0, 0.0, 0.72), OUTER_WIDTH, true)

	# warm magical body
	draw_polyline(points, Color(1.0, 0.22, 0.08, glow_alpha), GLOW_WIDTH, true)

	# bright inner highlight, with a tiny pulse
	var pulse_width := CORE_WIDTH + sin(_pulse) * 1.1
	draw_polyline(points, Color(1.0, 0.76, 0.28, core_alpha), pulse_width, true)

func _draw_arrow_head(points: PackedVector2Array, has_hover_target: bool) -> void:
	var tip := points[points.size() - 1]
	var prev := points[points.size() - 2]
	var dir := (tip - prev).normalized()
	if dir == Vector2.ZERO:
		return

	var normal := Vector2(-dir.y, dir.x)
	var back := tip - dir * ARROW_LENGTH
	var left := back + normal * ARROW_WIDTH
	var right := back - normal * ARROW_WIDTH

	var outline_left := back + normal * (ARROW_WIDTH + 6.0) - dir * 5.0
	var outline_right := back - normal * (ARROW_WIDTH + 6.0) - dir * 5.0
	var outline_tip := tip + dir * 6.0

	draw_polygon(
		PackedVector2Array([outline_tip, outline_left, outline_right]),
		[Color(0.08, 0.0, 0.0, 0.78)]
	)

	var main_color := Color(1.0, 0.28, 0.08, 0.96) if has_hover_target else Color(0.95, 0.18, 0.08, 0.86)
	draw_polygon(PackedVector2Array([tip, left, right]), [main_color])

	var inner_left := back + normal * (ARROW_WIDTH * 0.38)
	var inner_right := back - normal * (ARROW_WIDTH * 0.38)
	var inner_tip := tip - dir * 5.0
	draw_polygon(
		PackedVector2Array([inner_tip, inner_left, inner_right]),
		[Color(1.0, 0.83, 0.35, 0.9)]
	)

func _draw_source_anchor(pos: Vector2) -> void:
	var pulse_radius := SOURCE_RING_RADIUS + sin(_pulse) * 2.0
	draw_circle(pos, pulse_radius + 5.0, Color(1.0, 0.22, 0.08, 0.12))
	draw_arc(pos, pulse_radius, 0.0, TAU, 36, Color(1.0, 0.66, 0.22, 0.96), 4.0, true)
	draw_circle(pos, 5.5, Color(1.0, 0.82, 0.3, 0.95))

func _draw_target_anchor(pos: Vector2) -> void:
	var pulse_radius := TARGET_RING_RADIUS + sin(_pulse + 1.2) * 3.0
	draw_circle(pos, pulse_radius + 8.0, Color(1.0, 0.12, 0.06, 0.16))
	draw_arc(pos, pulse_radius, 0.0, TAU, 40, Color(1.0, 0.24, 0.08, 0.88), 4.5, true)
	draw_arc(pos, pulse_radius + 7.0, 0.0, TAU, 40, Color(1.0, 0.76, 0.28, 0.42), 2.0, true)
