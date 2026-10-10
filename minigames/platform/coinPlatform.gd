extends Area2D

signal collected

const _REGION := Rect2(34, 0, 16, 16)

var _origin_y := 0.0
var _time := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	_origin_y = position.y
	body_entered.connect(_on_body_entered)
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(4, 4)
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://Assets/platformer/monochrome_tilemap.png")
	atlas.region = _REGION
	sprite.texture = atlas
	var material := ShaderMaterial.new()
	material.shader = load("res://minigames/platform/chromaPlatform.gdshader")
	sprite.material = material
	add_child(sprite)
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	shape_node.shape = shape
	add_child(shape_node)


func _process(delta: float) -> void:
	_time += delta
	position.y = _origin_y + sin(_time * 3.0) * 6.0


func _on_body_entered(body: Node) -> void:
	if not body.has_method("respawn"):
		return
	collected.emit()
	queue_free()
