extends Node2D

const SPAWN := Vector2(160, 607)
const LEVEL_COUNT := 9
const _SFX_GAIN := 0.55
const MonsterScript := preload("res://minigames/platform/monsterPlatform.gd")
const CoinScript := preload("res://minigames/platform/coinPlatform.gd")
const PixelTransitionShader := preload("res://shaders/pixel_transition.gdshader")
const _JUMP_SFX: AudioStream = preload("res://minigames/platform/audio/jump.wav")
const _COIN_SFX: AudioStream = preload("res://minigames/platform/audio/coin.wav")
const _ENEMY_SFX: AudioStream = preload("res://minigames/platform/audio/enemy.wav")
const _LEVEL_SFX: AudioStream = preload("res://minigames/platform/audio/level_complete.wav")
const _GAME_SFX: AudioStream = preload("res://minigames/platform/audio/game_complete.wav")

var _level := 1
var _done := false
var _switching := false
var _started_msec := 0
var _run := 0
var _coins := 0
var _level_coins := 0
var _hold_layer: CanvasLayer
var _jump_player: AudioStreamPlayer
var _coin_player: AudioStreamPlayer
var _enemy_player: AudioStreamPlayer
var _level_player: AudioStreamPlayer
var _game_player: AudioStreamPlayer

@onready var _level_map: TileMapLayer = $LevelPlatform
@onready var _player: CharacterBody2D = $PlayerPlatform
@onready var _end_screen: Control = $Hud/EndScreen
@onready var _deaths_label: Label = $Hud/EndScreen/Deaths
@onready var _coins_end_label: Label = $Hud/EndScreen/Coins
@onready var _time_label: Label = $Hud/EndScreen/Time
@onready var _coins_label: Label = $Hud/Coins


func _ready() -> void:
	_jump_player = _add_sfx(_JUMP_SFX)
	_coin_player = _add_sfx(_COIN_SFX)
	_enemy_player = _add_sfx(_ENEMY_SFX)
	_level_player = _add_sfx(_LEVEL_SFX)
	_game_player = _add_sfx(_GAME_SFX)


func _add_sfx(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(_SFX_GAIN)
	add_child(player)
	return player


func play_jump() -> void:
	_jump_player.play()


func play_enemy() -> void:
	_enemy_player.play()


func begin() -> void:
	_run += 1
	_switching = false
	_done = false
	_clear_transition()
	_player.deaths = 0
	_coins = 0
	_refresh_coins()
	_player.move_axis = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_started_msec = Time.get_ticks_msec()
	_end_screen.visible = false
	_start_level(1)


func is_finished() -> bool:
	return _done and not _switching


func restart() -> void:
	if not is_finished():
		return
	_switching = true
	_restart_from_ending()


func _restart_from_ending() -> void:
	var run := _run
	_set_actors_active(false)
	var from_tex := _snapshot()
	_freeze(from_tex)
	_done = false
	_player.deaths = 0
	_coins = 0
	_refresh_coins()
	_player.move_axis = Vector2.ZERO
	_started_msec = Time.get_ticks_msec()
	_end_screen.visible = false
	_start_level(1)
	_set_actors_active(false)
	# #region agent log
	_agent_log("A", "restart level shown before cover", {"level": _level, "end": _end_screen.visible, "covers": _cover_count()})
	# #endregion
	await RenderingServer.frame_post_draw
	if run != _run:
		return
	var to_tex := await _photograph()
	await _play_pixel(from_tex, to_tex)
	if run != _run:
		return
	_switching = false
	_player.velocity = Vector2.ZERO
	_set_actors_active(true)


func _clear_transition() -> void:
	for child in get_children():
		if child is CanvasLayer and child.layer == 20:
			child.queue_free()


func _start_level(index: int) -> void:
	_level = index
	for child in get_children():
		if child.get_script() == MonsterScript or child.get_script() == CoinScript:
			child.queue_free()
	_level_map.load_level(index)
	_place_goal(_level_map.goal_cell())
	_player.set_spawn(SPAWN)
	for cell in _coin_cells(index):
		_add_coin(_above(cell))
	for patrol in _patrols(index):
		_add_monster(patrol.x, patrol.y, patrol.z)
	_level_coins = _coins


func reload_level() -> void:
	if _switching or _done:
		return
	_coins = _level_coins
	_refresh_coins()
	_player.move_axis = Vector2.ZERO
	_start_level(_level)


func _coin_cells(index: int) -> Array[Vector2i]:
	match index:
		1:
			return [Vector2i(6, 9), Vector2i(12, 9), Vector2i(16, 8)]
		2:
			return [Vector2i(8, 9), Vector2i(9, 9), Vector2i(14, 10)]
		3:
			return [Vector2i(5, 9), Vector2i(7, 8), Vector2i(9, 7)]
		4:
			return [Vector2i(8, 9), Vector2i(12, 9), Vector2i(16, 10)]
		5:
			return [Vector2i(6, 9), Vector2i(10, 8), Vector2i(14, 9)]
		6:
			return [Vector2i(6, 9), Vector2i(11, 10), Vector2i(14, 9)]
		7:
			return [Vector2i(5, 10), Vector2i(8, 10), Vector2i(11, 10), Vector2i(14, 10)]
		8:
			return [Vector2i(6, 8), Vector2i(8, 7), Vector2i(10, 8), Vector2i(13, 8)]
		_:
			return [Vector2i(5, 10), Vector2i(8, 10), Vector2i(11, 10), Vector2i(14, 10)]


func _patrols(index: int) -> Array[Vector3]:
	match index:
		3:
			return [Vector3(800, 660, 1040)]
		6:
			return [Vector3(280, 200, 360), Vector3(700, 530, 860)]
		_:
			return []


func _above(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * 64 + 32, cell.y * 64 - 48)


func _place_goal(cell: Vector2i) -> void:
	var goal := $Goal as Area2D
	var shape_node := $Goal/CollisionShape2D as CollisionShape2D
	shape_node.position = Vector2.ZERO
	(shape_node.shape as RectangleShape2D).size = Vector2(48, 72)
	goal.position = Vector2(cell.x * 64 + 32, cell.y * 64 - 20)


func _add_coin(spot: Vector2) -> void:
	var coin := Area2D.new()
	coin.set_script(CoinScript)
	coin.position = spot
	coin.collected.connect(_on_coin_collected)
	add_child(coin)


func _on_coin_collected() -> void:
	_coins += 1
	_refresh_coins()
	_coin_player.play()


func _refresh_coins() -> void:
	_coins_label.text = "Moedas: %d" % _coins
	_coins_end_label.text = "Coins: %d" % _coins


func _add_monster(x: float, left: float, right: float) -> void:
	var monster := CharacterBody2D.new()
	monster.set_script(MonsterScript)
	monster.position = Vector2(x, SPAWN.y)
	monster.left_limit = left
	monster.right_limit = right
	add_child(monster)


func notify_goal() -> void:
	if _done or _switching:
		return
	_switching = true
	_change_level()


func _change_level() -> void:
	var run := _run
	_set_actors_active(false)
	var from_tex := _snapshot()
	_freeze(from_tex)
	if _level >= LEVEL_COUNT:
		_done = true
		_game_player.play()
		_show_ending()
		_player.velocity = Vector2.ZERO
	else:
		_level_player.play()
		_start_level(_level + 1)
		_set_actors_active(false)
	# #region agent log
	_agent_log("A", "next level shown before cover", {"level": _level, "end": _end_screen.visible, "covers": _cover_count()})
	# #endregion
	await RenderingServer.frame_post_draw
	# #region agent log
	_agent_log("C", "screen after level swap", {"freeze_size": str(_hold_size()), "screen": str(_screen_pixel(200, 200)), "frozen": str(_tex_pixel(from_tex, 200, 200))})
	# #endregion
	# #region agent log
	_agent_log("E", "block pixel after level swap", {"screen": str(_screen_pixel(672, 608)), "frozen": str(_tex_pixel(from_tex, 672, 608))})
	# #endregion
	if run != _run:
		return
	var to_tex := await _photograph()
	await _play_pixel(from_tex, to_tex)
	if run != _run:
		return
	_switching = false
	if _done:
		return
	_player.velocity = Vector2.ZERO
	_set_actors_active(true)


func _set_actors_active(active: bool) -> void:
	_player.set_physics_process(active)
	if not active:
		_player.velocity = Vector2.ZERO
	for child in get_children():
		if child.get_script() == MonsterScript:
			child.set_physics_process(active)


func _show_ending() -> void:
	var elapsed := int((Time.get_ticks_msec() - _started_msec) / 1000.0)
	var minutes := elapsed / 60
	var seconds := elapsed % 60
	_deaths_label.text = "Deaths: %d" % _player.deaths
	_refresh_coins()
	_time_label.text = "Time: %d:%02d" % [minutes, seconds]
	_end_screen.visible = true


func _cover_count() -> int:
	var count := 0
	for child in get_children():
		if child is CanvasLayer and child.layer == 20:
			count += 1
	return count


func _hold_size() -> Vector2:
	if _hold_layer == null or not is_instance_valid(_hold_layer) or _hold_layer.get_child_count() == 0:
		return Vector2.ZERO
	return (_hold_layer.get_child(0) as ColorRect).size


func _screen_pixel(x: int, y: int) -> Color:
	return get_viewport().get_texture().get_image().get_pixel(x, y)


func _tex_pixel(tex: ImageTexture, x: int, y: int) -> Color:
	return tex.get_image().get_pixel(x, y)


func _agent_log(hypothesis_id: String, message: String, data: Dictionary) -> void:
	# #region agent log
	var path := "/home/fabvarisco/Developer/unisinos-gamejam-2026/.cursor/debug-7bc056.log"
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	file.seek_end()
	file.store_line(JSON.stringify({"sessionId": "7bc056", "hypothesisId": hypothesis_id, "location": "platformMinigame.gd", "message": message, "data": data, "timestamp": Time.get_ticks_msec()}))
	file.close()
	# #endregion


func _freeze(from_tex: ImageTexture) -> void:
	if _hold_layer != null and is_instance_valid(_hold_layer):
		_hold_layer.queue_free()
	_hold_layer = CanvasLayer.new()
	_hold_layer.layer = 20
	var cover := ColorRect.new()
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = PixelTransitionShader
	material.set_shader_parameter("from_tex", from_tex)
	material.set_shader_parameter("to_tex", from_tex)
	material.set_shader_parameter("progress", 0.0)
	cover.material = material
	_hold_layer.add_child(cover)
	add_child(_hold_layer)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _photograph() -> ImageTexture:
	var screen := get_viewport() as SubViewport
	var host := screen.get_parent()
	if _hold_layer != null and is_instance_valid(_hold_layer) and _hold_layer.get_parent() == self:
		remove_child(_hold_layer)
		screen.add_child(_hold_layer)
	var tex: ImageTexture = await host.photograph_screen()
	# #region agent log
	var shot := tex.get_image()
	var found := ""
	for y in range(520, 700, 4):
		for x in range(560, 800, 4):
			if shot.get_pixel(x, y).r > 0.8:
				found = "%d,%d" % [x, y]
				break
		if found != "":
			break
	_agent_log("G", "dest block search", {"found": found, "floor": str(shot.get_pixel(200, 660))})
	# #endregion
	if _hold_layer != null and is_instance_valid(_hold_layer) and _hold_layer.get_parent() == screen:
		screen.remove_child(_hold_layer)
		add_child(_hold_layer)
	return tex


func _snapshot() -> ImageTexture:
	var image := get_viewport().get_texture().get_image()
	return ImageTexture.create_from_image(image)


func _play_pixel(from_tex: ImageTexture, to_tex: ImageTexture) -> void:
	var layer := _hold_layer
	var cover := layer.get_child(0) as ColorRect
	var material := cover.material as ShaderMaterial
	material.set_shader_parameter("from_tex", from_tex)
	material.set_shader_parameter("to_tex", from_tex)
	material.set_shader_parameter("progress", 0.0)
	material.set_shader_parameter("min_tiles", 24.0)
	# #region agent log
	_agent_log("B", "level cover added", {"size": str(cover.size), "progress": material.get_shader_parameter("progress"), "layer": layer.layer})
	# #endregion
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("progress", value), 0.0, 0.5, 1.1)
	await get_tree().create_timer(0.35).timeout
	# #region agent log
	var live := get_viewport().get_texture().get_image()
	var live_found := ""
	for y in range(520, 700, 4):
		for x in range(560, 800, 4):
			if live.get_pixel(x, y).r > 0.8:
				live_found = "%d,%d" % [x, y]
				break
		if live_found != "":
			break
	_agent_log("F", "early tween pixel", {"progress": material.get_shader_parameter("progress"), "screen_block": live_found, "frozen_block": str(_tex_pixel(from_tex, 672, 608)), "dest_block": str(_tex_pixel(to_tex, 672, 608))})
	# #endregion
	await tween.finished
	material.set_shader_parameter("from_tex", to_tex)
	material.set_shader_parameter("to_tex", to_tex)
	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_SINE)
	reveal.set_ease(Tween.EASE_IN_OUT)
	reveal.tween_method(func(value: float) -> void: material.set_shader_parameter("progress", value), 0.5, 0.0, 1.1)
	await reveal.finished
	layer.queue_free()
	_hold_layer = null


func _on_goal_body_entered(body: Node2D) -> void:
	if body == _player:
		notify_goal()
