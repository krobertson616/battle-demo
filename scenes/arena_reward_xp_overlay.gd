extends Node

const XP_BADGE_NAME := "XpRewardBadge"
const DEFAULT_XP_GAIN := 1

var arena: Node
var reward_overlay: Control
var survivor_cards_row: HBoxContainer
var xp_gain_label: Label
var was_reward_visible := false
var last_card_count := -1
var refresh_pending := false

func _ready() -> void:
	arena = get_parent()
	if arena == null:
		set_process(false)
		return

	reward_overlay = arena.get_node_or_null("RewardOverlay") as Control
	survivor_cards_row = arena.get_node_or_null("RewardOverlay/RewardPanel/RewardVBox/SurvivorCardsRow") as HBoxContainer
	xp_gain_label = arena.get_node_or_null("RewardOverlay/RewardPanel/RewardVBox/XpGainLabel") as Label
	set_process(true)
	_schedule_refresh()

func _process(_delta: float) -> void:
	if reward_overlay == null or survivor_cards_row == null:
		return

	var reward_visible := reward_overlay.visible
	var card_count := survivor_cards_row.get_child_count()

	if reward_visible and (not was_reward_visible or card_count != last_card_count):
		_schedule_refresh()

	was_reward_visible = reward_visible
	last_card_count = card_count

func _schedule_refresh() -> void:
	if refresh_pending:
		return

	refresh_pending = true
	call_deferred("_refresh_xp_badges")

func _refresh_xp_badges() -> void:
	refresh_pending = false

	if reward_overlay == null or survivor_cards_row == null:
		return
	if not reward_overlay.visible:
		return

	await get_tree().process_frame

	var card_count := survivor_cards_row.get_child_count()
	if card_count <= 0:
		if xp_gain_label != null:
			xp_gain_label.visible = true
		return

	if xp_gain_label != null:
		xp_gain_label.visible = false

	var survivors: Array = []
	if Engine.has_singleton("GameState"):
		survivors = GameState.pending_result.get("player_survivors", [])
	elif "pending_result" in GameState:
		survivors = GameState.pending_result.get("player_survivors", [])

	for i in range(card_count):
		var row_child := survivor_cards_row.get_child(i)
		var card := _find_card_with_portrait(row_child)
		if card == null:
			continue

		var xp_amount := DEFAULT_XP_GAIN
		if i < survivors.size() and typeof(survivors[i]) == TYPE_DICTIONARY:
			xp_amount = int(survivors[i].get("xp_gain", survivors[i].get("xp", DEFAULT_XP_GAIN)))

		_apply_xp_badge(card, xp_amount)

func _find_card_with_portrait(root: Node) -> Control:
	if root == null:
		return null

	if root is Control and _get_portrait(root as Control) != null:
		return root as Control

	for child in root.get_children():
		var found := _find_card_with_portrait(child)
		if found != null:
			return found

	return null

func _get_portrait(card: Control) -> TextureRect:
	return card.get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/ArtFrame/AspectRatioContainer/Portrait") as TextureRect

func _apply_xp_badge(card: Control, xp_amount: int) -> void:
	var portrait := _get_portrait(card)
	if portrait == null:
		return

	var badge := card.get_node_or_null(XP_BADGE_NAME) as Label
	if badge == null:
		badge = Label.new()
		badge.name = XP_BADGE_NAME
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.z_index = 200
		card.add_child(badge)

	badge.text = "+%d XP" % xp_amount
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 28)
	badge.add_theme_color_override("font_color", Color(0.75, 0.22, 1.0, 1.0))
	badge.add_theme_color_override("font_outline_color", Color(0.08, 0.0, 0.12, 1.0))
	badge.add_theme_constant_override("outline_size", 7)

	var portrait_local_pos := portrait.get_global_position() - card.get_global_position()
	badge.position = portrait_local_pos + Vector2(0, 4)
	badge.size = Vector2(portrait.size.x, 34)
