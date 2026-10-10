extends Node3D

@export var sensitivity: float = 0.01

var _dragging := false
var _pressing_dpad := false
var _last_mouse := Vector2.ZERO

@onready var _camera: Camera3D = $"../Camera3D"
@onready var _dpad: StaticBody3D = $Dpad
@onready var _player: CharacterBody2D = $ScreenViewport/PlatformGame/CharacterBody2D


func _process(_delta: float) -> void:
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var mouse := get_viewport().get_mouse_position()
	if not pressed:
		_dragging = false
		_pressing_dpad = false
		_player.move_axis = Vector2.ZERO
		return
	if not _dragging and not _pressing_dpad:
		if get_viewport().gui_get_hovered_control() != null:
			return
		var axis := _dpad_axis(mouse)
		if axis != Vector2.ZERO:
			_pressing_dpad = true
			_player.move_axis = axis
			return
		_dragging = true
		_last_mouse = mouse
		return
	if _pressing_dpad:
		var axis := _dpad_axis(mouse)
		if axis != Vector2.ZERO:
			_player.move_axis = axis
		return
	var delta := mouse - _last_mouse
	_last_mouse = mouse
	if delta == Vector2.ZERO:
		return
	var yaw: float = -delta.x * sensitivity
	var pitch: float = -delta.y * sensitivity
	var rot := Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, pitch)
	quaternion = rot * quaternion


func _dpad_axis(mouse: Vector2) -> Vector2:
	var origin := _camera.project_ray_origin(mouse)
	var end := origin + _camera.project_ray_normal(mouse) * 100.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider != _dpad:
		return Vector2.ZERO
	var local: Vector3 = _dpad.to_local(hit.position)
	if absf(local.x) > absf(local.y):
		return Vector2(-1.0 if local.x < 0.0 else 1.0, 0.0)
	return Vector2(0.0, -1.0 if local.y > 0.0 else 1.0)
