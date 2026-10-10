extends Node3D

@export var min_distance: float = 1.6
@export var max_distance: float = 8.0
@export var zoom_step: float = 0.12

const _LINES: PackedStringArray = [
	"Whoa, a video game. I wonder if this works? Maybe if I connect the batteries, it will turn on.",
	"Press Turn to flip the Game Boy. Then drag each battery into its slot on the back.",
]
const _BACK_LINE := "Wow, so many circuits. But it looks like I need to connect the cable to them for them to work."

@onready var _camera: Camera3D = $Camera3D
@onready var _console: Node3D = $Console
@onready var _fade: ColorRect = $CanvasLayer/Fade
@onready var _dialogue: PanelContainer = $CanvasLayer/Dialogue

var _direction := Vector3.FORWARD
var _distance := 3.2
var intro_playing := true
var _spin: Tween
var _seen_back := false


func _ready() -> void:
	_distance = _camera.position.length()
	_direction = _camera.position / _distance
	_console.place_batteries_out()
	for battery_name in ["BatteryLeft", "BatteryRight"]:
		_console.get_node(battery_name).inserted.connect(_on_battery_inserted)
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
	_dialogue.start(_LINES)


func _on_battery_inserted() -> void:
	if not _dialogue.visible:
		return
	for battery_name in ["BatteryLeft", "BatteryRight"]:
		if not _console.get_node(battery_name).installed:
			return
	_dialogue.close()


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


func _on_turn_pressed() -> void:
	if intro_playing or _dialogue.visible:
		return
	_stop_spin()
	_console.spin_locked = true
	var spin := create_tween()
	_spin = spin
	spin.tween_property(_console, "rotation:y", _console.rotation.y + PI, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	spin.finished.connect(func() -> void:
		if _spin != spin:
			return
		_console.spin_locked = false
		if _seen_back:
			return
		_seen_back = true
		_dialogue.start(PackedStringArray([_BACK_LINE]))
	)


func _on_reset_pressed() -> void:
	if intro_playing or _dialogue.visible:
		return
	_stop_spin()
	_console.quaternion = Quaternion.IDENTITY


func _stop_spin() -> void:
	if _spin != null and _spin.is_valid():
		_spin.kill()
	_spin = null
	_console.spin_locked = false
