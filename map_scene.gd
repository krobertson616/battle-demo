extends Control

@onready var title_label: Label = $MainVBox/TitleLabel
@onready var cave_button: Button = $MainVBox/ZoneButtons/CaveButton
@onready var forest_button: Button = $MainVBox/ZoneButtons/ForestButton
@onready var crypt_button: Button = $MainVBox/ZoneButtons/CryptButton
@onready var view_roster_button: Button = $MainVBox/ViewRosterButton
@onready var roster_panel: PanelContainer = $RosterPanel
@onready var roster_label: Label = $RosterPanel/VBoxContainer/RosterTitle
@onready var roster_row: HBoxContainer = $RosterPanel/VBoxContainer/RosterRow
@onready var team_label: Label = $RosterPanel/VBoxContainer/TeamLabel
@onready var team_row: HBoxContainer = $RosterPanel/VBoxContainer/TeamRow
@onready var close_roster_button: Button = $RosterPanel/VBoxContainer/CloseRosterButton



var monster_card_scene = preload("res://scenes/monster_card.tscn")

var codex_button: Button
var codex_panel: PanelContainer
var codex_close_button: Button
var codex_entry_container: GridContainer

var codex_entries: Array[Dictionary] = []

func _ready() -> void:
	title_label.text = "Choose Your Expedition"

	cave_button.text = "Cave (Fresh Run)"
	forest_button.text = "Forest (Lv 10+)"
	crypt_button.text = "Crypt (Lv 20+)"

	view_roster_button.text = "View Saved Monsters"

	cave_button.pressed.connect(_on_zone_pressed.bind("cave", 1))
	forest_button.pressed.connect(_on_zone_pressed.bind("forest", 10))
	crypt_button.pressed.connect(_on_zone_pressed.bind("crypt", 20))
	view_roster_button.pressed.connect(_on_view_roster_pressed)
	close_roster_button.pressed.connect(_on_close_roster_pressed)

	roster_panel.visible = false
	_refresh_roster_panel()

	_build_codex_entries()
	_create_codex_ui()
	_refresh_codex_ui()


func _build_codex_entries() -> void:
	codex_entries.clear()

	for i in range(100):
		codex_entries.append({
			"id": i + 1,
			"name": "Monster %03d" % [i + 1],
			"tribe": "???",
			"biome": "???",
			"discovered": false,
			"monster_data": null
		})

	var sheni_template: MonsterData = GameState.get_monster_by_id("wolf")
	if sheni_template != null:
		var sheni: MonsterData = GameState.clone_monster(sheni_template)

		codex_entries[0] = {
			"id": 1,
			"name": sheni.display_name,
			"tribe": sheni.tribe,
			"biome": "Cave",
			"discovered": true,
			"monster_data": sheni
		}

	# Uncomment a few if you want some starter sample unlocked rows
	# codex_entries[0]["name"] = "Cave Slime"
	# codex_entries[0]["tribe"] = "Slime"
	# codex_entries[0]["biome"] = "Cave"
	# codex_entries[0]["discovered"] = true
	#
	# codex_entries[1]["name"] = "Fire Imp"
	# codex_entries[1]["tribe"] = "Imp"
	# codex_entries[1]["biome"] = "Cave"
	# codex_entries[1]["discovered"] = true
	#
	# codex_entries[2]["name"] = "Pebble"
	# codex_entries[2]["tribe"] = "Stone"
	# codex_entries[2]["biome"] = "Cave"
	# codex_entries[2]["discovered"] = true


func _create_codex_ui() -> void:
	codex_button = Button.new()
	codex_button.text = "Monster Codex"
	codex_button.custom_minimum_size = Vector2(180, 44)
	codex_button.anchor_left = 1.0
	codex_button.anchor_top = 0.0
	codex_button.anchor_right = 1.0
	codex_button.anchor_bottom = 0.0
	codex_button.offset_left = -210
	codex_button.offset_top = 20
	codex_button.offset_right = -20
	codex_button.offset_bottom = 64
	codex_button.pressed.connect(_on_codex_button_pressed)
	add_child(codex_button)

	codex_panel = PanelContainer.new()
	codex_panel.name = "CodexPanel"
	codex_panel.visible = false
	codex_panel.anchor_left = 0.08
	codex_panel.anchor_top = 0.08
	codex_panel.anchor_right = 0.92
	codex_panel.anchor_bottom = 0.92
	codex_panel.offset_left = 0
	codex_panel.offset_top = 0
	codex_panel.offset_right = 0
	codex_panel.offset_bottom = 0
	add_child(codex_panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 18)
	panel_margin.add_theme_constant_override("margin_top", 18)
	panel_margin.add_theme_constant_override("margin_right", 18)
	panel_margin.add_theme_constant_override("margin_bottom", 18)
	codex_panel.add_child(panel_margin)

	var panel_vbox := VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 12)
	panel_margin.add_child(panel_vbox)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	panel_vbox.add_child(header_row)

	var codex_title := Label.new()
	codex_title.text = "Monster Codex"
	codex_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	codex_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_row.add_child(codex_title)

	codex_close_button = Button.new()
	codex_close_button.text = "Close"
	codex_close_button.custom_minimum_size = Vector2(120, 36)
	codex_close_button.pressed.connect(_on_codex_close_pressed)
	header_row.add_child(codex_close_button)

	var info_label := Label.new()
	info_label.text = "Discovered monsters will appear here. Undiscovered entries remain hidden."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_vbox.add_child(info_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_vbox.add_child(scroll)

	codex_entry_container = GridContainer.new()
	codex_entry_container.columns = 2
	codex_entry_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	codex_entry_container.add_theme_constant_override("h_separation", 12)
	codex_entry_container.add_theme_constant_override("v_separation", 12)
	scroll.add_child(codex_entry_container)


func _refresh_codex_ui() -> void:
	if codex_entry_container == null:
		return

	for child in codex_entry_container.get_children():
		child.queue_free()

	for entry in codex_entries:
		codex_entry_container.add_child(_make_codex_entry(entry))
func _get_codex_portrait(monster: MonsterData) -> Texture2D:
	if monster == null:
		return null

	# Adjust this path to match where your monster portraits actually live.
	# Example result for Sheni:
	# res://assets/monsters/wolf.png
	var path := "res://assets/shen.png" % monster.id

	if ResourceLoader.exists(path):
		return load(path) as Texture2D

	return null

func _make_codex_entry(entry: Dictionary) -> Control:
	var outer := HBoxContainer.new()
	outer.custom_minimum_size = Vector2(0, 140)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 12)

	var monster_data: MonsterData = entry.get("monster_data", null)

	# Left side: portrait only
	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(120, 120)
	outer.add_child(portrait_panel)

	var portrait_margin := MarginContainer.new()
	portrait_margin.add_theme_constant_override("margin_left", 6)
	portrait_margin.add_theme_constant_override("margin_top", 6)
	portrait_margin.add_theme_constant_override("margin_right", 6)
	portrait_margin.add_theme_constant_override("margin_bottom", 6)
	portrait_panel.add_child(portrait_margin)

	if entry.get("discovered", false) and monster_data != null:
		var portrait := TextureRect.new()
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(108, 108)
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
		portrait.texture = _get_codex_portrait(monster_data)
		portrait_margin.add_child(portrait)
	else:
		var placeholder := Label.new()
		placeholder.text = "???"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		portrait_margin.add_child(placeholder)

	# Right side: text info
	var info_panel := PanelContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(info_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	info_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var id_and_name := Label.new()
	if entry.get("discovered", false):
		id_and_name.text = "#%03d  %s" % [entry.get("id", 0), entry.get("name", "Unknown")]
	else:
		id_and_name.text = "#%03d  ???" % [entry.get("id", 0)]
	vbox.add_child(id_and_name)

	var details := Label.new()
	if entry.get("discovered", false):
		details.text = "Tribe: %s\nBiome: %s" % [
			entry.get("tribe", "???"),
			entry.get("biome", "???")
		]
	else:
		details.text = "Tribe: ???\nBiome: ???"

	details.modulate = Color(0.8, 0.8, 0.8, 1.0)
	vbox.add_child(details)

	return outer
func _on_codex_button_pressed() -> void:
	codex_panel.visible = true


func _on_codex_close_pressed() -> void:
	codex_panel.visible = false


func _on_view_roster_pressed() -> void:
	_refresh_roster_panel()
	roster_panel.visible = true


func _on_close_roster_pressed() -> void:
	roster_panel.visible = false


func _make_monster_card_entry(monster: MonsterData, button_text: String, pressed_callback: Callable, setup_index: int) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(160, 240)

	var card = monster_card_scene.instantiate()
	card.custom_minimum_size = Vector2(150, 180)

	# Use "map" first. If your monster_card script only supports known locations,
	# change "map" to "board" here too.
	card.setup(monster, "map", setup_index)

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


func _refresh_roster_panel() -> void:
	roster_label.text = "Saved Monsters"
	team_label.text = "Expedition Team (%d / 3) Total Level: %d" % [
		GameState.selected_roster_indexes.size(),
		GameState.get_selected_team_total_level()
	]

	for c in roster_row.get_children():
		c.queue_free()

	for c in team_row.get_children():
		c.queue_free()

	for i in range(GameState.saved_monsters.size()):
		var monster: MonsterData = GameState.saved_monsters[i]

		var wrapper := VBoxContainer.new()
		wrapper.custom_minimum_size = Vector2(160, 240)

		var card = monster_card_scene.instantiate()
		card.custom_minimum_size = Vector2(150, 180)
		card.setup(monster, "board", i)

		if card is BaseButton:
			card.disabled = true
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

		wrapper.add_child(card)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 36)

		if i in GameState.selected_roster_indexes:
			btn.text = "In Team"
			btn.disabled = true
		else:
			btn.text = "Add to Team"
			btn.pressed.connect(_on_add_monster_to_team.bind(i))

		wrapper.add_child(btn)
		roster_row.add_child(wrapper)

	for index in GameState.selected_roster_indexes:
		if index < 0 or index >= GameState.saved_monsters.size():
			continue

		var monster: MonsterData = GameState.saved_monsters[index]

		var wrapper := VBoxContainer.new()
		wrapper.custom_minimum_size = Vector2(160, 240)

		var card = monster_card_scene.instantiate()
		card.custom_minimum_size = Vector2(150, 180)
		card.setup(monster, "board", index)

		if card is BaseButton:
			card.disabled = true
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

		wrapper.add_child(card)

		var btn := Button.new()
		btn.text = "Remove"
		btn.custom_minimum_size = Vector2(150, 36)
		btn.pressed.connect(_on_remove_monster_from_team.bind(index))
		wrapper.add_child(btn)

		team_row.add_child(wrapper)


func _on_add_monster_to_team(index: int) -> void:
	GameState.add_roster_monster_to_team(index)
	_refresh_roster_panel()


func _on_remove_monster_from_team(index: int) -> void:
	GameState.remove_roster_monster_from_team(index)
	_refresh_roster_panel()


func _on_zone_pressed(location_id: String, required_total_level: int) -> void:
	# Cave is always a fresh run with no expedition team
	if location_id == "cave":
		GameState.clear_selected_team()
		GameState.start_new_run_from_map("cave")
		get_tree().change_scene_to_file("res://scenes/run_scene.tscn")
		return

	# Harder zones require a selected team
	if GameState.selected_roster_indexes.is_empty():
		title_label.text = "Pick at least one monster."
		return

	if GameState.get_selected_team_total_level() < required_total_level:
		title_label.text = "Need team total level %d." % required_total_level
		return

	GameState.start_new_run_from_map(location_id)
	get_tree().change_scene_to_file("res://scenes/run_scene.tscn")
