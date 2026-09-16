extends Node3D
## Root of "기록된 날개" (Recorded Wings): a centered eye with three copies of
## the same torn-notebook-paper wing sprite arranged around it (right/top/
## left -- bottom deliberately skipped). A nice echo of this game's existing
## "기록지"(record-paper) motif from SaveSystem: same torn-lined-paper idea,
## repurposed here as a wing shape instead of the save-card art.
##
## Not yet placed in scenes/main.tscn -- exists only as files under
## entities/recorded_wings/ until a separate integration pass wires it in.
## No dialogue/Interactable: this entity is purely ambient/visual.
##
## Group facing: every sprite here (Eye + all 3 wings) has billboard = 1.
## Per spinning_trinket.gd's note, billboard fully recomputes a Sprite3D's
## rotation from the camera every frame and discards the node's own
## `rotation` entirely. Since all four sprites run that *exact same* math
## against the *exact same* camera each frame, they end up with an
## identical facing basis for free -- there is nothing to keep in sync, so
## it reads as one rigid group turning together with zero custom facing
## code. (Verified in a real scene with an orbiting camera rather than
## just trusted from the reasoning -- see CLAUDE.md.) This also happens to
## satisfy "one consistent orientation, not individually mirrored" for the
## wings automatically: billboard ignores per-node rotation/mirroring of
## the *frame*, so the 3 wing copies can only ever differ by position, never
## by orientation.
##
## The whole assembly bobs as ONE unit -- root-level sine bob, same idiom as
## trash_angel.gd -- individual sprites never move under their own bob.
##
## Each wing (WingRight/WingTop/WingLeft) independently runs its own random
## timer + one-of-three short behavior, in the spirit of speaker.gd's pump
## envelope math but per-sprite and randomized instead of driven by one
## shared flag:
##   1. TREMBLE -- fast small local-position jitter for a moment
##   2. PUMP    -- ~5 scale pulses then stops
##   3. STRETCH -- elongates along local Y, eases back to normal
## then returns to rest and re-rolls its own next interval + next choice.

@export var bob_height := 0.12
@export var bob_speed := 0.5

@export var wing_interval_min := 2.5 # seconds -- shortest gap between behaviors
@export var wing_interval_max := 6.0 # seconds -- longest gap between behaviors

@export var tremble_duration := 0.35
@export var tremble_speed := 40.0 # rad/s, how fast the jitter oscillates
@export var tremble_amplitude := 0.035 # meters of local position jitter

@export var pump_count := 5
@export var pump_duration := 0.16 # seconds per pulse
@export var pump_scale := 1.35 # peak scale during a pulse

@export var stretch_duration := 0.55
@export var stretch_scale := 1.6 # peak elongation along the wing's local Y

enum Behavior { TREMBLE, PUMP, STRETCH }

# Emitted whenever a wing starts/finishes one of the 3 behaviors above --
# mainly here so a headless test can observe transitions without the
# entity itself needing to print (see entities/recorded_wings test notes
# in CLAUDE.md).
signal wing_behavior_started(wing: Sprite3D, behavior: int)
signal wing_behavior_finished(wing: Sprite3D, behavior: int)

class WingState:
	var sprite: Sprite3D
	var base_position: Vector3
	var behavior: int = -1 # Behavior enum value, -1 = idle (no behavior running)
	var state_time := 0.0
	var next_trigger_in := 0.0
	var pumps_done := 0

var _base_y: float
var _time_offset: float
var _wings: Array[WingState] = []

func _ready() -> void:
	_base_y = position.y
	_time_offset = randf() * TAU
	for wing_node in [$WingRight, $WingTop, $WingLeft]:
		var w := WingState.new()
		w.sprite = wing_node
		w.base_position = wing_node.position
		w.next_trigger_in = randf_range(wing_interval_min, wing_interval_max)
		_wings.append(w)

func _process(delta: float) -> void:
	position.y = _base_y + sin(Time.get_ticks_msec() / 1000.0 * bob_speed + _time_offset) * bob_height
	for w in _wings:
		_update_wing(w, delta)

func _update_wing(w: WingState, delta: float) -> void:
	if w.behavior == -1:
		w.next_trigger_in -= delta
		if w.next_trigger_in <= 0.0:
			_start_behavior(w)
		return

	w.state_time += delta
	match w.behavior:
		Behavior.TREMBLE:
			_run_tremble(w)
		Behavior.PUMP:
			_run_pump(w)
		Behavior.STRETCH:
			_run_stretch(w)

func _start_behavior(w: WingState) -> void:
	w.behavior = randi_range(0, 2)
	w.state_time = 0.0
	w.pumps_done = 0
	wing_behavior_started.emit(w.sprite, w.behavior)

func _finish_behavior(w: WingState) -> void:
	w.sprite.position = w.base_position
	w.sprite.scale = Vector3.ONE
	var finished_behavior := w.behavior
	w.behavior = -1
	w.state_time = 0.0
	w.pumps_done = 0
	w.next_trigger_in = randf_range(wing_interval_min, wing_interval_max)
	wing_behavior_finished.emit(w.sprite, finished_behavior)

func _run_tremble(w: WingState) -> void:
	if w.state_time >= tremble_duration:
		_finish_behavior(w)
		return
	var t := w.state_time
	var jitter := Vector3(
		sin(t * tremble_speed) * tremble_amplitude,
		cos(t * tremble_speed * 1.3) * tremble_amplitude,
		0.0
	)
	w.sprite.position = w.base_position + jitter

func _run_pump(w: WingState) -> void:
	var cycle_index := int(w.state_time / pump_duration)
	if cycle_index >= pump_count:
		_finish_behavior(w)
		return
	var local_t := fmod(w.state_time, pump_duration) / pump_duration
	var f := sin(PI * local_t) # 0 -> 1 -> 0 within each pulse
	# ponytail/known-pitfall: `lerp()` has multiple overloads (float/Vector2/
	# Vector3/...), so `:=` can't statically resolve its return type and
	# GDScript treats that as an error-level warning here -- explicit
	# `: float` (not inferred) sidesteps it, same workaround speaker.gd uses
	# by inlining lerp() calls instead of assigning them via `:=`.
	var s: float = lerp(1.0, pump_scale, f)
	w.sprite.scale = Vector3(s, s, s)

func _run_stretch(w: WingState) -> void:
	if w.state_time >= stretch_duration:
		_finish_behavior(w)
		return
	var f := sin(PI * (w.state_time / stretch_duration)) # 0 -> 1 -> 0
	w.sprite.scale = Vector3(1.0, lerp(1.0, stretch_scale, f), 1.0)
