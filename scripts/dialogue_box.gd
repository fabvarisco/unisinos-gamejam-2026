extends PanelContainer

signal finished

var _lines: PackedStringArray = PackedStringArray()
var _index := 0

@onready var _body: Label = $Margin/Column/Body
@onready var _hint: Label = $Margin/Column/Hint


func start(lines: PackedStringArray) -> void:
	_lines = lines
	_index = 0
	visible = true
	_show_current()


func close() -> void:
	if not visible:
		return
	visible = false
	finished.emit()


func _gui_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	_advance()


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		close()
		return
	_show_current()


func _show_current() -> void:
	_body.text = _lines[_index]
	var last := _index >= _lines.size() - 1
	_hint.text = "Click to close" if last else "Click to continue"
