class_name MonsterData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var tribe: String = ""
@export var cost: int = 1
@export var attack: int = 1
@export var health: int = 1
@export var evolves_to_id: String = ""
@export var max_health: int = 1

@export var modifiers: Array = []
@export var instincts: Array = []

@export var modifier_slots: int = 0
@export var equipped_modifiers: Array = []
