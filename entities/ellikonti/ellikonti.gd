extends Node3D
## Ellikonti (엘리콘티) -- ground-anchored NPC that is always visibly
## trembling with fear, and periodically mutters short fear-words to itself
## even when no conversation is open. First real (non-test) consumer of the
## dialogue-extension interface documented in CLAUDE.md
## (unskippable/tremble_level/reveal_chars_per_second on AnalogDialogueBalloon
## + MutterLabel.say()).
##
## Body is a low-poly 3D model (ellikonti.glb, built by model/build_ellikonti.py
## from the user's shape sketch) with PS1-style materials
## (shaders/retro_character.gdshader). The face is NOT geometry: it is three
## swappable texture layers (eyes / mouth / extra) the head material projects
## onto the head -- see EXPRESSIONS / set_expression(). Dialogue switches it
## through the existing StoryFlags visual-state mechanism:
##   $> StoryFlags.set_visual_state("ellikonti", "face", "panic")
##
## Deeply afraid of "the great wings" (기록된 날개 -- a different entity built
## on a separate branch this script has zero runtime knowledge of; the fear is
## pure dialogue flavor, see ellikonti.dialogue).
##
## Shake is sum-of-incommensurate-sines, same recipe as speaker.gd's pump
## envelope being a fast repeating envelope rather than per-frame randf() --
## a few sine waves at unrelated frequencies/phases summed together reads as
## a continuous full-body shiver instead of single-frame jitter/popping.
## Only the child Visual (Node3D holding the model) is moved/rotated by the shake -- this
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

# She only turns to stare at the player once they come within look_radius
# (horizontal metres); further away she turns back to her resting direction
# (whatever yaw Visual has in the scene). Applied to Visual only.
@export var look_radius := 4.0
@export var turn_speed := 2.5
# Within look_radius she also tilts her head (hat and star ride along, they
# are children of Head in the .glb) up toward the player's eyes.
@export var max_look_up_degrees := 35.0

# Expression name -> [eyes, mouth, extra] layer textures in faces/.
const EXPRESSIONS := {
	"default": ["eyes_default", "mouth_default", "extra_none"],
	"scared": ["eyes_default", "mouth_wavy", "extra_sweat"],
	"panic": ["eyes_panic", "mouth_open", "extra_sweat"],
	"cry": ["eyes_teary", "mouth_wavy", "extra_tears"],
	"tired": ["eyes_halflid", "mouth_small", "extra_none"],
	"flustered": ["eyes_closed", "mouth_wavy", "extra_blush"],
	# Contract cutscene: eyes staring two different ways, painted mouth
	# blanked because the cutscene's 3D TearMouth takes over.
	"contract": ["eyes_diverge", "mouth_none", "extra_none"],
}
const FACE_DIR := "res://entities/ellikonti/faces/"
const CONTRACT_CUTSCENE := preload("res://entities/ellikonti/contract_cutscene/contract_cutscene.tscn")
const BLINK_TIME := 0.12

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

var _face_material: ShaderMaterial
var _expression := "default"
var _blink_timer := 0.0
var _next_blink := 3.0
var _bell: Node3D
var _bell_base_rotation: Vector3
var _star: Node3D
var _star_base_position: Vector3
var _rest_yaw: float
var _in_cutscene := false
var _head: Node3D
var _head_base_pitch: float

@onready var _visual: Node3D = $Visual
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

	# owned=false: these live inside the instanced .glb scene.
	var head := _visual.find_child("Head", true, false) as MeshInstance3D
	_head = head
	_head_base_pitch = head.rotation.x
	_bell = _visual.find_child("Bell", true, false) as Node3D
	_star = _visual.find_child("Star", true, false) as Node3D
	_rest_yaw = _visual.rotation.y
	_bell_base_rotation = _bell.rotation
	_star_base_position = _star.position
	# Own copy of the head material so swapping face layers never touches
	# the shared ek_head.tres resource on disk.
	var shared_mat := head.get_active_material(0) as ShaderMaterial
	_face_material = shared_mat.duplicate() as ShaderMaterial
	head.set_surface_override_material(0, _face_material)

	StoryFlags.visual_state_changed.connect(_on_visual_state_changed)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	var start_face: String = StoryFlags.get_visual_state("ellikonti", "face", "default")
	set_expression(start_face)


func _process(delta: float) -> void:
	_update_tremble()
	_update_facing(delta)
	_update_trinkets()
	_update_blink(delta)
	_update_mutter(delta)


func set_expression(expression_name: String) -> void:
	if not EXPRESSIONS.has(expression_name):
		push_warning("Ellikonti: unknown expression '%s'" % expression_name)
		return
	_expression = expression_name
	var layers: Array = EXPRESSIONS[expression_name]
	_face_material.set_shader_parameter("face_eyes", load(FACE_DIR + layers[0] + ".png"))
	_face_material.set_shader_parameter("face_mouth", load(FACE_DIR + layers[1] + ".png"))
	_face_material.set_shader_parameter("face_extra", load(FACE_DIR + layers[2] + ".png"))


func _on_visual_state_changed(id: String, key: String, value) -> void:
	if id == "ellikonti" and key == "face":
		set_expression(str(value))


# The .dialogue sets faces mid-conversation; whichever way it ends (many
# "=> END" exits), she goes back to her resting face.
# The contract (any route) ends the dialogue with ellikonti_contracted set:
# go straight into the cutscene on the same frame, so the player never gets
# control back in between ("대화 직후에 계속 경직").
func _on_dialogue_ended(resource: DialogueResource) -> void:
	if resource != $Interactable.dialogue_resource:
		return
	if StoryFlags.get_flag("ellikonti_contracted") and not StoryFlags.get_flag("ellikonti_contract_cutscene_seen")\
			and not _in_cutscene:
		_start_contract_cutscene()
		return
	StoryFlags.set_visual_state("ellikonti", "face", "default")


func _start_contract_cutscene() -> void:
	_in_cutscene = true
	$Interactable.process_mode = Node.PROCESS_MODE_DISABLED
	$Interactable.visible = false
	set_expression("contract")
	var cutscene := CONTRACT_CUTSCENE.instantiate()
	add_child(cutscene)
	cutscene.rotation.y = _visual.rotation.y  # local +Z = toward the player
	cutscene.start(self, _visual, _head)


# Yaw only, on Visual only -- the root and its Interactable never rotate.
# The model faces local +Z.
func _update_facing(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_cam := cam.global_position - global_position
	var dist := Vector2(to_cam.x, to_cam.z).length()
	if dist < 0.01:
		return
	var target := _rest_yaw
	var pitch := 0.0
	if dist <= look_radius:
		target = atan2(to_cam.x, to_cam.z) - global_rotation.y
		var to_eyes := cam.global_position - _head.global_position
		var flat := Vector2(to_eyes.x, to_eyes.z).length()
		pitch = clampf(atan2(to_eyes.y, flat), 0.0, deg_to_rad(max_look_up_degrees))
	# Model faces +Z, so a negative X rotation lifts the face.
	_head.rotation.x = lerp_angle(_head.rotation.x, _head_base_pitch - pitch,
			clampf(turn_speed * delta, 0.0, 1.0))
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target, clampf(turn_speed * delta, 0.0, 1.0))


# Bell on the hat rattles with the shiver; the star bobs and sways (a full
# spin would show it edge-on as a flat plank half the time).
func _update_trinkets() -> void:
	var t := Time.get_ticks_msec() / 1000.0 + _time_offset
	var shiver := sin(t * _FREQS[2]) + 0.6 * sin(t * _ROT_FREQS[1] + 0.9)
	_bell.rotation = _bell_base_rotation + Vector3(shiver * 0.12, 0.0, sin(t * 3.1) * 0.15)
	_star.position = _star_base_position + Vector3(0.0, sin(t * 1.7) * 0.025, 0.0)
	_star.rotation.y = sin(t * 0.8) * 0.6


# Occasional blink: eyes layer alone flips to "closed" for a moment, unless
# the current expression already has its eyes shut.
func _update_blink(delta: float) -> void:
	if _in_cutscene:
		return
	_blink_timer += delta
	if _blink_timer >= _next_blink:
		var eyes: String = EXPRESSIONS[_expression][0]
		if eyes != "eyes_closed":
			_face_material.set_shader_parameter("face_eyes", load(FACE_DIR + "eyes_closed.png"))
		if _blink_timer >= _next_blink + BLINK_TIME:
			_face_material.set_shader_parameter("face_eyes", load(FACE_DIR + eyes + ".png"))
			_blink_timer = 0.0
			_next_blink = randf_range(2.0, 6.0)


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
	if _in_cutscene:
		return
	_mutter_timer += delta
	if _mutter_timer >= _next_mutter_delay:
		_mutter_timer = 0.0
		_roll_next_mutter_delay()
		_mutter.say(MUTTER_LINES[randi() % MUTTER_LINES.size()])


func _roll_next_mutter_delay() -> void:
	_next_mutter_delay = randf_range(mutter_interval_min, mutter_interval_max)
