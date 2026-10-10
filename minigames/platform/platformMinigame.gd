extends Node2D

const SPAWN := Vector2(160, 607)
const MonsterScript := preload("res://minigames/platform/monsterPlatform.gd")
const PixelTransitionShader := preload("res://shaders/pixel_transition.gdshader")

var _level := 1
var _done := false
var _switching := false

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
	if _done or _switching:
		return
	_switching = true
	_change_level()


func _change_level() -> void:
	_set_actors_active(false)
	var from_tex := _snapshot()
	if _level >= 4:
		_done = true
		_done_label.visible = true
		_player.velocity = Vector2.ZERO
	else:
		_start_level(_level + 1)
		_set_actors_active(false)
	await RenderingServer.frame_post_draw
	var to_tex := _snapshot()
	await _play_pixel(from_tex, to_tex)
	_switching = false
	if _done:
		return
	_player.velocity = Vector2.ZERO
	_set_actors_active(true)


func _set_actors_active(active: bool) -> void:
	_player.set_physics_process(active)
	if not active:
		_player.velocity = Vector2.ZERO
	for child in get_children():
		if child.get_script() == MonsterScript:
			child.set_physics_process(active)


func _snapshot() -> ImageTexture:
	var image := get_viewport().get_texture().get_image()
	return ImageTexture.create_from_image(image)


func _play_pixel(from_tex: ImageTexture, to_tex: ImageTexture) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	var cover := ColorRect.new()
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = PixelTransitionShader
	material.set_shader_parameter("from_tex", from_tex)
	material.set_shader_parameter("to_tex", to_tex)
	material.set_shader_parameter("progress", 0.0)
	cover.material = material
	add_child(layer)
	layer.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("progress", value), 0.0, 1.0, 1.2)
	await tween.finished
	layer.queue_free()


func _on_goal_body_entered(body: Node2D) -> void:
	if body == _player:
		notify_goal()
