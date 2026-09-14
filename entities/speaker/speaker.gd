extends Node3D
## Novelty gramophone-style prop: a large box body with a brass horn
## spinning on top. Only the horn moves -- the box is static.

@export var spin_speed := 2.5 # radians per second

@onready var _horn: Sprite3D = $Horn

func _ready() -> void:
	_horn.rotation_degrees.z = 180.0

func _process(delta: float) -> void:
	# Horn's billboard is deliberately OFF (unlike floating_photo/trash_angel):
	# a billboarded Sprite3D recomputes its whole basis to face the camera
	# every frame and discards manual rotation entirely (see
	# spinning_trinket.gd, which has to fake spin via a scale.x flip
	# because of this). Horn instead stays flat and genuinely rotates
	# around its own local Z axis -- the quad's face-on plane -- which reads
	# as a real clockwise spin as long as the player is roughly in front of
	# it (billboard would fight this rotation, not help it).
	_horn.rotation.z -= spin_speed * delta
