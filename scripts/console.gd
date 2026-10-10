extends Node3D

const DpadButtonScript := preload("res://scripts/dpad_button.gd")
const PixelTransitionShader := preload("res://shaders/pixel_transition.gdshader")
const SHAKE_TIME := 0.34
const MASTER_BUS := "Master"
const VOLUME_DB_MIN := -40.0
const VOLUME_DB_MAX := 0.0
const VOLUME_DB_STEP := 4.0
const VOLUME_PRESS := 0.014

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
var intro_playing := true
var spin_locked := false
var _menu_moved := false
var _opening := false

@onready var _camera: Camera3D = $"../Camera3D"
@onready var _player: CharacterBody2D = $ScreenViewport/PlatformMinigame/PlayerPlatform
@onready var _platform: Node2D = $ScreenViewport/PlatformMinigame
@onready var _game_select: Node2D = $ScreenViewport/GameSelect
@onready var _wire: Node3D = $Back/Mainboard/Wire
@onready var _energy_label: Label = $ScreenViewport/ScreenHud/EnergyLabel
@onready var _batteries: Array[MeshInstance3D] = [$BatteryLeft, $BatteryRight]
@onready var _screwdriver: Node3D = $Screwdriver
@onready var _volume_plus: MeshInstance3D = $Side/VolumePlus
@onready var _volume_minus: MeshInstance3D = $Side/VolumeMinus
@onready var _volume_pips: Array[MeshInstance3D] = [
	$Side/VolumeMeter/Pip0,
	$Side/VolumeMeter/Pip1,
	$Side/VolumeMeter/Pip2,
	$Side/VolumeMeter/Pip3,
	$Side/VolumeMeter/Pip4,
]

var _bodies: Dictionary = {}
var _hovered: MeshInstance3D
var _overlay_white: StandardMaterial3D
var _overlay_green: StandardMaterial3D
var _overlay_red: StandardMaterial3D
var _burned: StandardMaterial3D
var _shake := 0.0
var _rest_position := Vector3.ZERO
var _volume_db := VOLUME_DB_MAX
var _volume_pip_on: StandardMaterial3D
var _volume_rest: Dictionary = {}
var _volume_tweens: Dictionary = {}
var _hold_layer: CanvasLayer
var _capture: SubViewport


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
	_volume_pip_on = StandardMaterial3D.new()
	_volume_pip_on.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_volume_pip_on.albedo_color = Color(0.55, 0.95, 0.4)
	_volume_pip_on.emission_enabled = true
	_volume_pip_on.emission = Color(0.4, 0.85, 0.3)
	_volume_pip_on.emission_energy_multiplier = 1.2
	_volume_rest[_volume_plus] = _volume_plus.position
	_volume_rest[_volume_minus] = _volume_minus.position
	_volume_db = _volume_db_from_bus()
	_apply_master_volume()
	_refresh_volume_pips()
	_add_blocker($Body, Vector3(1.5, 2.3, 0.5))
	_game_select.set_shown(false)
	_platform.begin()
	_platform.visible = true
	_platform.process_mode = Node.PROCESS_MODE_INHERIT
	for battery in _batteries:
		battery.removed.connect(_refresh_energy)
		battery.inserted.connect(_refresh_energy)
	_refresh_energy()
	_rest_position = position
	_capture = SubViewport.new()
	_capture.name = "CaptureViewport"
	_capture.size = Vector2i(1280, 720)
	_capture.disable_3d = true
	_capture.handle_input_locally = false
	_capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_capture)


func place_batteries_out() -> void:
	_batteries[0].place_out(Vector3(-1.22, -0.35, 0.02))
	_batteries[1].place_out(Vector3(-1.22, -1.05, 0.02))
	for battery in _batteries:
		battery.set_shown(false)
	_refresh_energy()


func reveal_batteries() -> void:
	for battery in _batteries:
		if not battery.installed:
			battery.set_shown(true)


func _process(frame_delta: float) -> void:
	if intro_playing:
		return
	_update_shake(frame_delta)
	_keyboard_yaw(frame_delta)
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
		_menu_moved = false
		if _opening or _menu_is_open():
			_player.move_axis = Vector2.ZERO
		else:
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
		if _adjust_volume(mouse):
			_pressing_button = true
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
	if spin_locked:
		return
	var yaw: float = -delta.x * sensitivity
	rotation = Vector3(0.0, rotation.y + yaw, 0.0)


func _keyboard_yaw(frame_delta: float) -> void:
	if spin_locked:
		return
	var direction := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0
	if direction == 0.0:
		return
	rotation = Vector3(0.0, rotation.y + direction * 1.8 * frame_delta, 0.0)


func _refresh_energy() -> void:
	var installed := 0
	for battery in _batteries:
		if battery.installed:
			installed += 1
	_energy_label.text = "%d%%" % (installed * 50)
	$Screen.set_powered(installed > 0)


func _try_grab_screwdriver(mouse: Vector2) -> bool:
	var hit := _ray_hit(mouse)
	if hit.is_empty():
		return false
	var pad_name := ""
	if _screwdriver.seated_pad != null:
		pad_name = _screwdriver.seated_pad.name
	if not _screwdriver.try_grab(hit.collider):
		return false
	if pad_name != "":
		_clear_short(pad_name)
	_holding_screwdriver = true
	return true


func _update_jump() -> void:
	if _opening or _menu_is_open() or _platform.is_finished():
		return
	var stuck: bool = _shorted.has("PadA")
	var wired: bool = _holding_a and _wire.is_live("PadA")
	if stuck or wired:
		_player.try_jump()


func _adjust_volume(mouse: Vector2) -> bool:
	var mesh := _mesh_under(mouse)
	if mesh != _volume_plus and mesh != _volume_minus:
		return false
	var direction := -1.0 if mesh == _volume_minus else 1.0
	_volume_db = clampf(_volume_db + direction * VOLUME_DB_STEP, VOLUME_DB_MIN, VOLUME_DB_MAX)
	_apply_master_volume()
	_refresh_volume_pips()
	_press_volume_button(mesh)
	return true


func _volume_db_from_bus() -> float:
	var bus := AudioServer.get_bus_index(MASTER_BUS)
	if bus < 0:
		return VOLUME_DB_MAX
	var db := AudioServer.get_bus_volume_db(bus)
	if is_nan(db) or is_inf(db):
		return VOLUME_DB_MIN if db < 0.0 else VOLUME_DB_MAX
	var steps := roundi((db - VOLUME_DB_MIN) / VOLUME_DB_STEP)
	return clampf(VOLUME_DB_MIN + float(steps) * VOLUME_DB_STEP, VOLUME_DB_MIN, VOLUME_DB_MAX)


func _apply_master_volume() -> void:
	var bus := AudioServer.get_bus_index(MASTER_BUS)
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, _volume_db)


func _refresh_volume_pips() -> void:
	var steps := roundi((_volume_db - VOLUME_DB_MIN) / VOLUME_DB_STEP)
	var lit := clampi(int(float(steps * _volume_pips.size()) / 10.0), 0, _volume_pips.size())
	for index in _volume_pips.size():
		_volume_pips[index].material_override = _volume_pip_on if index < lit else null


func _press_volume_button(mesh: MeshInstance3D) -> void:
	var rest: Vector3 = _volume_rest[mesh]
	var active: Tween = _volume_tweens.get(mesh)
	if active != null and active.is_valid():
		active.kill()
	mesh.position = rest
	var tween := create_tween()
	_volume_tweens[mesh] = tween
	tween.tween_property(mesh, "position", rest + Vector3(-VOLUME_PRESS, 0.0, 0.0), 0.05)
	tween.tween_property(mesh, "position", rest, 0.08)


func _press_front_button(mouse: Vector2) -> bool:
	var mesh := _mesh_under(mouse)
	if mesh == null:
		return false
	var pad_name: String = _bodies[_body_for(mesh)]["pad"]
	if pad_name == "" or pad_name == "PadDpad":
		return false
	if pad_name == "PadA" and _menu_is_open():
		if _wire.is_live("PadA") or _shorted.has("PadA"):
			_game_select.confirm()
		return true
	if pad_name == "PadA" and _platform.is_finished():
		if _wire.is_live("PadA") or _shorted.has("PadA"):
			_platform.restart()
		return true
	if pad_name == "PadA":
		_holding_a = true
	if pad_name == "PadStart":
		if _screwdriver.seated_pad != null and _screwdriver.seated_pad.name == "PadStart":
			_burn("PadStart")
		return true
	if _screwdriver.seated_pad != null and _screwdriver.seated_pad.name == pad_name:
		_burn(pad_name)
	return true


func _burn(pad_name: String) -> void:
	if _shorted.has(pad_name):
		return
	_shorted[pad_name] = true
	_wire.block_pad(pad_name)
	var hole := get_node("Back/%s/Hole" % pad_name) as MeshInstance3D
	hole.material_override = _burned
	for body in _bodies:
		var info: Dictionary = _bodies[body]
		if info["pad"] == pad_name:
			(info["mesh"] as MeshInstance3D).material_overlay = _overlay_red
	_shake = SHAKE_TIME
	_burst(pad_name)


func _clear_short(pad_name: String) -> void:
	if not _shorted.has(pad_name):
		return
	_shorted.erase(pad_name)
	_wire.unblock_pad(pad_name)
	var hole := get_node("Back/%s/Hole" % pad_name) as MeshInstance3D
	hole.material_override = null
	for body in _bodies:
		var info: Dictionary = _bodies[body]
		if info["pad"] == pad_name:
			(info["mesh"] as MeshInstance3D).material_overlay = null
	if pad_name == "PadDpad":
		_dpad_locked = false
		_locked_axis = Vector2.ZERO
		_player.move_axis = Vector2.ZERO


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
	if _opening:
		return
	if _menu_is_open():
		if not _menu_moved and (_wire.is_live("PadDpad") or _shorted.has("PadDpad")):
			if direction.y < 0.0:
				_game_select.move(-1)
			elif direction.y > 0.0:
				_game_select.move(1)
			_menu_moved = true
		return
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


func _on_game_opened(game_id: String) -> void:
	if _opening or game_id != "platform":
		return
	_opening = true
	_play_open_transition()


func _menu_is_open() -> bool:
	return is_instance_valid(_game_select) and _game_select.visible


func _play_open_transition() -> void:
	await _game_select.hide_text()
	await RenderingServer.frame_post_draw
	var from_tex := _snapshot_screen()
	freeze_screen(from_tex)
	_game_select.set_shown(false)
	_platform.begin()
	_platform.visible = true
	# #region agent log
	_agent_log("A", "open scene swapped before cover", {"platform": _platform.visible, "menu": _game_select.visible, "covers": _cover_count()})
	# #endregion
	await RenderingServer.frame_post_draw
	# #region agent log
	_agent_log("C", "screen after open swap", {"freeze_size": str(_hold_size()), "screen": str(_screen_pixel(640, 360)), "frozen": str(_tex_pixel(from_tex, 640, 360))})
	# #endregion
	var to_tex := await photograph_screen()
	await _play_pixel_transition(from_tex, to_tex)
	_opening = false
	_platform.process_mode = Node.PROCESS_MODE_INHERIT


func _return_to_menu() -> void:
	_opening = true
	_holding_a = false
	_player.move_axis = Vector2.ZERO
	var from_tex := _snapshot_screen()
	freeze_screen(from_tex)
	_platform.process_mode = Node.PROCESS_MODE_DISABLED
	_platform.visible = false
	_game_select.set_shown(true)
	# #region agent log
	_agent_log("A", "menu shown before cover", {"platform": _platform.visible, "menu": _game_select.visible, "covers": _cover_count()})
	# #endregion
	await RenderingServer.frame_post_draw
	var to_tex := await photograph_screen()
	await _play_pixel_transition(from_tex, to_tex)
	await _game_select.show_text()
	_opening = false


func _play_pixel_transition(from_tex: ImageTexture, to_tex: ImageTexture) -> void:
	var layer := _hold_layer
	var cover := layer.get_child(0) as ColorRect
	var material := cover.material as ShaderMaterial
	material.set_shader_parameter("from_tex", from_tex)
	material.set_shader_parameter("to_tex", from_tex)
	material.set_shader_parameter("progress", 0.0)
	material.set_shader_parameter("min_tiles", 24.0)
	# #region agent log
	_agent_log("B", "console cover added", {"size": str(cover.size), "progress": material.get_shader_parameter("progress")})
	# #endregion
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("progress", value), 0.0, 0.5, 1.2)
	await tween.finished
	material.set_shader_parameter("from_tex", to_tex)
	material.set_shader_parameter("to_tex", to_tex)
	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_SINE)
	reveal.set_ease(Tween.EASE_IN_OUT)
	reveal.tween_method(func(value: float) -> void: material.set_shader_parameter("progress", value), 0.5, 0.0, 1.2)
	await reveal.finished
	layer.queue_free()
	_hold_layer = null


func freeze_screen(from_tex: ImageTexture) -> void:
	_drop_hold()
	_hold_layer = _make_cover(from_tex, false)
	$ScreenViewport.add_child(_hold_layer)


func photograph_screen() -> ImageTexture:
	var screen := $ScreenViewport as SubViewport
	var moved: Array[Node] = []
	var indexes: Array[int] = []
	for child in screen.get_children():
		if child is CanvasLayer and child.layer == 20:
			continue
		moved.append(child)
		indexes.append(child.get_index())
	for child in moved:
		screen.remove_child(child)
		_capture.add_child(child)
	_capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	var image := _capture.get_texture().get_image()
	_capture.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for index in moved.size():
		var child: Node = moved[index]
		_capture.remove_child(child)
		screen.add_child(child)
		screen.move_child(child, indexes[index])
	return ImageTexture.create_from_image(image)


func _drop_hold() -> void:
	if _hold_layer != null and is_instance_valid(_hold_layer):
		_hold_layer.queue_free()
	_hold_layer = null


func _make_cover(from_tex: ImageTexture, level_blend: bool) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 20
	var cover := ColorRect.new()
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = PixelTransitionShader
	material.set_shader_parameter("from_tex", from_tex)
	material.set_shader_parameter("to_tex", from_tex)
	material.set_shader_parameter("progress", 0.0)
	if level_blend:
		material.set_shader_parameter("min_tiles", 24.0)
	cover.material = material
	layer.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return layer


func _hold_size() -> Vector2:
	if _hold_layer == null or not is_instance_valid(_hold_layer) or _hold_layer.get_child_count() == 0:
		return Vector2.ZERO
	return (_hold_layer.get_child(0) as ColorRect).size


func _screen_pixel(x: int, y: int) -> Color:
	return ($ScreenViewport as SubViewport).get_texture().get_image().get_pixel(x, y)


func _tex_pixel(tex: ImageTexture, x: int, y: int) -> Color:
	return tex.get_image().get_pixel(x, y)


func _cover_count() -> int:
	var count := 0
	for child in $ScreenViewport.get_children():
		if child is CanvasLayer and child.layer == 20:
			count += 1
	return count


func _agent_log(hypothesis_id: String, message: String, data: Dictionary) -> void:
	# #region agent log
	var path := "/home/fabvarisco/Developer/unisinos-gamejam-2026/.cursor/debug-7bc056.log"
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	file.seek_end()
	file.store_line(JSON.stringify({"sessionId": "7bc056", "hypothesisId": hypothesis_id, "location": "console.gd", "message": message, "data": data, "timestamp": Time.get_ticks_msec()}))
	file.close()
	# #endregion


func _snapshot_screen() -> ImageTexture:
	var image := ($ScreenViewport as SubViewport).get_texture().get_image()
	return ImageTexture.create_from_image(image)


func _add_blocker(host: Node3D, box_size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	body.add_child(shape)
	host.add_child(body)


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
