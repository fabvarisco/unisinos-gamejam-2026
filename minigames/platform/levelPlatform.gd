extends TileMapLayer

const GROUND := Vector2i(1, 8)
const PIPE_LEFT := Vector2i(0, 10)
const PIPE_MID := Vector2i(1, 10)
const PIPE_RIGHT := Vector2i(2, 10)
const GOAL := Vector2i(15, 18)

var _goal := Vector2i(18, 9)


func _ready() -> void:
	tile_set = _make_tileset()


func goal_cell() -> Vector2i:
	return _goal


func load_level(index: int) -> void:
	clear()
	match index:
		1:
			_level_steps()
		2:
			_level_pit()
		3:
			_level_stairs()
		4:
			_level_pipes()
		5:
			_level_islands()
		6:
			_level_final()
		7:
			_level_gaps()
		8:
			_level_stairs_tight()
		_:
			_level_pillars()


func _level_steps() -> void:
	_row(0, 19, 10, GROUND)
	_row(5, 6, 9, GROUND)
	_row(11, 12, 9, GROUND)
	_row(15, 16, 9, GROUND)
	_cell(16, 8, GROUND)
	_goal_at(18, 9)


func _level_pit() -> void:
	_row(0, 7, 10, GROUND)
	_row(10, 19, 10, GROUND)
	_row(8, 9, 9, GROUND)
	_goal_at(18, 9)


func _level_stairs() -> void:
	_row(0, 19, 10, GROUND)
	_row(4, 5, 9, GROUND)
	_row(6, 7, 8, GROUND)
	_row(8, 9, 7, GROUND)
	_cell(17, 9, GROUND)
	_goal_at(18, 9)


func _level_pipes() -> void:
	_row(0, 11, 10, GROUND)
	_row(14, 19, 10, GROUND)
	_cell(4, 9, PIPE_MID)
	_cell(7, 9, PIPE_LEFT)
	_cell(8, 9, PIPE_RIGHT)
	_row(12, 13, 9, GROUND)
	_goal_at(18, 9)


func _level_islands() -> void:
	_row(0, 3, 10, GROUND)
	_row(5, 7, 9, GROUND)
	_row(9, 11, 8, GROUND)
	_row(13, 15, 9, GROUND)
	_row(17, 19, 10, GROUND)
	_goal_at(18, 10)


func _level_gaps() -> void:
	_row(0, 2, 10, GROUND)
	_cell(5, 10, GROUND)
	_cell(8, 10, GROUND)
	_cell(11, 10, GROUND)
	_cell(14, 10, GROUND)
	_row(17, 19, 10, GROUND)
	_goal_at(18, 10)


func _level_stairs_tight() -> void:
	_row(0, 2, 10, GROUND)
	_cell(4, 9, GROUND)
	_cell(6, 8, GROUND)
	_cell(8, 7, GROUND)
	_cell(10, 8, GROUND)
	_cell(13, 8, GROUND)
	_cell(15, 9, GROUND)
	_row(17, 19, 10, GROUND)
	_goal_at(18, 10)


func _level_pillars() -> void:
	_row(0, 2, 10, GROUND)
	_cell(5, 10, GROUND)
	_cell(8, 10, GROUND)
	_cell(11, 10, GROUND)
	_cell(14, 10, GROUND)
	_goal_at(17, 10)


func _level_final() -> void:
	_row(0, 5, 10, GROUND)
	_row(6, 7, 9, GROUND)
	_row(8, 13, 10, GROUND)
	_row(14, 15, 9, GROUND)
	_row(16, 19, 10, GROUND)
	_goal_at(18, 10)


func _goal_at(x: int, y: int) -> void:
	_goal = Vector2i(x, y)
	set_cell(_goal, 0, GOAL)


func _cell(x: int, y: int, tile: Vector2i) -> void:
	set_cell(Vector2i(x, y), 0, tile)


func _row(x0: int, x1: int, y: int, tile: Vector2i) -> void:
	for x in range(x0, x1 + 1):
		_cell(x, y, tile)


func _make_tileset() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	tiles.add_physics_layer()
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://Assets/platformer/monochrome_tilemap.png")
	atlas.texture_region_size = Vector2i(16, 16)
	atlas.separation = Vector2i(1, 1)
	tiles.add_source(atlas, 0)
	for coord in [GROUND, PIPE_LEFT, PIPE_MID, PIPE_RIGHT, GOAL]:
		atlas.create_tile(coord)
		var data := atlas.get_tile_data(coord, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
		]))
	return tiles
