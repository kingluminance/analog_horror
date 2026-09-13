extends Sprite3D

# ponytail: shared per-frame sine bob; if dozens of these end up on screen at once
# and the synced motion reads as artificial, give each instance its own noise curve instead.
@export var bob_height := 0.15
@export var bob_speed := 0.6

var _base_y: float
var _time_offset: float

func _ready() -> void:
	_base_y = position.y
	_time_offset = randf() * TAU

func _process(_delta: float) -> void:
	position.y = _base_y + sin(Time.get_ticks_msec() / 1000.0 * bob_speed + _time_offset) * bob_height
