extends CharacterBody2D

@export var speed: float = 280.0
@export var gravity: float = 1400.0

var move_axis := Vector2.ZERO


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	elif move_axis.y >= 0.0:
		velocity.y = 0.0

	velocity.x = move_axis.x * speed
	if move_axis.y != 0.0:
		velocity.y = move_axis.y * speed

	move_and_slide()
