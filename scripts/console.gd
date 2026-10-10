extends Node3D

const DpadButtonScript := preload("res://scripts/dpad_button.gd")

@export var sensitivity: float = 0.01

var _dragging := false
var _pressing_dpad := false
var _pressing_button := false
var _holding_wire := false
var _holding_battery: MeshInstance3D
var _holding_screwdriver := false
var _last_mouse := Vector2.ZERO
var _shorted: Dictionary = {}
var _dpad_locked := false
var _locked_axis := Vector2.ZERO
var _holding_a := false

@onready var _camera: Camera3D = $"../Camera3D"
@onready var _player: CharacterBody2D = $ScreenViewport/PlatformMinigame/PlayerPlatform
@onready var _wire: Node3D = $Back/Mainboard/Wire
@onready var _energy_label: Label = $ScreenViewport/PlatformMinigame/Hud/EnergyLabel
@onready var _batteries: Array[MeshInstance3D] = [$BatteryLeft, $BatteryRight]
@onready var _screwdriver: Node3D = $Screwdriver

var _bodies: Dictionary = {}
var _hovered: MeshInstance3D
var _overlay_white: StandardMaterial3D
var _overlay_green: StandardMaterial3D
var _overlay_red: StandardMaterial3D
var _burned: StandardMaterial3D
var _shake := 0.0
var _rest_position := Vector3.ZERO

const SHAKE_TIME := 0.34


func _ready() -> void:
	_overlay_white = _make_overlay(Color(1, 1, 1, 0.55))
	_overlay_green = _make_overlay(Color(0.25, 1, 0.4, 0.55))
	_overlay_red = _make_overlay(Color(1, 0.18, 0.12, 0.6))
	_burned = _make_overlay(Color(0.12, 0.05, 0.02, 1.0))
	_burned.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	for button in $Dpad.get_children():
		if button.get_script() == DpadButtonScript:
			button.pressed.connect(_on_dpad_pressed)
			_bodies[button] = {"mesh": button.get_node("Mesh"), "pad": "PadDpad", "live": false}
	_add_hitbox($ButtonA, "PadA")
	_add_hitbox($ButtonB, "PadB")
	_add_hitbox($Start, "PadStart")
	_add_cylinder_hitbox($Side/ContrastWheel)
	_add_hitbox($Side/VolumePlus, "", true)
	_add_hitbox($Side/VolumeMinus, "", true)
	_add_blocker($Body)
	for battery in _batteries:
		battery.removed.connect(_refresh_energy)
	_refresh_energy()
	_rest_position = position


func _process(frame_delta: float) -> void:
	_update_shake(frame_delta)
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var mouse := get_viewport().get_mouse_position()
	_update_hover(mouse)
	if not pressed:
		_holding_a = false
	_update_jump()
	if not pressed:
		_dragging = false
		_pressing_dpad = false
		_pressing_button = false
		_holding_wire = false
		_holding_screwdriver = false
		if _holding_battery != null:
			_holding_battery.release()
			_holding_battery = null
		_screwdriver.release()
		_wire.release()
		_player.move_axis = _locked_axis if _dpad_locked else Vector2.ZERO
		return
	if not _dragging and not _pressing_dpad and not _pressing_button and not _holding_wire and _holding_battery == null and not _holding_screwdriver:
		if get_viewport().gui_get_hovered_control() != null:
			return
		if _try_grab_battery(mouse):
			return
		if _try_grab_screwdriver(mouse):
			return
		if _wire.try_grab(mouse, _camera):
			_holding_wire = true
			return
		if _dpad_axis(mouse) != Vector2.ZERO:
			_pressing_dpad = true
			return
		if _press_front_button(mouse):
			_pressing_button = true
			return
		if _mesh_under(mouse) != null:
			return
		_dragging = true
		_last_mouse = mouse
		return
	if _holding_battery != null:
		_holding_battery.drag_to(_holding_battery.follow_point(mouse, _camera))
		return
	if _holding_screwdriver:
		_screwdriver.drag_to(_screwdriver.follow_point(mouse, _camera))
		return
	if _holding_wire:
		_wire.drag(mouse, _camera)
		return
	if _pressing_dpad:
		_dpad_axis(mouse)
		return
	if _pressing_button:
		return
	var delta := mouse - _last_mouse
	_last_mouse = mouse
	if delta == Vector2.ZERO:
		return
	var yaw: float = -delta.x * sensitivity
	rotation = Vector3(0.0, rotation.y + yaw, 0.0)


func _refresh_energy() -> void:
	var installed := 0
	for battery in _batteries:
		if battery.installed:
			installed += 1
	_energy_label.text = "%d%%" % (installed * 50)


func _try_grab_screwdriver(mouse: Vector2) -> bool:
	var hit := _ray_hit(mouse)
	if hit.is_empty():
		return false
	if not _screwdriver.try_grab(hit.collider):
		return false
	_holding_screwdriver = true
	return true


func _update_jump() -> void:
	var stuck: bool = _shorted.has("PadA")
	var wired: bool = _holding_a and _wire.is_live("PadA")
	if stuck or wired:
		_player.try_jump()


func _press_front_button(mouse: Vector2) -> bool:
	var mesh := _mesh_under(mouse)
	if mesh == null:
		return false
	var pad_name: String = _bodies[_body_for(mesh)]["pad"]
	if pad_name == "" or pad_name == "PadDpad":
		return false
	if pad_name == "PadA":
		_holding_a = true
	if _screwdriver.seated_pad != null and _screwdriver.seated_pad.name == pad_name:
		_burn(pad_name)
	return true


func _burn(pad_name: String) -> void:
	if _shorted.has(pad_name):
		return
	_shorted[pad_name] = true
	_screwdriver.stick()
	_wire.block_pad(pad_name)
	var hole := get_node("Back/%s/Hole" % pad_name) as MeshInstance3D
	hole.material_override = _burned
	for body in _bodies:
		var info: Dictionary = _bodies[body]
		if info["pad"] == pad_name:
			(info["mesh"] as MeshInstance3D).material_overlay = _overlay_red
	_shake = SHAKE_TIME
	_burst(pad_name)


func _update_shake(delta: float) -> void:
	if _shake <= 0.0:
		position = _rest_position
		return
	_shake = maxf(_shake - delta, 0.0)
	var strength := _shake / SHAKE_TIME
	position = _rest_position + Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-0.35, 0.35)
	) * 0.05 * strength


func _burst(pad_name: String) -> void:
	var pad := get_node("Back/%s" % pad_name) as Node3D
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 0.92
	sparks.amount = 32
	sparks.lifetime = 0.5
	sparks.direction = Vector3(0, 0, -1)
	sparks.spread = 34.0
	sparks.gravity = Vector3(0, -1.2, 0)
	sparks.initial_velocity_min = 1.1
	sparks.initial_velocity_max = 2.4
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.028, 0.028, 0.028)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.62, 0.16)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.38, 0.05)
	material.emission_energy_multiplier = 2.2
	mesh.surface_set_material(0, material)
	sparks.mesh = mesh
	pad.add_child(sparks)
	sparks.position = Vector3(0, 0, -0.06)
	sparks.emitting = true
	get_tree().create_timer(1.1).timeout.connect(sparks.queue_free)


func _try_grab_battery(mouse: Vector2) -> bool:
	var hit := _ray_hit(mouse)
	if hit.is_empty():
		return false
	for battery in _batteries:
		if battery.try_grab(hit.collider):
			_holding_battery = battery
			return true
	return false


func _ray_hit(mouse: Vector2) -> Dictionary:
	var origin := _camera.project_ray_origin(mouse)
	var end := origin + _camera.project_ray_normal(mouse) * 100.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	return _camera.get_world_3d().direct_space_state.intersect_ray(query)


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
	if _dpad_locked:
		_player.move_axis = _locked_axis
		return
	if _screwdriver.seated_pad != null and _screwdriver.seated_pad.name == "PadDpad":
		_burn("PadDpad")
		_dpad_locked = true
		_locked_axis = direction
		_player.move_axis = direction
		return
	if not _wire.is_live("PadDpad"):
		return
	_player.move_axis = direction


func _add_blocker(mesh: MeshInstance3D) -> void:
	var body := StaticBody3D.new()
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (mesh.mesh as BoxMesh).size
	shape.shape = box
	body.add_child(shape)
	mesh.add_child(body)


func _add_hitbox(mesh: MeshInstance3D, pad_name: String, live := false) -> void:
	var body := StaticBody3D.new()
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (mesh.mesh as BoxMesh).size
	shape.shape = box
	body.add_child(shape)
	mesh.add_child(body)
	_bodies[body] = {"mesh": mesh, "pad": pad_name, "live": live}


func _add_cylinder_hitbox(mesh: MeshInstance3D) -> void:
	var source := mesh.mesh as CylinderMesh
	var body := StaticBody3D.new()
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = source.top_radius
	cylinder.height = source.height
	shape.shape = cylinder
	body.add_child(shape)
	mesh.add_child(body)
	_bodies[body] = {"mesh": mesh, "pad": "", "live": true}


func _update_hover(mouse: Vector2) -> void:
	var mesh := _mesh_under(mouse)
	if _hovered != null and _hovered != mesh and not _mesh_is_shorted(_hovered):
		_hovered.material_overlay = null
	_hovered = mesh
	if mesh == null:
		return
	var info: Dictionary = _bodies[_body_for(mesh)]
	var pad_name: String = info["pad"]
	if _shorted.has(pad_name):
		mesh.material_overlay = _overlay_red
		return
	var working: bool = bool(info["live"]) or (pad_name == "PadDpad" and _wire.is_live(pad_name))
	mesh.material_overlay = _overlay_green if working else _overlay_white


func _mesh_is_shorted(mesh: MeshInstance3D) -> bool:
	var body := _body_for(mesh)
	if body == null:
		return false
	return _shorted.has(_bodies[body]["pad"])


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
