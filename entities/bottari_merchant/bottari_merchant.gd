extends Node3D
## Root of "보따리로 판매합니다" (Bottari Merchant) -- a padlock-with-lips
## face floating above the ground, with two independent eyeball-keyring
## sprites drifting lazily nearby. Sells small locksmith/keyring-flavored
## trinkets via the shared ShopWatcher component (see the ShopWatcher child
## in bottari_merchant.tscn) once its dialogue's greeting choice opens the
## shop.
##
## Face bob reuses floating_photo.gd's exact sine-bob idiom (same formula,
## same per-instance randf() phase offset so it doesn't sync with other
## bobbing NPCs) -- just applied to the Face child Sprite3D's position
## instead of the script's own node, since this entity's root is a plain
## Node3D (so Interactable/ShopWatcher can sit as still siblings, same
## reasoning ellikonti.gd documents for why Interactable never wants to be
## nested under something that moves every frame).
##
## Companions (CompanionA/CompanionB) do NOT use recorded_wings.gd's
## root-only look_at() trick -- that trick only earns its complexity when
## several sprites are hand-posed at fixed relative angles to each other
## and need to turn as one rigid unit (see recorded_wings.gd's docstring).
## These two have no fixed relative pose at all, they just wander near the
## face independently -- so each is simply billboard = 1 on its own (set in
## bottari_merchant.tscn) and this script never touches their rotation.
## Each companion gets its own randomized phase/speed per axis in _ready()
## (same "randf() per instance so synced motion doesn't read as artificial"
## spirit as floating_photo.gd's _time_offset) so CompanionA and CompanionB
## read as two independent drifters, not mirrored twins.

@export var bob_height := 0.15
@export var bob_speed := 0.6

## Roughly how far (meters) each companion wanders from its own resting
## spot -- a slow lazy wander, not a fast tilted orbit like
## orbiting_paddle.gd.
@export var companion_drift_radius := 0.35
@export var companion_drift_speed_min := 0.15 # rad/s
@export var companion_drift_speed_max := 0.35 # rad/s

class CompanionDrift:
	var sprite: Sprite3D
	var base_position: Vector3
	var phase: Vector3
	var speed: Vector3

var _base_face_y: float
var _face_time_offset: float
var _companions: Array[CompanionDrift] = []

@onready var _face: Sprite3D = $Face

func _ready() -> void:
	_base_face_y = _face.position.y
	_face_time_offset = randf() * TAU
	for node in [$CompanionA, $CompanionB]:
		var c := CompanionDrift.new()
		c.sprite = node
		c.base_position = node.position
		c.phase = Vector3(randf(), randf(), randf()) * TAU
		c.speed = Vector3(
			randf_range(companion_drift_speed_min, companion_drift_speed_max),
			randf_range(companion_drift_speed_min, companion_drift_speed_max),
			randf_range(companion_drift_speed_min, companion_drift_speed_max)
		)
		_companions.append(c)

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_face.position.y = _base_face_y + sin(t * bob_speed + _face_time_offset) * bob_height
	for c in _companions:
		c.sprite.position = c.base_position + Vector3(
			sin(t * c.speed.x + c.phase.x) * companion_drift_radius,
			sin(t * c.speed.y + c.phase.y) * companion_drift_radius * 0.7,
			sin(t * c.speed.z + c.phase.z) * companion_drift_radius * 0.5
		)
