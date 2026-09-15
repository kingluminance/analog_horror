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

const TAB_HEIGHT := 40.0     # baseline (unselected) tab height
const TAB_POP := 6.0         # px the front/selected tab grows above baseline
const TAB_STEP := 6.0        # px shorter per rank behind the front tab
const TAB_MIN_HEIGHT := 24.0
const SLOT_HEIGHT := TAB_HEIGHT + TAB_POP  # every slot is this tall, fixed,
	# so every button's BOTTOM edge (see _update_tab_buttons) lands on the
	# same line no matter its own height
const TAB_H_PADDING := 40.0  # content margins (18+18) plus a little slack

@onready var panel: Control = %Panel
@onready var tab_bar: HBoxContainer = %TabBar
@onready var pages_root: Control = %PagesRoot

var _dialogue_active := false
var _open := false
var _current_tab := ""
var _tab_buttons: Dictionary = {}  # id -> Button (the visual, freely resized)
var _tab_slots: Dictionary = {}    # id -> Control (the HBoxContainer child that actually gets positioned)
var _pages: Dictionary = {}        # id -> Control

# Front-to-back stacking order (index 0 = current/frontmost tab, drawn
# leftmost and on top; each id after that cascades further right and
# further "back"). Selecting a tab moves it to the front of this list --
# a most-recently-used order, not TAB_DEFS' fixed order -- so the whole
# row reads as tabs stacked in sequence with the active one on top, the
# way real overlapping index tabs in a physical binder look.
var _tab_order: Array = []

var _tab_font: SystemFont
var _style_tab_normal: StyleBoxFlat
var _style_tab_selected: StyleBoxFlat

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	panel.hide()
	DialogueManager.dialogue_started.connect(func(_r): _dialogue_active = true)
	DialogueManager.dialogue_ended.connect(func(_r): _dialogue_active = false)

	_build_tab_styles()
	# Tabs must always draw over the binder frame below them in the
	# VBoxContainer, even though the frame is a later sibling (and later
	# siblings normally draw on top) -- otherwise the tabs render mostly
	# UNDER the frame's opaque top border wherever BookColumn's negative
	# separation makes them overlap, which is what made them look cut
	# off/illegible. z_index overrides tree draw order without touching
	# layout.
	tab_bar.z_index = 5

	for def in TAB_DEFS:
		var page: Control = pages_root.get_node(def.id)
		_pages[def.id] = page
		page.hide()
		if page.has_method("set_binder"):
			page.set_binder(self)

		# Each tab is a plain Control "slot" (an HBoxContainer child, so
		# the bar still lays slots out left-to-right with the usual
		# negative-separation overlap) holding a Button that is NOT
		# itself a Container child. HBoxContainer re-sorting a child's
		# rect turned out to also reset that child's `scale` back to
		# Vector2.ONE every time (found by testing -- no combination of
		# assignment order around move_child survived it), so the thing
		# that actually gets resized for the cascading-tabs look has to
		# sit one level below whatever the container manages.
		var text_width: float = _tab_font.get_string_size(def.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var btn_width: float = text_width + TAB_H_PADDING

		var slot := Control.new()
		slot.custom_minimum_size = Vector2(btn_width, SLOT_HEIGHT)
		tab_bar.add_child(slot)

		var btn := Button.new()
		btn.text = def.label
		btn.focus_mode = Control.FOCUS_NONE
		btn.position = Vector2(0.0, 0.0)
		btn.size = Vector2(btn_width, TAB_HEIGHT)
		btn.add_theme_font_override("font", _tab_font)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_switch_tab.bind(def.id, true))
		slot.add_child(btn)

		_tab_buttons[def.id] = btn
		_tab_slots[def.id] = slot
		_tab_order.append(def.id)
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
	_tab_order.erase(tab_id)
	_tab_order.push_front(tab_id)
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

## Two shared StyleBoxFlat "index tab" looks (dim/tucked-in vs bright/
## popped-up), built once instead of per-button so every tab shares the
## exact same look -- swapped per-button in _update_tab_buttons().
func _build_tab_styles() -> void:
	_tab_font = SystemFont.new()
	_tab_font.font_names = PackedStringArray(["Menlo", "Courier New", "Consolas", "monospace"])

	_style_tab_normal = StyleBoxFlat.new()
	_style_tab_normal.bg_color = Color(0.14, 0.11, 0.07, 0.92)
	_style_tab_normal.border_color = Color(0.75, 0.55, 0.25, 0.55)
	_style_tab_normal.border_width_left = 2
	_style_tab_normal.border_width_top = 2
	_style_tab_normal.border_width_right = 2
	_style_tab_normal.corner_radius_top_left = 8
	_style_tab_normal.corner_radius_top_right = 8
	_style_tab_normal.content_margin_left = 18
	_style_tab_normal.content_margin_right = 18
	# Kept small on purpose -- a Button's own content-driven minimum size
	# (font line height + these margins) sets a hard floor under
	# btn.size.y that a smaller explicit assignment gets silently
	# clamped back up past (found by testing: requested rank1/2 heights
	# of 34/28 were coming out as ~39/38 instead). Smaller margins here
	# plus a smaller font for non-selected tabs (_update_tab_buttons)
	# lower that floor enough for the cascade to actually show.
	_style_tab_normal.content_margin_top = 5
	_style_tab_normal.content_margin_bottom = 5

	_style_tab_selected = _style_tab_normal.duplicate()
	_style_tab_selected.bg_color = Color(0.24, 0.18, 0.09, 0.98)
	_style_tab_selected.border_color = Color(0.95, 0.8, 0.45, 0.95)
	_style_tab_selected.border_width_top = 3

## Lays every tab out by its rank in _tab_order (0 = current/frontmost):
## the slot's left-to-right position (move_child) follows rank directly,
## the button's height steps down a little per rank -- but only by
## moving its TOP edge; its BOTTOM edge always lands on SLOT_HEIGHT, the
## same fixed line for every rank, so the whole row still meets the
## binder frame's top border flush instead of leaving a gap under the
## shorter/receded tabs (an earlier scale-based version grew/shrank
## around a bottom pivot, which looked right in theory but a Button
## living in an HBoxContainer turned out to silently reset its own
## `scale` on every re-sort -- see the "알려진 함정" note in CLAUDE.md).
## z_index falls with rank so each tab still visibly overlaps the ones
## behind it regardless of container draw order.
func _update_tab_buttons() -> void:
	var total := _tab_order.size()
	for rank in total:
		var id: String = _tab_order[rank]
		var btn: Button = _tab_buttons[id]
		var slot: Control = _tab_slots[id]
		var selected: bool = rank == 0

		tab_bar.move_child(slot, rank)

		var style: StyleBoxFlat = _style_tab_selected if selected else _style_tab_normal
		for state in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(state, style)
		btn.add_theme_color_override("font_color", Color(0.97, 0.85, 0.55, 1.0) if selected else Color(0.62, 0.55, 0.45, 0.9))
		btn.add_theme_color_override("font_hover_color", Color(0.97, 0.85, 0.55, 1.0))
		btn.add_theme_font_size_override("font_size", 16 if selected else 13)

		var desired_height: float = (TAB_HEIGHT + TAB_POP) if selected else maxf(TAB_HEIGHT - rank * TAB_STEP, TAB_MIN_HEIGHT)
		btn.size.y = desired_height
		# Read the size back instead of trusting `desired_height` -- a
		# Button won't actually shrink past its own content-driven
		# minimum, so whatever it settled on (possibly taller than asked
		# for) is what position has to be based on, or the bottom edge
		# drifts off SLOT_HEIGHT for exactly the ranks that got clamped.
		btn.position.y = SLOT_HEIGHT - btn.size.y
		btn.z_index = total - rank

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
