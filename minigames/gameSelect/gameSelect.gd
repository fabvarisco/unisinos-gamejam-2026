extends Node2D

signal opened(game_id: String)

const _NAMES: PackedStringArray = ["Plataforma", "Corrida", "Quebra-cabeça"]
const _IDS: PackedStringArray = ["platform", "", ""]

var _index := 0
var _labels: Array[Label] = []
var _backdrop: ColorRect


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.04, 0.11, 0.07, 1)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for name_index in _NAMES.size():
		var label := Label.new()
		label.position = Vector2(160, 160 + name_index * 100)
		label.add_theme_font_size_override("font_size", 64)
		label.add_theme_color_override("font_color", Color(0.75, 0.95, 0.55))
		layer.add_child(label)
		_labels.append(label)
	_refresh()


func move(step: int) -> void:
	if not visible:
		return
	_index = clampi(_index + step, 0, _NAMES.size() - 1)
	_refresh()


func confirm() -> void:
	if not visible or _IDS[_index] == "":
		return
	opened.emit(_IDS[_index])


func set_shown(on: bool) -> void:
	visible = on
	_backdrop.visible = on
	for label in _labels:
		label.visible = on


func hide_text() -> void:
	var tween := create_tween()
	for label in _labels:
		tween.parallel().tween_property(label, "modulate:a", 0.0, 0.4)
	await tween.finished
	for label in _labels:
		label.visible = false


func show_text() -> void:
	_refresh()
	for label in _labels:
		label.visible = true
		label.modulate.a = 0.0
	var tween := create_tween()
	for label in _labels:
		tween.parallel().tween_property(label, "modulate:a", 1.0, 0.4)
	await tween.finished


func _refresh() -> void:
	for name_index in _NAMES.size():
		var selected := name_index == _index
		_labels[name_index].text = ("> " if selected else "  ") + _NAMES[name_index]
		_labels[name_index].modulate = Color(1, 1, 1) if selected else Color(0.45, 0.55, 0.4)
