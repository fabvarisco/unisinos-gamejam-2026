extends Node3D

const DpadButtonScript := preload("res://scripts/dpad_button.gd")

@export var sensitivity: float = 0.01

var _dragging := false
var _pressing_dpad := false
var _holding_wire := false
var _last_mouse := Vector2.ZERO

@onready var _camera: Camera3D = $"../Camera3D"
@onready var _player: CharacterBody2D = $ScreenViewport/PlatformGame/CharacterBody2D
@onready var _wire: Node3D = $Back/Mainboard/Wire


func _ready() -> void:
	for button in $Dpad.get_children():
		if button.get_script() == DpadButtonScript:
			button.pressed.connect(_on_dpad_pressed)


func _process(_delta: float) -> void:
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var mouse := get_viewport().get_mouse_position()
	if not pressed:
		_dragging = false
		_pressing_dpad = false
		_holding_wire = false
		_wire.release()
		_player.move_axis = Vector2.ZERO
		return
	if not _dragging and not _pressing_dpad and not _holding_wire:
		if get_viewport().gui_get_hovered_control() != null:
			return
		if _wire.try_grab(mouse, _camera):
			_holding_wire = true
			return
		if _dpad_axis(mouse) != Vector2.ZERO:
			_pressing_dpad = true
			return
		_dragging = true
		_last_mouse = mouse
		return
	if _holding_wire:
		_wire.drag(mouse, _camera)
		return
	if _pressing_dpad:
		_dpad_axis(mouse)
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
	if hit.is_empty():
		return Vector2.ZERO
	var button: StaticBody3D = hit.collider
	if button.get_script() != DpadButtonScript:
		return Vector2.ZERO
	button.press()
	return button.direction


func _on_dpad_pressed(direction: Vector2) -> void:
	_player.move_axis = direction
