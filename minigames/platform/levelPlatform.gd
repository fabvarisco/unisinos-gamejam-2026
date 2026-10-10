extends TileMapLayer

const GROUND := Vector2i(1, 8)
const GOAL := Vector2i(15, 18)


func _ready() -> void:
	tile_set = _make_tileset()


func load_level(index: int) -> void:
	clear()
	for x in 20:
		set_cell(Vector2i(x, 10), 0, GROUND)
	if index == 2 or index == 3:
		set_cell(Vector2i(10, 9), 0, GROUND)
	set_cell(Vector2i(18, 9), 0, GOAL)
	set_cell(Vector2i(18, 8), 0, GOAL)


func _make_tileset() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	tiles.add_physics_layer()
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://Assets/platformer/monochrome_tilemap.png")
	atlas.texture_region_size = Vector2i(16, 16)
	atlas.separation = Vector2i(1, 1)
	tiles.add_source(atlas, 0)
	for coord in [GROUND, GOAL]:
		atlas.create_tile(coord)
		var data := atlas.get_tile_data(coord, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
		]))
	return tiles
