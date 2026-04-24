extends Node

# Arena-side demo scaler.
# This catches enemy dictionaries and any boss summons that are created during
# combat so the whole fight uses the same x2 number scale.

const COMBAT_SCALE: int = 2

@onready var arena: Control = get_parent() as Control

func _ready() -> void:
	_scale_pending_teams()
	set_process(true)

func _process(_delta: float) -> void:
	if arena == null or not is_instance_valid(arena):
		return

	_scale_unit_array(arena.get("player_units"))
	_scale_unit_array(arena.get("enemy_units"))
	_scale_visual_array(arena.get("visual_player_team"))
	_scale_visual_array(arena.get("visual_enemy_team"))

func _scale_pending_teams() -> void:
	_scale_pending_array(GameState.pending_player_team)
	_scale_pending_array(GameState.pending_enemy_team)

func _scale_pending_array(team: Array) -> void:
	for entry in team:
		if entry is MonsterData:
			_scale_monster(entry)
		elif typeof(entry) == TYPE_DICTIONARY:
			_scale_enemy_dict(entry)

func _scale_visual_array(team) -> void:
	if typeof(team) != TYPE_ARRAY:
		return

	for entry in team:
		if entry is MonsterData:
			_scale_monster(entry)
		elif typeof(entry) == TYPE_DICTIONARY:
			_scale_enemy_dict(entry)

func _scale_unit_array(units) -> void:
	if typeof(units) != TYPE_ARRAY:
		return

	for unit in units:
		if typeof(unit) == TYPE_DICTIONARY:
			_scale_enemy_dict(unit)

func _scale_monster(monster) -> void:
	if monster == null:
		return
	if not (monster is MonsterData):
		return
	if monster.has_meta("demo_combat_scaled"):
		return

	var old_max_health: int = max(1, int(monster.max_health))
	var health_ratio: float = clampf(float(monster.health) / float(old_max_health), 0.0, 1.0)

	monster.attack = max(0, int(monster.attack) * COMBAT_SCALE)
	monster.max_health = max(1, int(monster.max_health) * COMBAT_SCALE)
	monster.health = clampi(int(round(float(monster.max_health) * health_ratio)), 1, int(monster.max_health))
	monster.set_meta("demo_combat_scaled", true)

func _scale_enemy_dict(enemy: Dictionary) -> void:
	if enemy.is_empty():
		return
	if bool(enemy.get("demo_combat_scaled", false)):
		return

	var old_max_health: int = max(1, int(enemy.get("max_health", enemy.get("health", 1))))
	var old_health: int = int(enemy.get("health", old_max_health))
	var health_ratio: float = clampf(float(old_health) / float(old_max_health), 0.0, 1.0)

	if enemy.has("attack"):
		enemy["attack"] = max(0, int(enemy.get("attack", 0)) * COMBAT_SCALE)
	if enemy.has("max_health"):
		enemy["max_health"] = max(1, int(enemy.get("max_health", 1)) * COMBAT_SCALE)
	if enemy.has("health"):
		var scaled_max: int = max(1, int(enemy.get("max_health", 1)))
		enemy["health"] = clampi(int(round(float(scaled_max) * health_ratio)), 1, scaled_max)

	# Scale fixed values on battle units so poison/burn/thorns/bonus damage remain visible.
	for key in ["poison_damage", "burn_damage", "thorns_damage", "bonus_damage", "heal_amount", "shield_amount"]:
		if enemy.has(key):
			enemy[key] = int(enemy.get(key, 0)) * COMBAT_SCALE

	enemy["demo_combat_scaled"] = true
