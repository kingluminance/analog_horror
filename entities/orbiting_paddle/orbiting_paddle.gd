extends Sprite3D
## Circles around its parent's origin at a fixed radius/height, on a tilted
## orbit plane — used to make the ping pong paddle orbit around the bottle
## creature. E-to-talk is handled by the `Interactable` child node (see
## orbiting_paddle.tscn), configured there with a much tighter facing cone
## since this target keeps moving — the player has to actually track it.

@export var orbit_radius := 1.3
@export var orbit_speed := 3.5 # radians per second
@export var orbit_height := 0.0 # local Y offset from the parent's origin (orbit center)
@export var tilt_degrees := 30.0 # how far the orbit plane leans from flat/horizontal

var _angle := 0.0

func _ready() -> void:
	_angle = randf() * TAU # avoid every orbiter starting at the same spot

func _process(delta: float) -> void:
	_angle += orbit_speed * delta
	var flat := Vector3(cos(_angle) * orbit_radius, 0.0, sin(_angle) * orbit_radius)
	var tilted := flat.rotated(Vector3.RIGHT, deg_to_rad(tilt_degrees))
	position = tilted + Vector3(0.0, orbit_height, 0.0)
