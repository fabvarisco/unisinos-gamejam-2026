extends Node3D

@export var sensitivity: float = 0.01

var _dragging := false
var _last_mouse := Vector2.ZERO


func _process(_delta: float) -> void:
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var mouse := get_viewport().get_mouse_position()
	if not pressed:
		_dragging = false
		return
	if not _dragging:
		if get_viewport().gui_get_hovered_control() != null:
			return
		_dragging = true
		_last_mouse = mouse
		return
	var delta := mouse - _last_mouse
	_last_mouse = mouse
	if delta == Vector2.ZERO:
		return
	var yaw: float = -delta.x * sensitivity
	var pitch: float = -delta.y * sensitivity
	var rot := Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, pitch)
	quaternion = rot * quaternion
