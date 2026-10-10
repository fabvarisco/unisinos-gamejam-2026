extends MeshInstance3D

@export var viewport_path: NodePath = ^"../ScreenViewport"

var _powered := false
var _live: StandardMaterial3D
var _off: StandardMaterial3D


func _ready() -> void:
	var viewport := get_node(viewport_path) as SubViewport
	for _frame in 2:
		await get_tree().process_frame
	_off = StandardMaterial3D.new()
	_off.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_off.albedo_color = Color(0.01, 0.01, 0.01)
	_live = StandardMaterial3D.new()
	_live.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_live.albedo_texture = viewport.get_texture()
	_apply()


func set_powered(on: bool) -> void:
	_powered = on
	_apply()


func _apply() -> void:
	if _live == null:
		return
	material_override = _live if _powered else _off
