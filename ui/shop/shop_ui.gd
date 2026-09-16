class_name ShopUI
extends CanvasLayer
## Generic shop overlay a merchant's ShopWatcher (entities/shared/
## shop_watcher.gd) opens by looking up the "shop_ui" group -- the same
## "single modal, pauses the game, its own explicit close control" pattern
## ui/binder/binder_ui.gd already established for the Tab/Esc binder, just
## for a second, independent modal. Meant to exist exactly once in the
## tree; not wired into scenes/main.tscn yet -- see the TODO left for that
## integration pass in this project's history (every NPC in CLAUDE.md's
## "NPC / 오브젝트 목록" got wired in as a separate step after its
## components existed, same story here).
##
## Items fan out along a semicircular arc in screen space -- a genuine 2D
## UI overlay (CanvasLayer + Control), never anything placed in the 3D
## world -- via `pivot + radius * Vector2(sin(theta), -cos(theta))` with
## theta spread evenly across ARC_SPREAD_DEGREES, each card also rotated by
## its own theta for a fanned-out-cards look. Clicking a card attempts a
## purchase directly against Inventory/Currency; deliberately does NOT rely
## on Esc to close (binder_ui.gd already owns Esc for its own toggle, and
## stacking a second Esc consumer on the same key is exactly the kind of
## thing that silently breaks one or the other depending on node order) --
## the exit card is the one unambiguous way to close this.

signal purchase_succeeded(item: ShopItem)
signal purchase_failed(item: ShopItem, reason: String)

const ShopItemCardScene := preload("res://ui/shop/shop_item_card.tscn")

const ARC_RADIUS := 260.0
const ARC_SPREAD_DEGREES := 80.0

@onready var panel: Control = %Panel
@onready var title_label: Label = %TitleLabel
@onready var arc_root: Control = %ArcRoot
@onready var exit_card: Button = %ExitCard

var _open := false
var _cards: Array = []
var _items: Array[ShopItem] = []

func _ready() -> void:
	# Same reason binder_ui.gd sets this on itself: get_tree().paused = true
	# would otherwise stop this CanvasLayer's own children (the exit
	# button's gui_input, etc.) from processing at all while the shop is
	# the very thing that just paused the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("shop_ui")
	add_to_group("modal_ui")
	panel.hide()
	exit_card.pressed.connect(close_shop)

func is_modal_open() -> bool:
	return _open

## `items` -- what to sell, in display order. `title` -- shown at the top
## of the panel (e.g. a merchant's name), blank is fine.
func open_shop(items: Array[ShopItem], title: String = "") -> void:
	# Courtesy extended to every "modal_ui" member, same rule binder_ui.gd's
	# own _try_open already follows -- don't stack this modal on top of
	# another one (or vice versa) if something else already has the game
	# paused and the mouse freed.
	for node in get_tree().get_nodes_in_group("modal_ui"):
		if node != self and node.has_method("is_modal_open") and node.is_modal_open():
			return

	_items = items
	title_label.text = title
	panel.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_open = true
	# arc_root's rect isn't guaranteed settled the very first time this
	# panel is ever shown (same "hidden Control hasn't been laid out yet"
	# trap ui/binder/items_page.gd's refresh() already documents and works
	# around) -- wait a frame before reading arc_root.size for the fan
	# pivot below.
	await get_tree().process_frame
	_rebuild_cards()

func close_shop() -> void:
	panel.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_open = false
	_clear_cards()

func _clear_cards() -> void:
	for c in _cards:
		if is_instance_valid(c):
			c.queue_free()
	_cards.clear()

func _rebuild_cards() -> void:
	_clear_cards()

	var n := _items.size()
	var pivot: Vector2 = arc_root.size / 2.0
	for i in n:
		var item: ShopItem = _items[i]
		var card = ShopItemCardScene.instantiate()
		arc_root.add_child(card)

		var theta_deg := 0.0
		if n > 1:
			theta_deg = -ARC_SPREAD_DEGREES / 2.0 + ARC_SPREAD_DEGREES * i / float(n - 1)
		var theta := deg_to_rad(theta_deg)
		var card_half: Vector2 = card.custom_minimum_size / 2.0
		card.position = pivot + ARC_RADIUS * Vector2(sin(theta), -cos(theta)) - card_half
		card.pivot_offset = card_half
		card.rotation_degrees = theta_deg

		card.setup_shop(item, Inventory.has_item(Currency.ID, item.price))
		card.clicked.connect(_attempt_purchase.bind(item, card))
		_cards.append(card)

func _attempt_purchase(item: ShopItem, card) -> void:
	if not Inventory.has_item(Currency.ID, item.price):
		purchase_failed.emit(item, "너가 부족하다.")
		if is_instance_valid(card):
			card.flash_unaffordable()
		return

	Inventory.remove_item(Currency.ID, item.price)
	# Idempotent -- safe even if nothing else registered this item id yet
	# (register_item just overwrites the same metadata on a repeat buy).
	Inventory.register_item(item.item_id, item.display_name, item.texture, item.description)
	Inventory.give_item(item.item_id)
	purchase_succeeded.emit(item)

	# Spending 너 may have pushed OTHER cards out of affordable range too,
	# not just this one -- refresh every card's dimmed state, not just the
	# one just bought.
	_refresh_affordability()

func _refresh_affordability() -> void:
	for i in _cards.size():
		if i >= _items.size():
			continue
		var item: ShopItem = _items[i]
		if is_instance_valid(_cards[i]):
			_cards[i].set_affordable(Inventory.has_item(Currency.ID, item.price))
