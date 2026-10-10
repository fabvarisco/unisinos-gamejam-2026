extends Node3D

const TIP := Vector3(0.23, 0.0, 0.0)
const SNAP_DISTANCE := 0.22

var held := false
var seated_pad: Node3D = null

var _grab: StaticBody3D


func _ready() -> void:
	_grab = StaticBody3D.new()
	_grab.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.36, 0.07, 0.07)
	shape_node.shape = box
	shape_node.position = Vector3(0.09, 0.0, 0.0)
	_grab.add_child(shape_node)
	add_child(_grab)


func try_grab(collider: Object) -> bool:
	if collider != _grab:
		return false
	held = true
	seated_pad = null
	return true


func drag_to(world_point: Vector3) -> void:
	if not held:
		return
	global_position = world_point


func release() -> void:
	if not held:
		return
	held = false
	var pad := _nearest_pad()
	seated_pad = pad
	if pad == null:
		return
	var console := get_parent() as Node3D
	global_position = pad.global_position - global_transform.basis * TIP
	global_position -= console.global_transform.basis.z * 0.05


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


func _nearest_pad() -> Node3D:
	var back := get_parent().get_node("Back")
	var tip := global_transform * TIP
	var best: Node3D = null
	var best_distance := SNAP_DISTANCE
	for child in back.get_children():
		if not str(child.name).begins_with("Pad"):
			continue
		var distance := tip.distance_to(child.global_position)
		if distance < best_distance:
			best_distance = distance
			best = child
	return best
