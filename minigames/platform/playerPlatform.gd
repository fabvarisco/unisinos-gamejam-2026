extends CharacterBody2D

@export var speed: float = 280.0
@export var gravity: float = 1400.0
@export var jump_velocity: float = -560.0

const _IDLE := Rect2(0, 204, 16, 16)
const _WALK := Rect2(17, 204, 16, 16)
const _JUMP := Rect2(85, 204, 16, 16)

var move_axis := Vector2.ZERO

var _spawn := Vector2.ZERO
var _walk_time := 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func set_spawn(point: Vector2) -> void:
	_spawn = point
	global_position = point
	velocity = Vector2.ZERO


func respawn() -> void:
	global_position = _spawn
	velocity = Vector2.ZERO


func try_jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = move_axis.x * speed
	move_and_slide()
	_animate(delta)
	if global_position.y > 820.0:
		respawn()


func _animate(delta: float) -> void:
	var atlas := _sprite.texture as AtlasTexture
	if not is_on_floor():
		atlas.region = _JUMP
	elif absf(move_axis.x) > 0.01:
		_walk_time += delta
		atlas.region = _WALK if int(_walk_time / 0.12) % 2 == 1 else _IDLE
	else:
		_walk_time = 0.0
		atlas.region = _IDLE
	if move_axis.x < 0.0:
		_sprite.flip_h = true
	elif move_axis.x > 0.0:
		_sprite.flip_h = false
