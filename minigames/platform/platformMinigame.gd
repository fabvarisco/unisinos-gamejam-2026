extends Node2D

const SPAWN := Vector2(160, 607)
const MonsterScript := preload("res://minigames/platform/monsterPlatform.gd")

var _level := 1
var _done := false

@onready var _level_map: TileMapLayer = $LevelPlatform
@onready var _player: CharacterBody2D = $PlayerPlatform
@onready var _done_label: Label = $Hud/DoneLabel


func _ready() -> void:
	_done_label.visible = false
	_start_level(1)


func _start_level(index: int) -> void:
	_level = index
	for child in get_children():
		if child.get_script() == MonsterScript:
			child.queue_free()
	_level_map.load_level(index)
	_player.set_spawn(SPAWN)
	if index == 3:
		_add_monster(860.0, 760.0, 1040.0)
	elif index == 4:
		_add_monster(520.0, 400.0, 680.0)
		_add_monster(900.0, 760.0, 1080.0)


func _add_monster(x: float, left: float, right: float) -> void:
	var monster := CharacterBody2D.new()
	monster.set_script(MonsterScript)
	monster.position = Vector2(x, SPAWN.y)
	monster.left_limit = left
	monster.right_limit = right
	add_child(monster)


func notify_goal() -> void:
	if _done:
		return
	if _level >= 4:
		_done = true
		_done_label.visible = true
		_player.velocity = Vector2.ZERO
		_player.set_physics_process(false)
		for child in get_children():
			if child.get_script() == MonsterScript:
				child.set_physics_process(false)
		return
	_start_level(_level + 1)


func _on_goal_body_entered(body: Node2D) -> void:
	if body == _player:
		notify_goal()
