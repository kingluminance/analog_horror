extends CanvasLayer
## Small, quiet "<이름>을/를 얻었습니다" notification — slides in from the
## right near the top of the screen, holds briefly, slides back out. Fires
## on Inventory.item_added. No queue: a pickup while one is showing just
## restarts with the new text.

@onready var panel: Control = %Panel

var _tween: Tween
var _rest_x: float
var _hidden_x: float

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rest_x = panel.position.x
	_hidden_x = _rest_x + panel.size.x + 40.0
	panel.position.x = _hidden_x
	panel.modulate.a = 0.0
	Inventory.item_added.connect(_on_item_added)

func _on_item_added(id: String, _count: int) -> void:
	var display_name := Inventory.get_display_name(id)
	_show_toast("%s%s 얻었습니다" % [display_name, _josa_eul_reul(display_name)])

func _show_toast(text: String) -> void:
	%Label.text = text
	if _tween and _tween.is_valid():
		_tween.kill()
	panel.position.x = _hidden_x
	panel.modulate.a = 0.0

	_tween = create_tween()
	_tween.tween_property(panel, "position:x", _rest_x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(1.3)
	_tween.tween_property(panel, "position:x", _hidden_x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.25)

# Korean object-marker particle: 을 after a syllable with a batchim (final
# consonant), 를 after one without — picked from the Hangul syllable's
# codepoint so it works for any dynamic item name.
static func _josa_eul_reul(word: String) -> String:
	if word.is_empty():
		return "를"
	var last_char := word.unicode_at(word.length() - 1)
	if last_char < 0xAC00 or last_char > 0xD7A3:
		return "를"
	var has_batchim := (last_char - 0xAC00) % 28 != 0
	return "을" if has_batchim else "를"
