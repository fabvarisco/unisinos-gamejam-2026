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

var _bodies: Dictionary = {}
var _hovered: MeshInstance3D
var _overlay_white: StandardMaterial3D
var _overlay_green: StandardMaterial3D


func _ready() -> void:
	_overlay_white = _make_overlay(Color(1, 1, 1, 0.55))
	_overlay_green = _make_overlay(Color(0.25, 1, 0.4, 0.55))
	for button in $Dpad.get_children():
		if button.get_script() == DpadButtonScript:
			button.pressed.connect(_on_dpad_pressed)
			_bodies[button] = {"mesh": button.get_node("Mesh"), "pad": "PadDpad"}
	_add_hitbox($ButtonA, "PadA")
	_add_hitbox($ButtonB, "PadB")
	_add_hitbox($Start, "PadStart")


func _process(_delta: float) -> void:
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var mouse := get_viewport().get_mouse_position()
	_update_hover(mouse)
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
	if not _wire.is_live("PadDpad"):
		return
	_player.move_axis = direction


func _add_hitbox(mesh: MeshInstance3D, pad_name: String) -> void:
	var body := StaticBody3D.new()
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (mesh.mesh as BoxMesh).size
	shape.shape = box
	body.add_child(shape)
	mesh.add_child(body)
	_bodies[body] = {"mesh": mesh, "pad": pad_name}


func _update_hover(mouse: Vector2) -> void:
	var mesh := _mesh_under(mouse)
	if _hovered != null and _hovered != mesh:
		_hovered.material_overlay = null
	_hovered = mesh
	if mesh == null:
		return
	var pad_name: String = _bodies[_body_for(mesh)]["pad"]
	var working: bool = pad_name == "PadDpad" and _wire.is_live(pad_name)
	mesh.material_overlay = _overlay_green if working else _overlay_white


func _body_for(mesh: MeshInstance3D) -> StaticBody3D:
	for body in _bodies:
		if _bodies[body]["mesh"] == mesh:
			return body
	return null


func _mesh_under(mouse: Vector2) -> MeshInstance3D:
	var origin := _camera.project_ray_origin(mouse)
	var end := origin + _camera.project_ray_normal(mouse) * 100.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not _bodies.has(hit.collider):
		return null
	return _bodies[hit.collider]["mesh"]


func _make_overlay(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1)
	material.emission_energy_multiplier = 0.6
	return material
