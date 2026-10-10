extends MeshInstance3D

const CrtShader := preload("res://shaders/crt.gdshader")

@export var viewport_path: NodePath = ^"../ScreenViewport"

var _powered := false
var _live: ShaderMaterial
var _off: StandardMaterial3D


func _ready() -> void:
	var viewport := get_node(viewport_path) as SubViewport
	for _frame in 2:
		await get_tree().process_frame
	_off = StandardMaterial3D.new()
	_off.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_off.albedo_color = Color(0.01, 0.01, 0.01)
	_live = ShaderMaterial.new()
	_live.shader = CrtShader
	_live.set_shader_parameter("screen_tex", viewport.get_texture())
	_apply()


func set_powered(on: bool) -> void:
	_powered = on
	_apply()


func _apply() -> void:
	if _live == null:
		return
	material_override = _live if _powered else _off
