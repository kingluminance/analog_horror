extends CanvasLayer
## Pops up top-center whenever any registered Stat DECREASES -- never on
## increase. Shaped like ui/item_toast.gd's brief appear-hold-fade
## lifecycle (same no-queue simplicity), but top-center instead of
## top-right, and instead of one line of text it shows one small analog
## gauge (ui/stat_loss_gauge.gd, a ui/stat_gauge.gd subclass) per stat
## that dropped THIS batch, needle stepping DOWN in discrete mechanical
## jumps with a synthesized click (audio/stat_tick.wav) per jump, plus a
## signed numeric label under each gauge (e.g. "유연성 -4").
##
## Nothing here is hardcoded to a particular stat id or count -- however
## many registered stats decrease in one batch (currently only
## HP/aggression/flexibility exist, but this doesn't assume that), that
## many gauge columns get built, same "no stat names hardcoded" spirit as
## Stats/StoryFlags/Inventory.
##
## Batches same-frame decreases: a single .dialogue $> block can call
## Stats.add_stat()/set_stat() several times in a row (once per stat),
## each one firing Stats.stat_delta_changed separately. Reacting to the
## very first signal immediately would pop a new toast per stat instead
## of one combined toast, so instead a pending batch dict is collected
## and only actually shown after one get_tree().process_frame -- by then
## every same-frame decrease has landed in the batch.
##
## No queue -- same simplicity as item_toast.gd: a fresh batch while one
## is still showing just tears down the old gauges and starts over
## (_show_token guards the old batch's suspended coroutines from acting
## on a display that's no longer theirs).
##
## Not instanced into scenes/main.tscn or log_cabin_interior.tscn by this
## change -- see CLAUDE.md, wiring a new UI piece into the actual game
## scenes is a separate, later integration step for every past
## NPC/UI addition on this project.

const StatLossGaugeScene := preload("res://ui/stat_loss_gauge.tscn")
const StatLossGaugeScript := preload("res://ui/stat_loss_gauge.gd")
const TickSound := preload("res://audio/stat_tick.wav")

@export var hold_time := 1.4  ## seconds the fully-stepped popup stays up before fading
@export var fade_in_time := 0.2
@export var fade_out_time := 0.3
@export var gauge_stagger := 0.15  ## seconds between each gauge's step-sequence starting -- keeps 2+ gauges from jumping in perfect lockstep

@onready var panel: PanelContainer = %Panel
@onready var gauges_row: HBoxContainer = %GaugesRow
@onready var tick_player: AudioStreamPlayer = %TickPlayer

var _pending: Dictionary = {}  # stat_id -> {old, new}, the batch currently being collected
var _collecting := false
var _show_token := 0  # bumped every new batch, so a stale awaiting coroutine from an interrupted batch can tell it no longer owns the display
var _lifecycle_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.hide()
	panel.modulate.a = 0.0
	Stats.stat_delta_changed.connect(_on_stat_delta_changed)

func _on_stat_delta_changed(stat_id: String, old_value: float, new_value: float) -> void:
	if new_value >= old_value:
		return  # only losses trigger this popup
	_pending[stat_id] = {"old": old_value, "new": new_value}
	if not _collecting:
		_collecting = true
		_collect_and_show()

func _collect_and_show() -> void:
	await get_tree().process_frame
	_collecting = false
	var batch := _pending.duplicate(true)
	_pending.clear()
	_run_batch(batch)

func _run_batch(batch: Dictionary) -> void:
	_show_token += 1
	var token := _show_token
	if _lifecycle_tween and _lifecycle_tween.is_valid():
		_lifecycle_tween.kill()

	for c in gauges_row.get_children():
		c.queue_free()

	var total_time := 0.0
	var i := 0
	for stat_id in batch.keys():
		var old_v: float = batch[stat_id].old
		var new_v: float = batch[stat_id].new
		var gauge = _add_gauge_column(stat_id, old_v, new_v)
		gauge.stepped.connect(_on_gauge_stepped)
		var delay: float = i * gauge_stagger
		var jumps := StatLossGaugeScript.compute_jump_count(old_v, new_v)
		total_time = max(total_time, delay + jumps * gauge.step_interval)
		_run_gauge(gauge, delay, old_v, new_v, Stats.get_max(stat_id), token)
		i += 1

	panel.show()
	panel.modulate.a = 0.0
	await get_tree().process_frame  # containers need a pass before their combined minimum size is meaningful -- same "hidden Control" pitfall as items_page.gd's refresh()
	if token != _show_token:
		return
	panel.size = panel.get_combined_minimum_size()
	panel.position.x = (get_viewport().get_visible_rect().size.x - panel.size.x) / 2.0

	_lifecycle_tween = create_tween()
	_lifecycle_tween.tween_property(panel, "modulate:a", 1.0, fade_in_time)
	_lifecycle_tween.tween_interval(total_time + hold_time)
	_lifecycle_tween.tween_property(panel, "modulate:a", 0.0, fade_out_time)
	await _lifecycle_tween.finished
	if token == _show_token:
		panel.hide()

## Fire-and-forget per gauge -- called without awaiting from _run_batch so
## every gauge's stagger delay + step sequence runs concurrently instead
## of one after another. `gauge` is left untyped (not `: Control`) since
## it's really a StatLossGauge instance -- stat_gauge.gd/stat_loss_gauge.gd
## declare no class_name, so a static Control type here would make the
## static analyzer reject animate_stepped()/step_interval below as
## unknown members (same reason ui/shop/shop_ui.gd leaves its `card`
## instance untyped when calling ShopItemCard-only methods on it).
func _run_gauge(gauge, delay: float, old_v: float, new_v: float, max_v: float, token: int) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if token != _show_token or not is_instance_valid(gauge):
		return  # a newer batch tore this gauge down (or is about to) before its turn came up
	await gauge.animate_stepped(old_v, new_v, max_v)

func _on_gauge_stepped(_value: float) -> void:
	tick_player.stream = TickSound
	tick_player.play()

func _add_gauge_column(stat_id: String, old_v: float, new_v: float):
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var gauge = StatLossGaugeScene.instantiate()
	column.add_child(gauge)
	gauges_row.add_child(column)  # into the live tree BEFORE setup() below -- setup() needs gauge._ready() to have already resolved its %NameLabel/%ValueLabel @onready vars, which only happens once the node is actually inside the SceneTree; calling setup() while gauge is still just a detached child of a not-yet-added column would find those vars null

	var max_v := Stats.get_max(stat_id)
	var display_name := Stats.get_display_name(stat_id)
	gauge.setup(display_name, old_v, max_v)

	var delta_label := Label.new()
	delta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	delta_label.text = "%s %s" % [display_name, _format_signed(new_v - old_v)]
	delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	delta_label.add_theme_font_size_override("font_size", 12)
	delta_label.add_theme_color_override("font_color", Color(0.85, 0.35, 0.3, 0.95))
	column.add_child(delta_label)

	return gauge

static func _format_signed(delta: float) -> String:
	if delta == round(delta):
		return str(int(delta))
	return "%.1f" % delta
