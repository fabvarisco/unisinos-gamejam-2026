extends MeshInstance3D

signal removed
signal inserted

var installed := true
var held := false

var _home := Transform3D.IDENTITY
var _grab: StaticBody3D
var _was_installed := false


func _ready() -> void:
	_home = transform
	_grab = StaticBody3D.new()
	_grab.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (mesh as BoxMesh).size + Vector3(0.06, 0.06, 0.1)
	shape_node.shape = box
	_grab.add_child(shape_node)
	add_child(_grab)


func try_grab(collider: Object) -> bool:
	if installed or not visible or collider != _grab:
		return false
	held = true
	_was_installed = false
	return true


func place_out(local_origin: Vector3) -> void:
	installed = false
	transform.origin = local_origin
	set_shown(true)


func set_shown(on: bool) -> void:
	visible = on
	_grab.collision_layer = 1 if on and not installed else 0


func drag_to(world_point: Vector3) -> void:
	if not held:
		return
	var console := get_parent() as Node3D
	var local := console.to_local(world_point)
	local.x = clampf(local.x, -0.7, 0.7)
	local.y = clampf(local.y, -1.15, 0.85)
	local.z = _home.origin.z
	transform.basis = _home.basis
	transform.origin = local


func release() -> void:
	if not held:
		return
	held = false
	var offset := transform.origin - _home.origin
	offset.z = 0.0
	if offset.length() <= 0.22:
		transform = _home
		installed = true
		set_shown(true)
		inserted.emit()
		return
	installed = false
	if _was_installed:
		set_shown(false)
		removed.emit()
		return
	set_shown(true)


func follow_point(mouse: Vector2, camera: Camera3D) -> Vector3:
	var console := get_parent() as Node3D
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var plane_point := console.to_global(Vector3(0.0, 0.0, _home.origin.z))
	var plane_normal := console.global_transform.basis.z
	var denom := plane_normal.dot(direction)
	if absf(denom) < 0.0001:
		return global_position
	var t := plane_normal.dot(plane_point - origin) / denom
	if t < 0.0:
		return global_position
	return origin + direction * t
