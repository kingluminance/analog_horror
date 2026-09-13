extends Sprite3D
## Small companion object that spins in place next to the brain-in-vat NPC.
## Billboarded Sprite3D always rotates its quad to face the camera every
## frame, which discards any `rotation` change entirely - a plain
## `rotation.y += speed*delta` would have zero visible effect here. Instead
## this fakes a continuous spin with the classic billboard-flip trick:
## oscillate local scale.x between +1 and -1 through 0 via cos(time*speed).
## Since the sprite still always faces the camera, this reads as an actual
## spin from any angle, not just a flat left-right flip.

@export var spin_speed := 6.0 # radians per second - reads as "조금 빠른" spin

var _time_offset: float

func _ready() -> void:
	_time_offset = randf() * TAU

func _process(_delta: float) -> void:
	scale.x = cos(Time.get_ticks_msec() / 1000.0 * spin_speed + _time_offset)
