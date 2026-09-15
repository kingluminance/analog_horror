extends CanvasLayer
## Single Tab/Esc modal replacing the old separate inventory panel
## (ui/inventory_ui.gd) and pause menu (ui/pause_menu.gd) -- an "L홀더"
## style binder with overlapping index tabs along the top edge. Tab opens
## straight to the [아이템] tab, Esc opens straight to [설정]; once open,
## any tab is freely clickable and the chosen one animates to the front
## with a quick scale.x flip (the same billboard-flip trick this project
## already uses for spinning things) instead of a hard cut.
##
## Tabs are data, not hardcoded UI -- add an entry to TAB_DEFS and a
## matching page scene instanced under %PagesRoot (node name == tab id)
## to add a fourth tab later; nothing else needs to change.

const TAB_DEFS := [
	{"id": "items", "label": "아이템"},
	{"id": "save_load", "label": "세이브 / 로드"},
	{"id": "settings", "label": "설정"},
]

@onready var panel: Control = %Panel
@onready var tab_bar: HBoxContainer = %TabBar
@onready var pages_root: Control = %PagesRoot

var _dialogue_active := false
var _open := false
var _current_tab := ""
var _tab_buttons: Dictionary = {}  # id -> Button
var _pages: Dictionary = {}        # id -> Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	panel.hide()
	DialogueManager.dialogue_started.connect(func(_r): _dialogue_active = true)
	DialogueManager.dialogue_ended.connect(func(_r): _dialogue_active = false)

	for def in TAB_DEFS:
		var page: Control = pages_root.get_node(def.id)
		_pages[def.id] = page
		page.hide()
		if page.has_method("set_binder"):
			page.set_binder(self)

		var btn := Button.new()
		btn.text = def.label
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_switch_tab.bind(def.id, true))
		tab_bar.add_child(btn)
		_tab_buttons[def.id] = btn
	_update_tab_buttons()

func is_modal_open() -> bool:
	return _open

## Public so a page (settings' "닫기" button, save/load after a load)
## can close the binder without reaching into private state.
func close_ui() -> void:
	_close()

func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		if _open:
			_close()
		else:
			_try_open("items")
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _open:
			_close()
		else:
			_try_open("settings")
		return

func _try_open(tab_id: String) -> void:
	for node in get_tree().get_nodes_in_group("modal_ui"):
		if node != self and node.has_method("is_modal_open") and node.is_modal_open():
			return
	panel.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_open = true
	_switch_tab(tab_id, false)

func _close() -> void:
	panel.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_open = false

func _switch_tab(tab_id: String, animate: bool) -> void:
	if tab_id == _current_tab:
		return
	var old_page: Control = _pages.get(_current_tab)
	var new_page: Control = _pages[tab_id]
	_current_tab = tab_id
	_update_tab_buttons()

	if new_page.has_method("refresh"):
		new_page.refresh()

	if not animate or old_page == null:
		if old_page:
			old_page.hide()
		new_page.show()
		return

	pages_root.move_child(new_page, pages_root.get_child_count() - 1)
	var tw := create_tween()
	tw.tween_property(old_page, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	old_page.hide()
	old_page.scale.x = 1.0
	new_page.scale.x = 0.0
	new_page.show()
	var tw2 := create_tween()
	tw2.tween_property(new_page, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _update_tab_buttons() -> void:
	for id in _tab_buttons:
		var btn: Button = _tab_buttons[id]
		var selected: bool = id == _current_tab
		btn.modulate = Color(0.95, 0.8, 0.45, 1.0) if selected else Color(0.55, 0.5, 0.42, 0.85)
		btn.scale = Vector2(1.06, 1.06) if selected else Vector2.ONE
		if selected:
			tab_bar.move_child(btn, tab_bar.get_child_count() - 1)

## Hides the whole binder panel for a couple of frames so a "세이브"
## screenshot captures the game world underneath, not this UI -- then
## shows the panel again. Called by save_load_page.gd.
func capture_world_screenshot() -> Image:
	panel.hide()
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	panel.show()
	return img
