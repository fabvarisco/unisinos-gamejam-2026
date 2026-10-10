extends CharacterBody2D

const SPEED := 110.0
const _FRAMES: Array[Rect2] = [
	Rect2(0, 272, 16, 16),
	Rect2(17, 272, 16, 16),
	Rect2(34, 272, 16, 16),
	Rect2(51, 272, 16, 16),
]

var left_limit := 0.0
var right_limit := 0.0

var _direction := 1.0
var _anim_time := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(4, 4)
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://Assets/platformer/monochrome_tilemap.png")
	atlas.region = _FRAMES[0]
	sprite.texture = atlas
	_sprite = sprite
	var material := ShaderMaterial.new()
	material.shader = load("res://minigames/platform/chromaPlatform.gdshader")
	sprite.material = material
	add_child(sprite)
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 50)
	shape_node.shape = shape
	add_child(shape_node)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	area.body_entered.connect(_on_body_entered)
	var area_shape := CollisionShape2D.new()
	var area_box := RectangleShape2D.new()
	area_box.size = Vector2(40, 44)
	area_shape.shape = area_box
	area.add_child(area_shape)
	add_child(area)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 1400.0 * delta
	velocity.x = _direction * SPEED
	move_and_slide()
	_anim_time += delta
	var atlas := _sprite.texture as AtlasTexture
	atlas.region = _FRAMES[int(_anim_time / 0.18) % _FRAMES.size()]
	_sprite.texture = atlas
	_sprite.flip_h = _direction < 0.0
	if global_position.x < left_limit:
		_direction = 1.0
	elif global_position.x > right_limit:
		_direction = -1.0
	for index in get_slide_collision_count():
		var normal := get_slide_collision(index).get_normal()
		if absf(normal.x) > 0.5:
			_direction = signf(normal.x)
			break


func _on_body_entered(body: Node) -> void:
	if not body.has_method("respawn") or not bool(body.call("respawn")):
		return
	var game := get_parent()
	if game.has_method("play_enemy"):
		game.play_enemy()
