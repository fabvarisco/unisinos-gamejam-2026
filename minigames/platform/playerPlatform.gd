extends CharacterBody2D

@export var speed: float = 180.0
@export var gravity: float = 1400.0
@export var jump_velocity: float = -560.0

const _IDLE_FRAMES: Array[Rect2] = [
	Rect2(0, 238, 16, 16),
	Rect2(17, 238, 16, 16),
]
const _WALK_FRAMES: Array[Rect2] = [
	Rect2(0, 204, 16, 16),
	Rect2(17, 204, 16, 16),
	Rect2(51, 204, 16, 16),
	Rect2(68, 204, 16, 16),
]
const _JUMP := Rect2(85, 204, 16, 16)

var move_axis := Vector2.ZERO
var deaths := 0

var _spawn := Vector2.ZERO
var _walk_time := 0.0
var _idle_time := 0.0
var _dying := false
var _jump_armed := true

@onready var _sprite: Sprite2D = $Sprite2D


func set_spawn(point: Vector2) -> void:
	_dying = false
	_spawn = point
	global_position = point
	velocity = Vector2.ZERO
	_jump_armed = true
	collision_layer = 1
	collision_mask = 1


func respawn() -> bool:
	if _dying:
		return false
	_dying = true
	deaths += 1
	move_axis = Vector2.ZERO
	if global_position.y > 700.0:
		global_position.y = 640.0
	velocity = Vector2(0, -780)
	collision_layer = 0
	collision_mask = 0
	return true


func try_jump() -> void:
	if _dying or not is_on_floor():
		return
	velocity.y = jump_velocity
	if not _jump_armed:
		return
	_jump_armed = false
	var game := get_parent()
	if game.has_method("play_jump"):
		game.play_jump()


func _physics_process(delta: float) -> void:
	if _dying:
		velocity.y += gravity * delta
		velocity.x = 0.0
		global_position += velocity * delta
		_animate(delta)
		if global_position.y > 900.0:
			var game := get_parent()
			if game.has_method("reload_level"):
				game.reload_level()
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = move_axis.x * speed
	move_and_slide()
	if not is_on_floor():
		_jump_armed = true
	_animate(delta)
	if global_position.y > 820.0:
		respawn()


func _animate(delta: float) -> void:
	var region := _IDLE_FRAMES[0]
	if _dying:
		region = _JUMP
	elif not is_on_floor():
		_idle_time = 0.0
		region = _JUMP
	elif absf(move_axis.x) > 0.01:
		_idle_time = 0.0
		_walk_time += delta
		var index := int(_walk_time / 0.16) % _WALK_FRAMES.size()
		region = _WALK_FRAMES[index]
	else:
		_walk_time = 0.0
		_idle_time += delta
		var idle_index := int(_idle_time / 0.45) % _IDLE_FRAMES.size()
		region = _IDLE_FRAMES[idle_index]
	var atlas := _sprite.texture as AtlasTexture
	atlas.region = region
	_sprite.texture = atlas
	if move_axis.x < 0.0:
		_sprite.flip_h = true
	elif move_axis.x > 0.0:
		_sprite.flip_h = false
