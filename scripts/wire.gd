extends Node3D

@export var anchor := Vector3(0.14, 0.0, -0.02)
@export var snap_distance := 0.16
@export var point_count := 12
@export var rope_length := 0.62
@export var gravity := 6.0

var held := false

@onready var _tip: Node3D = $Tip
@onready var _segment: MeshInstance3D = $Segment
@onready var _grab: StaticBody3D = $Tip/Grab

var _points: PackedVector3Array = PackedVector3Array()
var _previous: PackedVector3Array = PackedVector3Array()
var _segments: Array[MeshInstance3D] = []
var _spacing := 0.05
var _plugged := false
var _pinned := Vector3.ZERO
var connected_pad: Node3D = null
var _battery_nodes: Array[Node3D] = []


func _ready() -> void:
	_spacing = rope_length / float(point_count - 1)
	_points.resize(point_count)
	_previous.resize(point_count)
	var end := _tip.position
	for i in point_count:
		var t := float(i) / float(point_count - 1)
		var point := anchor.lerp(end, t)
		point.y -= sin(t * PI) * 0.08
		point.z = anchor.z
		_points[i] = point
		_previous[i] = point
	var console := get_parent().get_parent().get_parent()
	for battery_name in ["BatteryLeft", "BatteryRight"]:
		_battery_nodes.append(console.get_node(battery_name))
	_segment.visible = false
	for _i in point_count - 1:
		var piece := _segment.duplicate() as MeshInstance3D
		piece.visible = true
		add_child(piece)
		_segments.append(piece)
	_sync_tip()
	_redraw()


func _process(delta: float) -> void:
	_simulate(delta)
	_sync_tip()
	_redraw()


func try_grab(mouse: Vector2, camera: Camera3D) -> bool:
	var hit := _raycast(mouse, camera)
	if hit.is_empty() or hit.collider != _grab:
		return false
	held = true
	_plugged = false
	connected_pad = null
	drag(mouse, camera)
	return true


func drag(mouse: Vector2, camera: Camera3D) -> void:
	if not held:
		return
	_pinned = _clamp_to_board(to_local(_plane_hit(mouse, camera)))
	var last := point_count - 1
	_points[last] = _pinned
	_previous[last] = _pinned


func release() -> void:
	if not held:
		return
	held = false
	var pad := _nearest_pad()
	if pad == null:
		connected_pad = null
		return
	connected_pad = pad
	_plugged = true
	var local := to_local(pad.global_position)
	_pinned = _clamp_to_board(local)
	var last := point_count - 1
	_points[last] = _pinned
	_previous[last] = _pinned


func _simulate(delta: float) -> void:
	var step := Vector3(0.0, -gravity, 0.0) * delta * delta
	var last := point_count - 1
	var pin_end := held or _plugged
	var boxes := _battery_boxes()
	for i in range(1, point_count):
		if i == last and pin_end:
			_points[i] = _pinned
			_previous[i] = _pinned
			continue
		var current := _points[i]
		var velocity := (current - _previous[i]) * 0.985
		_previous[i] = current
		_points[i] = _outside_batteries(_clamp_to_board(current + velocity + step), boxes, i)
	for _iteration in 8:
		_points[0] = anchor
		for i in point_count - 1:
			var delta_point := _points[i + 1] - _points[i]
			var distance := delta_point.length()
			if distance < 0.0001:
				continue
			var correction := delta_point * ((distance - _spacing) / distance) * 0.5
			if i > 0:
				_points[i] += correction
			if i + 1 < last or not pin_end:
				_points[i + 1] -= correction
			else:
				_points[i] += correction
		_points[0] = anchor
		if pin_end:
			_points[last] = _pinned
		for i in range(1, point_count):
			_points[i] = _outside_batteries(_clamp_to_board(_points[i]), boxes, i)


func _battery_boxes() -> Array[AABB]:
	var boxes: Array[AABB] = []
	var to_wire := global_transform.affine_inverse()
	for battery in _battery_nodes:
		if not battery.visible or battery.get("installed") == false:
			continue
		var half := ((battery as MeshInstance3D).mesh as BoxMesh).size * 0.5
		var to_local_wire := to_wire * battery.global_transform
		var box := AABB()
		var started := false
		for x in [-half.x, half.x]:
			for y in [-half.y, half.y]:
				for z in [-half.z, half.z]:
					var corner := to_local_wire * Vector3(x, y, z)
					if not started:
						box = AABB(corner, Vector3.ZERO)
						started = true
					else:
						box = box.expand(corner)
		boxes.append(box)
	return boxes


func _outside_batteries(point: Vector3, boxes: Array[AABB], index: int) -> Vector3:
	var margin := 0.034 if index == point_count - 1 else 0.014
	for _pass in 2:
		for box in boxes:
			point = _push_out_xy(point, box, margin)
	return _clamp_to_board(point)


func _push_out_xy(point: Vector3, box: AABB, margin: float) -> Vector3:
	var min_x := box.position.x - margin
	var max_x := box.position.x + box.size.x + margin
	var min_y := box.position.y - margin
	var max_y := box.position.y + box.size.y + margin
	if point.x <= min_x or point.x >= max_x or point.y <= min_y or point.y >= max_y:
		return point
	var up := max_y - point.y
	var down := point.y - min_y
	var left := point.x - min_x
	var right := max_x - point.x
	if up <= down and up <= left and up <= right:
		point.y = max_y
	elif down <= left and down <= right:
		point.y = min_y
	elif left <= right:
		point.x = min_x
	else:
		point.x = max_x
	return point


func _clamp_to_board(point: Vector3) -> Vector3:
	point.x = clampf(point.x, -0.55, 0.55)
	point.y = clampf(point.y, -1.05, 0.75)
	point.z = anchor.z
	return point


func _sync_tip() -> void:
	_tip.position = _points[point_count - 1]


func is_live(pad_name: String) -> bool:
	return connected_pad != null and connected_pad.name == pad_name


func _nearest_pad() -> Node3D:
	var back := get_parent().get_parent()
	var best: Node3D = null
	var best_distance := snap_distance
	for child in back.get_children():
		if not str(child.name).begins_with("Pad"):
			continue
		var distance := _tip.global_position.distance_to(child.global_position)
		if distance < best_distance:
			best_distance = distance
			best = child
	return best


func _plane_hit(mouse: Vector2, camera: Camera3D) -> Vector3:
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var plane_normal := global_transform.basis.z
	var denom := plane_normal.dot(direction)
	if absf(denom) < 0.0001:
		return _tip.global_position
	var t := plane_normal.dot(global_position - origin) / denom
	if t < 0.0:
		return _tip.global_position
	return origin + direction * t


func _raycast(mouse: Vector2, camera: Camera3D) -> Dictionary:
	var origin := camera.project_ray_origin(mouse)
	var end := origin + camera.project_ray_normal(mouse) * 100.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	return camera.get_world_3d().direct_space_state.intersect_ray(query)


func _redraw() -> void:
	for i in _segments.size():
		var from: Vector3 = _points[i]
		var to: Vector3 = _points[i + 1]
		var offset := to - from
		var length := offset.length()
		if length < 0.001:
			continue
		var x_axis := offset / length
		var up := Vector3.UP
		if absf(x_axis.dot(up)) > 0.99:
			up = Vector3.FORWARD
		var y_axis := up.cross(x_axis).normalized()
		var z_axis := x_axis.cross(y_axis).normalized()
		_segments[i].transform = Transform3D(Basis(x_axis * length, y_axis, z_axis), (from + to) * 0.5)
