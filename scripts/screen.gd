extends MeshInstance3D

@export var viewport_path: NodePath = ^"../ScreenViewport"


func _ready() -> void:
	var viewport := get_node(viewport_path) as SubViewport
	for _frame in 2:
		await get_tree().process_frame
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = viewport.get_texture()
	material_override = material
