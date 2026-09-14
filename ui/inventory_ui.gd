extends CanvasLayer
## VHS-drawer-of-Polaroids inventory + a row of analog stat gauges.
## KEY_TAB toggles it (this project has no InputMap [input] section --
## every interactable hardcodes its key the same way, e.g.
## floating_photo/orbiting_paddle hardcode KEY_E -- so this follows that
## convention rather than being the first to add one). Mutually
## exclusive with the pause menu and with dialogue via the "modal_ui"
## group / DialogueManager signals.

const InventoryPolaroidScene := preload("res://ui/inventory_polaroid.tscn")
const StatGaugeScene := preload("res://ui/stat_gauge.tscn")

@onready var panel: Control = %Panel
@onready var scatter: Control = %Scatter
@onready var caption: Label = %Caption
@onready var stats_row: Control = %StatsRow

var _dialogue_active := false
var _open := false
var _cards: Array = []
var _items: Array = []
var _focused_index := -1
var _gauges: Dictionary = {}  # stat id -> StatGauge instance

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	panel.hide()
	DialogueManager.dialogue_started.connect(func(_r): _dialogue_active = true)
	DialogueManager.dialogue_ended.connect(func(_r): _dialogue_active = false)
	Inventory.item_added.connect(func(_id, _count): if _open: _rebuild())
	Inventory.item_removed.connect(func(_id, _count): if _open: _rebuild())
	Stats.stat_changed.connect(func(id, value): if _open: _update_gauge(id, value))

func is_modal_open() -> bool:
	return _open

func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		if _open:
			_close()
		else:
			_try_open()
		return
	if not _open:
		return
	if event.is_action_pressed("ui_left"):
		_move_focus(-1)
	elif event.is_action_pressed("ui_right"):
		_move_focus(1)

func _try_open() -> void:
	for node in get_tree().get_nodes_in_group("modal_ui"):
		if node != self and node.has_method("is_modal_open") and node.is_modal_open():
			return
	_rebuild()
	_rebuild_gauges()
	panel.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_open = true

func _close() -> void:
	panel.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_open = false

func _rebuild() -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()
	_items = Inventory.get_owned_items()
	_focused_index = -1

	var viewport_size := get_viewport().get_visible_rect().size
	var spacing := 190.0
	var start_x := viewport_size.x / 2.0 - (_items.size() - 1) * spacing / 2.0
	var base_y := viewport_size.y / 2.0 - 95.0

	for i in _items.size():
		var item: Dictionary = _items[i]
		var card: Control = InventoryPolaroidScene.instantiate()
		scatter.add_child(card)
		card.position = Vector2(start_x + i * spacing - 80.0, base_y)
		card.setup(item.id, item.display_name, item.texture, item.description)
		card.clicked.connect(_on_card_clicked.bind(i))
		_cards.append(card)

	if not _cards.is_empty():
		_focused_index = 0
	_update_focus()

func _rebuild_gauges() -> void:
	for g in stats_row.get_children():
		g.queue_free()
	_gauges.clear()
	for id in Stats.get_registered_stats():
		var gauge: Control = StatGaugeScene.instantiate()
		stats_row.add_child(gauge)
		gauge.setup(Stats.get_display_name(id), Stats.get_stat(id), Stats.get_max(id))
		_gauges[id] = gauge

func _update_gauge(id: String, value: float) -> void:
	if _gauges.has(id):
		_gauges[id].set_value(value)
	else:
		_rebuild_gauges()  # a new stat got registered after the panel was built

func _on_card_clicked(index: int) -> void:
	_focused_index = index
	_update_focus()

func _move_focus(delta: int) -> void:
	if _cards.is_empty():
		return
	_focused_index = wrapi(_focused_index + delta, 0, _cards.size())
	_update_focus()

func _update_focus() -> void:
	for i in _cards.size():
		_cards[i].set_focused(i == _focused_index)
	if _focused_index >= 0 and _focused_index < _items.size():
		caption.text = "[%s]" % _items[_focused_index].display_name
		_cards[_focused_index].show_description()
	else:
		caption.text = "(비어 있음)"
