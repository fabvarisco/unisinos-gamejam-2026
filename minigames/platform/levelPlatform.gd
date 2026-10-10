extends TileMapLayer

const GROUND := Vector2i(1, 8)


func _ready() -> void:
	tile_set = _make_tileset()
	_paint()


func _make_tileset() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	tiles.add_physics_layer()
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://Assets/platformer/monochrome_tilemap.png")
	atlas.texture_region_size = Vector2i(16, 16)
	atlas.separation = Vector2i(1, 1)
	tiles.add_source(atlas, 0)
	atlas.create_tile(GROUND)
	var data := atlas.get_tile_data(GROUND, 0)
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	]))
	return tiles


func _paint() -> void:
	for x in 20:
		if x >= 7 and x <= 12:
			continue
		set_cell(Vector2i(x, 10), 0, GROUND)
	for x in range(5, 9):
		set_cell(Vector2i(x, 7), 0, GROUND)
	for x in range(11, 16):
		set_cell(Vector2i(x, 5), 0, GROUND)
