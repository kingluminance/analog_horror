extends Control
## "아이템" binder page -- the same scattered-Polaroid pile + analog stat
## gauges that used to be the whole of the old ui/inventory_ui.gd, now
## living as one page inside the binder (ui/binder/binder_ui.gd) instead
## of its own standalone modal. binder_ui calls refresh() every time this
## page becomes the front page.

const InventoryPolaroidScene := preload("res://ui/inventory_polaroid.tscn")
const StatGaugeScene := preload("res://ui/stat_gauge.tscn")

@onready var scatter: Control = %Scatter
@onready var caption: Label = %Caption
@onready var stats_row: Control = %StatsRow

var _cards: Array = []
var _items: Array = []
var _focused_index := -1
var _gauges: Dictionary = {}  # stat id -> StatGauge instance

func _ready() -> void:
	Inventory.item_added.connect(func(_id, _count): if visible: refresh())
	Inventory.item_removed.connect(func(_id, _count): if visible: refresh())
	Stats.stat_changed.connect(func(id, value): if visible: _update_gauge(id, value))

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_left"):
		_move_focus(-1)
	elif event.is_action_pressed("ui_right"):
		_move_focus(1)

func refresh() -> void:
	# Deferred one frame: on the very first-ever open, the container
	# chain above this page (BookWrap/BookColumn/BinderFrame/PagesRoot)
	# hasn't finished its layout pass yet (the whole binder was hidden
	# until just now), so `size` below would still read as whatever it
	# was before ever being shown -- cards ended up scattered near the
	# top-left corner, overlapping the tab bar, instead of centered in
	# the page. Waiting a frame lets that layout settle first.
	await get_tree().process_frame
	_rebuild()
	_rebuild_gauges()

func _rebuild() -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()
	_items = Inventory.get_owned_items()
	_focused_index = -1

	# Centered within this page's own rect (the binder's inner box), not
	# the full screen -- this page no longer owns the whole viewport.
	var box_size := size
	var spacing := 190.0
	var start_x := box_size.x / 2.0 - (_items.size() - 1) * spacing / 2.0
	var base_y := box_size.y / 2.0 - 40.0

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
		_rebuild_gauges()

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
