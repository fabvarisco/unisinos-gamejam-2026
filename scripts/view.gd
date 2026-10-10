extends Node3D

@export var min_distance: float = 1.6
@export var max_distance: float = 8.0
@export var zoom_step: float = 0.12

@onready var _camera: Camera3D = $Camera3D
@onready var _console: Node3D = $Console
@onready var _fade: ColorRect = $CanvasLayer/Fade

var _direction := Vector3.FORWARD
var _distance := 3.2
var intro_playing := true


func _ready() -> void:
	_distance = _camera.position.length()
	_direction = _camera.position / _distance
	_console.place_batteries_out()
	_console.position.y = -4.0
	_console.rotation.y = TAU * 3.0
	var fade_material := _fade.material as ShaderMaterial
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_console, "position:y", 0.0, 2.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_console, "rotation:y", 0.0, 2.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(fade_material, "shader_parameter/cover", 0.0, 2.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_finish_intro)


func _finish_intro() -> void:
	intro_playing = false
	_console.intro_playing = false
	_console.reveal_batteries()
	_fade.visible = false


func _input(event: InputEvent) -> void:
	if intro_playing:
		return
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
	if intro_playing:
		return
	_console.quaternion = Quaternion.IDENTITY
