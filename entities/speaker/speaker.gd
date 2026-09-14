extends Node3D
## Novelty gramophone-style prop: a large box body with a brass horn on
## top, flipped upside-down and pumping in size like it's talking/pulsing
## along with music that plays near it. No real audio analysis -- just a
## fast repeating scale envelope, since it only needs to feel roughly in
## time, not be exact.

@export var pump_interval := 0.28 # seconds per pump cycle -- fast on purpose
@export var pump_scale := 1.4 # peak scale multiplier at the top of each pump
@export var pump_attack := 0.05 # seconds to snap up to peak scale (fast)

var _time_offset: float

@onready var _horn: Sprite3D = $Horn

func _ready() -> void:
	_horn.rotation_degrees.z = 180.0
	_time_offset = randf() * pump_interval

func _process(_delta: float) -> void:
	var t := fmod(Time.get_ticks_msec() / 1000.0 + _time_offset, pump_interval)
	var s: float
	if t < pump_attack:
		# quick snap up to the exaggerated peak
		s = lerp(1.0, pump_scale, t / pump_attack)
	else:
		# ease back down to normal size for the rest of the cycle
		var f := (t - pump_attack) / (pump_interval - pump_attack)
		s = lerp(pump_scale, 1.0, smoothstep(0.0, 1.0, f))
	_horn.scale = Vector3.ONE * s
