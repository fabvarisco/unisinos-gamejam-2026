extends CharacterBody2D

@export var speed: float = 280.0
@export var gravity: float = 1400.0
@export var jump_velocity: float = -900.0

var move_axis := Vector2.ZERO

var _spawn := Vector2.ZERO


func _ready() -> void:
	_spawn = global_position


func try_jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = move_axis.x * speed
	move_and_slide()
	if global_position.y > 820.0:
		global_position = _spawn
		velocity = Vector2.ZERO
