extends MeshInstance3D

signal removed

var installed := true
var held := false

var _home := Transform3D.IDENTITY
var _grab: StaticBody3D


func _ready() -> void:
	_home = transform
	_grab = StaticBody3D.new()
	_grab.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (mesh as BoxMesh).size
	shape_node.shape = box
	_grab.add_child(shape_node)
	add_child(_grab)


func try_grab(collider: Object) -> bool:
	if not installed or collider != _grab:
		return false
	held = true
	return true


func drag_to(world_point: Vector3) -> void:
	if not held:
		return
	transform.origin = (get_parent() as Node3D).to_local(world_point)


func release() -> void:
	if not held:
		return
	held = false
	if transform.origin.distance_to(_home.origin) > 0.45:
		installed = false
		visible = false
		_grab.collision_layer = 0
		removed.emit()
		return
	transform = _home


func follow_point(mouse: Vector2, camera: Camera3D) -> Vector3:
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var plane_normal := -camera.global_transform.basis.z
	var denom := plane_normal.dot(direction)
	if absf(denom) < 0.0001:
		return global_position
	var t := plane_normal.dot(global_position - origin) / denom
	if t < 0.0:
		return global_position
	return origin + direction * t
