extends Control

# Polished targeting arrow for arena_scene.
# It replaces the simple Line2D with a curved, layered arrow that feels closer
# to Hearthstone / MTG Arena while keeping the existing targeting logic intact.

const CURVE_STEPS: int = 32
const OUTER_WIDTH: float = 20.0
const GLOW_WIDTH: float = 14.0
const CORE_WIDTH: float = 6.0
const ARROW_LENGTH: float = 34.0
const ARROW_WIDTH: float = 22.0
const SOURCE_RING_RADIUS: float = 18.0
const TARGET_RING_RADIUS: float = 36.0
const QUEUED_LINE_OUTER_WIDTH: float = 5.0
const QUEUED_LINE_INNER_WIDTH: float = 2.2

@onready var arena: Control = get_parent() as Control
@onready var player_row: HBoxContainer = arena.get_node("MarginContainer/VBoxContainer/PlayerRow")
@onready var enemy_row: HBoxContainer = arena.get_node("MarginContainer/VBoxContainer/EnemyRow")

var _pulse: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 9000
	z_as_relative = false
	top_level = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sync_to_viewport()
	set_process(true)

func _process(delta: float) -> void:
	_pulse += delta * 4.0
	_sync_to_viewport()
	_hide_and_clear_old_line()

	var is_dragging: bool = arena != null and is_instance_valid(arena) and bool(arena.get("drag_assigning"))
	var should_show_queued_lines: bool = arena != null and is_instance_valid(arena) and bool(arena.get("battle_paused")) and _has_queued_enemy_targets()
	visible = is_dragging or should_show_queued_lines

	queue_redraw()

func _draw() -> void:
	if arena == null or not is_instance_valid(arena):
		return

	if bool(arena.get("battle_paused")):
		_draw_queued_target_lines()

	if not bool(arena.get("drag_assigning")):
		return

	var start_index: int = int(arena.get("drag_start_player_index"))
	if start_index < 0:
		return

	var start_pos: Vector2 = _get_player_arrow_start(start_index)
	if start_pos == Vector2.INF:
		start_pos = _get_mouse_arrow_end()

	var hover_enemy_index: int = int(arena.get("drag_hover_enemy_index"))
	if hover_enemy_index < 0:
		hover_enemy_index = _get_hovered_enemy_index()

	var has_hover_target: bool = hover_enemy_index >= 0
	var end_pos: Vector2 = _get_enemy_arrow_end(hover_enemy_index) if has_hover_target else _get_mouse_arrow_end()

	if end_pos == Vector2.INF or start_pos == Vector2.INF:
		return

	var points: PackedVector2Array = _build_curve_points(start_pos, end_pos)
	if points.size() < 2:
		return

	# Draw the lock-on marker first so the arrow appears above it, but make it big
	# enough that it remains visible around the arrowhead.
	if has_hover_target:
		_draw_target_anchor(end_pos)

	_draw_arrow_body(points, has_hover_target)
	_draw_arrow_head(points, has_hover_target)
	_draw_source_anchor(start_pos)

func _sync_to_viewport() -> void:
	var viewport_rect: Rect2 = get_viewport_rect()
	global_position = viewport_rect.position
	size = viewport_rect.size
	custom_minimum_size = viewport_rect.size

func _hide_and_clear_old_line() -> void:
	if arena == null or not is_instance_valid(arena):
		return

	var old_line = arena.get("drag_line")
	if old_line != null and is_instance_valid(old_line):
		old_line.visible = false
		if old_line.has_method("clear_points"):
			old_line.clear_points()

	var old_layer = arena.get("line_layer")
	if old_layer != null and is_instance_valid(old_layer):
		old_layer.visible = false

func _get_player_arrow_start(index: int) -> Vector2:
	var card: Control = _get_card_in_row(player_row, index)
	if card == null:
		return Vector2.INF

	var rect: Rect2 = card.get_global_rect()
	var global_pos: Vector2 = rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.18)
	return _global_to_local(global_pos)

func _get_enemy_arrow_end(index: int) -> Vector2:
	var card: Control = _get_card_in_row(enemy_row, index)
	if card == null:
		return _get_mouse_arrow_end()

	var rect: Rect2 = card.get_global_rect()
	var global_pos: Vector2 = rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5)
	return _global_to_local(global_pos)

func _get_mouse_arrow_end() -> Vector2:
	var local_from_arena = arena.get("drag_mouse_local")
	if typeof(local_from_arena) == TYPE_VECTOR2:
		return _global_to_local(arena.global_position + local_from_arena)

	return _global_to_local(get_viewport().get_mouse_position())

func _get_mouse_global_pos() -> Vector2:
	var local_from_arena = arena.get("drag_mouse_local")
	if typeof(local_from_arena) == TYPE_VECTOR2:
		return arena.global_position + local_from_arena

	return get_viewport().get_mouse_position()

func _global_to_local(global_pos: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_pos

func _get_card_in_row(row: HBoxContainer, index: int) -> Control:
	if row == null or not is_instance_valid(row):
		return null
	if index < 0 or index >= row.get_child_count():
		return null

	var holder: Control = row.get_child(index) as Control
	if holder == null:
		return null

	for child in holder.get_children():
		if child is Control:
			return child as Control

	return null

func _get_hovered_enemy_index() -> int:
	if enemy_row == null or not is_instance_valid(enemy_row):
		return -1

	var mouse_global: Vector2 = _get_mouse_global_pos()
	for i in range(enemy_row.get_child_count()):
		var card: Control = _get_card_in_row(enemy_row, i)
		if card == null:
			continue

		if card.get_global_rect().grow(12.0).has_point(mouse_global):
			return i

	return -1

func _build_curve_points(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var delta: Vector2 = end_pos - start_pos
	var distance: float = maxf(delta.length(), 1.0)
	var mid: Vector2 = start_pos.lerp(end_pos, 0.5)
	var normal: Vector2 = Vector2(-delta.y, delta.x).normalized()
	var bend_sign: float = 1.0 if end_pos.x >= start_pos.x else -1.0
	var bend_amount: float = clampf(distance * 0.13, 28.0, 88.0)
	var control: Vector2 = mid + normal * bend_amount * bend_sign

	for i in range(CURVE_STEPS + 1):
		var t: float = float(i) / float(CURVE_STEPS)
		points.append(_quadratic_bezier(start_pos, control, end_pos, t))

	return points

func _quadratic_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var ab: Vector2 = a.lerp(b, t)
	var bc: Vector2 = b.lerp(c, t)
	return ab.lerp(bc, t)

func _draw_arrow_body(points: PackedVector2Array, has_hover_target: bool) -> void:
	var glow_alpha: float = 0.72 if has_hover_target else 0.56
	var core_alpha: float = 1.0 if has_hover_target else 0.92
	var body_points: PackedVector2Array = _trim_curve_tail(points, ARROW_LENGTH * 0.45)

	# Dark readable outline.
	draw_polyline(body_points, Color(0.08, 0.0, 0.0, 0.82), OUTER_WIDTH, true)

	# Warm magical body.
	draw_polyline(body_points, Color(1.0, 0.22, 0.08, glow_alpha), GLOW_WIDTH, true)

	# Bright inner highlight, with a tiny pulse.
	var pulse_width: float = CORE_WIDTH + sin(_pulse) * 1.1
	draw_polyline(body_points, Color(1.0, 0.76, 0.28, core_alpha), pulse_width, true)

func _trim_curve_tail(points: PackedVector2Array, trim_amount: float) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var trimmed := PackedVector2Array()
	for point in points:
		trimmed.append(point)

	var remaining_trim: float = trim_amount
	while trimmed.size() >= 2 and remaining_trim > 0.0:
		var last_index: int = trimmed.size() - 1
		var tip: Vector2 = trimmed[last_index]
		var prev: Vector2 = trimmed[last_index - 1]
		var segment_length: float = tip.distance_to(prev)

		if segment_length <= remaining_trim and trimmed.size() > 2:
			trimmed.remove_at(last_index)
			remaining_trim -= segment_length
		else:
			var dir: Vector2 = (tip - prev).normalized()
			trimmed[last_index] = tip - dir * remaining_trim
			remaining_trim = 0.0

	return trimmed

func _draw_arrow_head(points: PackedVector2Array, has_hover_target: bool) -> void:
	var tip: Vector2 = points[points.size() - 1]
	var dir: Vector2 = _get_tip_direction(points)
	if dir == Vector2.ZERO:
		return

	var normal: Vector2 = Vector2(-dir.y, dir.x)
	var back: Vector2 = tip - dir * ARROW_LENGTH
	var left: Vector2 = back + normal * ARROW_WIDTH
	var right: Vector2 = back - normal * ARROW_WIDTH

	var outline_left: Vector2 = back + normal * (ARROW_WIDTH + 6.0) - dir * 5.0
	var outline_right: Vector2 = back - normal * (ARROW_WIDTH + 6.0) - dir * 5.0
	var outline_tip: Vector2 = tip + dir * 6.0

	draw_polygon(
		PackedVector2Array([outline_tip, outline_left, outline_right]),
		[Color(0.08, 0.0, 0.0, 0.86)]
	)

	var main_color: Color = Color(1.0, 0.28, 0.08, 1.0) if has_hover_target else Color(0.95, 0.18, 0.08, 0.94)
	draw_polygon(PackedVector2Array([tip, left, right]), [main_color])

	var inner_left: Vector2 = back + normal * (ARROW_WIDTH * 0.38)
	var inner_right: Vector2 = back - normal * (ARROW_WIDTH * 0.38)
	var inner_tip: Vector2 = tip - dir * 5.0
	draw_polygon(
		PackedVector2Array([inner_tip, inner_left, inner_right]),
		[Color(1.0, 0.83, 0.35, 0.95)]
	)

func _get_tip_direction(points: PackedVector2Array) -> Vector2:
	var tip: Vector2 = points[points.size() - 1]

	for i in range(points.size() - 2, -1, -1):
		var candidate: Vector2 = points[i]
		if tip.distance_to(candidate) >= 16.0:
			var dir: Vector2 = (tip - candidate).normalized()
			if dir != Vector2.ZERO:
				return dir

	return (tip - points[0]).normalized()

func _draw_source_anchor(pos: Vector2) -> void:
	var pulse_radius: float = SOURCE_RING_RADIUS + sin(_pulse) * 2.0
	draw_circle(pos, pulse_radius + 5.0, Color(1.0, 0.22, 0.08, 0.16))
	draw_arc(pos, pulse_radius, 0.0, TAU, 36, Color(1.0, 0.66, 0.22, 1.0), 4.0, true)
	draw_circle(pos, 5.5, Color(1.0, 0.82, 0.3, 1.0))

func _draw_target_anchor(pos: Vector2) -> void:
	var pulse_radius: float = TARGET_RING_RADIUS + sin(_pulse + 1.2) * 5.0
	var outer_radius: float = pulse_radius + 12.0
	var crosshair_color := Color(1.0, 0.92, 0.18, 1.0)
	var crosshair_shadow := Color(0.08, 0.0, 0.0, 0.82)

	# Lock-on crosshair is drawn before the arrow body/head, so it sits below the arrow,
	# but it is oversized so it remains visible around the arrowhead.
	draw_circle(pos, outer_radius + 10.0, Color(1.0, 0.16, 0.04, 0.20))
	draw_circle(pos, pulse_radius + 3.0, Color(1.0, 0.22, 0.06, 0.10))
	draw_arc(pos, pulse_radius, 0.0, TAU, 56, crosshair_shadow, 8.0, true)
	draw_arc(pos, pulse_radius, 0.0, TAU, 56, crosshair_color, 4.0, true)
	draw_arc(pos, outer_radius, 0.0, TAU, 56, Color(1.0, 0.56, 0.10, 0.55), 2.0, true)

	_draw_crosshair_segment(pos + Vector2(-outer_radius - 14.0, 0.0), pos + Vector2(-14.0, 0.0), crosshair_shadow, crosshair_color)
	_draw_crosshair_segment(pos + Vector2(14.0, 0.0), pos + Vector2(outer_radius + 14.0, 0.0), crosshair_shadow, crosshair_color)
	_draw_crosshair_segment(pos + Vector2(0.0, -outer_radius - 14.0), pos + Vector2(0.0, -14.0), crosshair_shadow, crosshair_color)
	_draw_crosshair_segment(pos + Vector2(0.0, 14.0), pos + Vector2(0.0, outer_radius + 14.0), crosshair_shadow, crosshair_color)
	draw_circle(pos, 5.0, crosshair_shadow)
	draw_circle(pos, 3.0, crosshair_color)

func _draw_crosshair_segment(a: Vector2, b: Vector2, shadow_color: Color, main_color: Color) -> void:
	draw_line(a, b, shadow_color, 7.0, true)
	draw_line(a, b, main_color, 3.0, true)

func _has_queued_enemy_targets() -> bool:
	var player_units = arena.get("player_units")
	if typeof(player_units) != TYPE_ARRAY:
		return false

	for unit in player_units:
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("health", 1)) <= 0:
			continue
		if str(unit.get("queued_target_side", "enemy")) != "enemy":
			continue
		if int(unit.get("queued_target_index", -1)) >= 0:
			return true

	return false

func _draw_queued_target_lines() -> void:
	var player_units = arena.get("player_units")
	if typeof(player_units) != TYPE_ARRAY:
		return

	for i in range(player_units.size()):
		var unit = player_units[i]
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		if int(unit.get("health", 1)) <= 0:
			continue
		if str(unit.get("queued_target_side", "enemy")) != "enemy":
			continue

		var target_index: int = int(unit.get("queued_target_index", -1))
		if target_index < 0:
			continue

		var start_pos: Vector2 = _get_player_arrow_start(i)
		var end_pos: Vector2 = _get_enemy_arrow_end(target_index)
		if start_pos == Vector2.INF or end_pos == Vector2.INF:
			continue

		_draw_thin_queued_line(start_pos, end_pos)

func _draw_thin_queued_line(start_pos: Vector2, end_pos: Vector2) -> void:
	var points: PackedVector2Array = _build_curve_points(start_pos, end_pos)
	if points.size() < 2:
		return

	draw_polyline(points, Color(0.02, 0.0, 0.0, 0.58), QUEUED_LINE_OUTER_WIDTH, true)
	draw_polyline(points, Color(1.0, 0.58, 0.18, 0.78), QUEUED_LINE_INNER_WIDTH, true)
	draw_circle(end_pos, 5.0, Color(1.0, 0.72, 0.28, 0.82))
