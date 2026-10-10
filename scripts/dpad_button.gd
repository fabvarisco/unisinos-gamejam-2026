extends StaticBody3D

signal pressed(direction: Vector2)

@export var direction := Vector2.ZERO


func press() -> void:
	pressed.emit(direction)
