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
# Shared by tabs AND ghost sheets (see _update_ghost_sheets) -- one
# source of truth for "how far behind is rank N" so a tab's label
# actually lines up with its own page peeking out behind the front
# one, instead of the two drifting apart (requested: "진짜 그 페이지에
# 인덱스 붙어 있는거처럼" -- looks like the tab is physically attached
# to that specific sheet, not just floating above the stack).
const RANK_OFFSETS := [Vector2.ZERO, Vector2(12.0, 10.0), Vector2(24.0, 20.0)]

const Z_BACK_TAB := 1   # rank >= 1 tabs -- above the ghost sheets, below the frame
const Z_FRAME := 2      # BinderFrame (and everything in PagesRoot)
const Z_FRONT_TAB := 3  # rank 0's tab -- has to clear the frame's own top border

@onready var panel: Control = %Panel
@onready var tab_bar: HBoxContainer = %TabBar
@onready var pages_root: Control = %PagesRoot
@onready var binder_frame: Control = %BinderFrame
@onready var ghost_sheet_1: ColorRect = %GhostSheet1  # rank 1's sheet, peeking out behind the frame
@onready var ghost_sheet_2: ColorRect = %GhostSheet2  # rank 2's sheet, peeking out further behind that

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
	# Layering, back to front: ghost sheets (0, default) -> back tabs
	# (Z_BACK_TAB) -> the frame/front page (Z_FRAME) -> the front tab
	# (Z_FRONT_TAB). Two different bugs shaped this:
	# - BookColumn's negative separation makes the tab row overlap
	#   BinderFrame's top edge, and a later sibling normally draws over
	#   an earlier one -- without a z boost EVERY tab renders mostly
	#   under the frame's opaque border, illegible (the first version of
	#   this feature hit exactly that).
	# - the opposite bug came later: giving every tab the SAME z boost
	#   put the back tabs (rank >= 1) above the frame too, so they never
	#   looked like they were tucked behind the front page's body at all
	#   ("당연히 맨 앞장보다 레이어가 뒤어야지"). Back tabs need to sit
	#   ABOVE the ghost sheets they belong to but BELOW the front page,
	#   so the front page's own body visibly covers the part of them it
	#   overlaps.
	binder_frame.z_index = Z_FRAME

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

		# (Tried a per-tab accent "spine" -- a strip below each tab meant
		# to read as a sheet of paper -- but it just looked like a big
		# ugly bar, not the intended paper edges; removed. The ghost
		# sheets below the frame carry that idea instead.)
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
	call_deferred("_update_ghost_sheets")

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

	# If the tab being picked was a back tab, it had its own ghost sheet
	# peeking out behind the frame -- pull that specific sheet out and
	# slide it into the frame's own spot before doing anything else
	# ("뒷종이 꺼내서 넘기는 듯한 애니메이션", requested alongside the
	# z-index fix above). Only for an actual click (animate=true), not
	# the instant first-open path.
	var old_rank := _tab_order.find(tab_id)
	var pulled_ghost: ColorRect = null
	if animate and old_rank >= 1 and old_rank <= 2:
		pulled_ghost = [ghost_sheet_1, ghost_sheet_2][old_rank - 1]

	_current_tab = tab_id
	_tab_order.erase(tab_id)
	_tab_order.push_front(tab_id)
	_update_tab_buttons()

	if pulled_ghost:
		var pull := create_tween()
		pull.tween_property(pulled_ghost, "global_position", binder_frame.global_position, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		pull.parallel().tween_property(pulled_ghost, "color", Color(0.06, 0.05, 0.035, 0.97), 0.22)
		await pull.finished
		pulled_ghost.hide()

	# Re-settles both ghost sheets onto whichever tabs are now rank 1/2
	# (the one just pulled forward included -- it gets reassigned to
	# whichever back rank it landed on, or hidden if there's no rank 2).
	call_deferred("_update_ghost_sheets")

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

		# Only the horizontal component of RANK_OFFSETS applies to the tab
		# itself -- it still needs to sit UP at the top of the stack (just
		# shifted right, toward wherever its ghost sheet peeks out), not
		# sink down by the sheet's own y-offset too. Applying the full
		# offset (tried first) dragged rank1/2's tabs down below the
		# front tab's own bottom line, reading as "fallen off" instead of
		# "tucked behind" -- caught by the user from a screenshot ("뒤쪽
		#으로 보내야지 좀 올리고"). Only _update_ghost_sheets uses the
		# y-offset, for the big page body that actually is meant to sit
		# lower/behind.
		var offset_x: float = RANK_OFFSETS[rank].x if rank < RANK_OFFSETS.size() else RANK_OFFSETS[RANK_OFFSETS.size() - 1].x

		var desired_height: float = (TAB_HEIGHT + TAB_POP) if selected else maxf(TAB_HEIGHT - rank * TAB_STEP, TAB_MIN_HEIGHT)
		btn.size.y = desired_height
		# Read the size back instead of trusting `desired_height` -- a
		# Button won't actually shrink past its own content-driven
		# minimum, so whatever it settled on (possibly taller than asked
		# for) is what position has to be based on, or the bottom edge
		# drifts off SLOT_HEIGHT for exactly the ranks that got clamped.
		btn.position = Vector2(offset_x, SLOT_HEIGHT - btn.size.y)
		btn.z_index = Z_FRONT_TAB if selected else Z_BACK_TAB

## The other two pages aren't just hidden behind the front one -- their
## own big "sheet" peeks out from behind it, offset a little further
## down-right per rank, the same idea as the tab spines but for the
## whole page instead of just its label ("이 전체 큰 탭들이 종이들처럼
## 있는거 처럼" -- the file-folder-viewed-from-the-front request). Reads
## BinderFrame's actual on-screen rect (only known once layout has
## settled -- called via call_deferred, never inline) rather than
## hardcoding an offset from the CenterContainer's dynamic centering.
func _update_ghost_sheets() -> void:
	var frame_pos := binder_frame.global_position
	var frame_size := binder_frame.size
	if frame_size == Vector2.ZERO:
		return  # layout hasn't run yet this frame -- try again next update
	var ghosts := [ghost_sheet_1, ghost_sheet_2]
	var colors := [Color(0.15, 0.12, 0.08, 0.95), Color(0.1, 0.08, 0.055, 0.95)]
	for i in ghosts.size():
		var rank := i + 1
		var g: ColorRect = ghosts[i]
		if rank >= _tab_order.size():
			g.hide()
			continue
		g.show()
		g.global_position = frame_pos + RANK_OFFSETS[rank]
		g.size = frame_size
		g.color = colors[i]

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
