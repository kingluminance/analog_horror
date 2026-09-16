extends Node3D
## Ellikonti (엘리콘티) -- ground-anchored NPC that is always visibly
## trembling with fear, and periodically mutters short fear-words to itself
## even when no conversation is open. First real (non-test) consumer of the
## dialogue-extension interface documented in CLAUDE.md
## (unskippable/tremble_level/reveal_chars_per_second on AnalogDialogueBalloon
## + MutterLabel.say()).
##
## Deeply afraid of "the great wings" (기록된 날개 -- a different entity built
## on a separate branch this script has zero runtime knowledge of; the fear is
## pure dialogue flavor, see ellikonti.dialogue).
##
## Shake is sum-of-incommensurate-sines, same recipe as speaker.gd's pump
## envelope being a fast repeating envelope rather than per-frame randf() --
## a few sine waves at unrelated frequencies/phases summed together reads as
## a continuous full-body shiver instead of single-frame jitter/popping.
## Only the child Visual (Sprite3D) is moved/rotated by the shake -- this
## node's own position/rotation, and the sibling Interactable anchored to it,
## are left completely still so Interactable's range/facing math (which reads
## this node's global_position + hint_offset, see interactable.gd) stays
## stable. Same reasoning already established for red_bouncy_ball.gd's bounce
## and orbiting_paddle's fast orbit -- keep Interactable off of anything that
## moves every frame.

@export var tremble_intensity := 0.035 # meters, peak position jitter
@export var tremble_speed := 1.0 # multiplies every sine frequency below

# Rotation shake (z-axis "shivering" wobble), kept separate from the
# position jitter so the two knobs can be tuned independently -- rotation
# reads more like "flinching," small position jitter reads more like a
# literal shiver.
@export var tremble_rotation_degrees := 3.0

# Ambient mutter timer: irregular interval, not a fixed Timer.wait_time --
# picks a new random interval after every mutter so it doesn't read as a
# metronome.
@export var mutter_interval_min := 4.0
@export var mutter_interval_max := 9.0

const MUTTER_LINES := [
	"무서워...",
	"가지마...",
	"...날개.",
	"보지마...",
	"조용히... 조용히...",
	"흑...",
]

var _time_offset: float
var _mutter_timer := 0.0
var _next_mutter_delay := 0.0

# Captured in _ready() from whatever the .tscn set Visual's position/rotation
# to (the ground-anchoring offset that lifts the sprite so its feet touch
# y=0) -- same pattern as floating_photo.gd's _base_y. The shake below is
# added on TOP of this base every frame, never replaces it.
var _base_visual_position: Vector3
var _base_visual_rotation_z: float

@onready var _visual: Sprite3D = $Visual
@onready var _mutter: MutterLabel = $MutterLabel

# Sum of a few sine waves at deliberately unrelated (non-integer-ratio)
# frequencies/phases -- the incommensurate frequencies keep the combined
# motion from ever settling into an obvious repeating loop, so it reads as
# a continuous nervous shiver rather than a wobble you can predict.
const _FREQS := [11.3, 17.7, 23.1]
const _ROT_FREQS := [13.9, 21.4]


func _ready() -> void:
	_time_offset = randf() * TAU
	_base_visual_position = _visual.position
	_base_visual_rotation_z = _visual.rotation_degrees.z
	_roll_next_mutter_delay()


func _process(delta: float) -> void:
	_update_tremble()
	_update_mutter(delta)


func _update_tremble() -> void:
	var t := Time.get_ticks_msec() / 1000.0 * tremble_speed + _time_offset

	var jitter := Vector3.ZERO
	jitter.x = sin(t * _FREQS[0]) + 0.5 * sin(t * _FREQS[1] + 1.7)
	jitter.y = cos(t * _FREQS[1]) + 0.5 * sin(t * _FREQS[2] + 0.6)
	# Normalize the (roughly [-1.5, 1.5]) sum back to unit range before
	# scaling by tremble_intensity, so the export stays in real meters.
	jitter = jitter / 1.5 * tremble_intensity
	_visual.position = _base_visual_position + jitter

	var rot := sin(t * _ROT_FREQS[0]) + 0.5 * sin(t * _ROT_FREQS[1] + 2.2)
	_visual.rotation_degrees.z = _base_visual_rotation_z + (rot / 1.5) * tremble_rotation_degrees


func _update_mutter(delta: float) -> void:
	_mutter_timer += delta
	if _mutter_timer >= _next_mutter_delay:
		_mutter_timer = 0.0
		_roll_next_mutter_delay()
		_mutter.say(MUTTER_LINES[randi() % MUTTER_LINES.size()])


func _roll_next_mutter_delay() -> void:
	_next_mutter_delay = randf_range(mutter_interval_min, mutter_interval_max)
