extends Node3D
## Small red ball that bounces in place at a fixed XZ anchor (ground at y=0).
## Scripted procedural bounce, not RigidBody3D physics — consistent with every
## other entity's motion in this project (floating_photo.gd's sine bob,
## orbiting_paddle.gd's circular math).
##
## Only the child MeshInstance3D is moved/scaled by the bounce+squash math.
## This node's own `position` is left untouched so it stays a stable ground
## anchor for the sibling Interactable (E-to-talk range/facing checks would
## jitter with the fast bounce cycle otherwise).

@export var bounce_height := 1.0
@export var bounce_duration := 0.8

# Squash-and-stretch tuning: how strong the flatten gets at ground contact,
# and how much of the bounce cycle (near t=0 and t=bounce_duration) counts
# as "near contact" and therefore squashes.
@export var max_squash := 0.35
@export var squash_window := 0.15

@onready var _mesh: MeshInstance3D = $MeshInstance3D

var _time_elapsed := 0.0

func _ready() -> void:
	Inventory.register_item("red_marble", "빨간 구슬", preload("res://entities/red_bouncy_ball/red_marble.png"), "빨간 공한테서 굴러나온 작은 구슬.")

func _process(delta: float) -> void:
	_time_elapsed += delta
	var t := fmod(_time_elapsed, bounce_duration)
	var phase := t / bounce_duration
	_mesh.position.y = 4.0 * bounce_height * phase * (1.0 - phase)

	# phase 0 and phase 1 both mean "on the ground" — squash ramps up as we
	# approach either end of the cycle and springs back to Vector3.ONE
	# everywhere else (mid-arc).
	var dist_from_contact: float = min(phase, 1.0 - phase)
	var squash := 0.0
	if dist_from_contact < squash_window:
		squash = max_squash * (1.0 - dist_from_contact / squash_window)
	_mesh.scale = Vector3(1.0 + squash * 0.5, 1.0 - squash, 1.0 + squash * 0.5)
