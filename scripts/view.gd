extends Node3D

@export var min_distance: float = 1.6
@export var max_distance: float = 8.0
@export var zoom_step: float = 0.12

@onready var _camera: Camera3D = $Camera3D
@onready var _console: Node3D = $Console

var _direction := Vector3.FORWARD
var _distance := 3.2


func _ready() -> void:
	_distance = _camera.position.length()
	_direction = _camera.position / _distance


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			return
		var amount: float = button.factor if button.factor > 0.0 else 1.0
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_distance(_distance * (1.0 - zoom_step * amount))
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_distance(_distance * (1.0 + zoom_step * amount))


func _set_distance(next: float) -> void:
	_distance = clampf(next, min_distance, max_distance)
	_camera.position = _direction * _distance


func _on_reset_pressed() -> void:
	_console.quaternion = Quaternion.IDENTITY
