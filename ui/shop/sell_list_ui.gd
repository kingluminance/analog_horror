class_name SellListUI
extends CanvasLayer
## Fixed-size scrollable list any merchant's SellWatcher (entities/shared/
## sell_watcher.gd) opens so the player can sell items straight out of
## their own Inventory. Dialogue Manager choices are static text baked
## into a .dialogue file -- there's no way to make one dynamically list
## "however many items I currently own", so this is a small second modal
## instead of a dialogue branch, same "single modal, pauses the game,
## explicit close button, joins modal_ui" shape as ui/shop/shop_ui.gd and
## ui/binder/binder_ui.gd (see shop_ui.gd's own docstring for why Esc
## isn't the close mechanism either -- binder_ui.gd already owns Esc for
## its own toggle).
##
## Meant to exist exactly once in the tree, shared by every merchant with
## a SellWatcher child -- this class only renders rows and reports which
## one got clicked via sell_requested; SellWatcher owns all the actual
## business logic (which items are sellable, price/reaction-line lookup,
## the real Inventory mutation).

signal sell_requested(item_id: String)

@onready var panel: Control = %Panel
@onready var rows_container: VBoxContainer = %RowsContainer
@onready var reaction_label: Label = %ReactionLabel
@onready var close_button: Button = %CloseButton

var _open := false

func _ready() -> void:
	# Same reason shop_ui.gd/binder_ui.gd set this on themselves:
	# get_tree().paused = true would otherwise stop this CanvasLayer's own
	# children (the row buttons, close button) from processing input at
	# all while this panel is the very thing that just paused the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("sell_list_ui")
	add_to_group("modal_ui")
	panel.hide()
	close_button.pressed.connect(close_list)

func is_modal_open() -> bool:
	return _open

## `rows` -- Array of {id, display_name, count, price}, in display order.
func open_list(rows: Array[Dictionary]) -> void:
	# Same courtesy shop_ui.gd's open_shop() already extends to every
	# modal_ui member -- don't stack this on top of (or under) another
	# open modal.
	for node in get_tree().get_nodes_in_group("modal_ui"):
		if node != self and node.has_method("is_modal_open") and node.is_modal_open():
			return

	_rebuild_rows(rows)
	# Deliberately NOT clearing reaction_label here -- the caller (a
	# SellWatcher) decides what belongs in that slot each time: its
	# default_sell_line as a standing greeting on first open, or a
	# specific per-item reaction after a sale/refusal. Clearing it here
	# would wipe whatever the caller sets right after this call returns.
	panel.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_open = true

func close_list() -> void:
	panel.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_open = false

## Called by a SellWatcher right after a sale so the reaction line and the
## (now one-less) row list both update in place.
func show_reaction(text: String) -> void:
	reaction_label.text = text

func _rebuild_rows(rows: Array[Dictionary]) -> void:
	for child in rows_container.get_children():
		child.queue_free()
	if rows.is_empty():
		var empty_label := Label.new()
		empty_label.text = "팔 만한 게 없네."
		rows_container.add_child(empty_label)
	for row in rows:
		var btn := Button.new()
		if row.get("sellable", true):
			btn.text = "%s x%d  --  %d너" % [row.display_name, row.count, row.price]
		else:
			btn.text = "%s x%d  --  판매 불가" % [row.display_name, row.count]
		btn.pressed.connect(_on_row_pressed.bind(row.id))
		rows_container.add_child(btn)

func _on_row_pressed(item_id: String) -> void:
	sell_requested.emit(item_id)
