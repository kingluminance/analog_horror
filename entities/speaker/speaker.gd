extends Node3D
## Novelty gramophone-style prop: a large box body with a brass horn on
## top, flipped upside-down. Both pump along with the composite track
## while it's actually playing (StoryFlags flag "gramophone_playing")
## -- horn does a squash-and-stretch (stretches wide left-right while
## squashing vertically), box just stretches vertically -- and sit
## still (scale 1) whenever the song isn't on. No real audio analysis --
## just a fast repeating envelope, since it only needs to feel roughly
## in time, not be exact.

@export var pump_interval := 0.28 # seconds per pump cycle -- fast on purpose
@export var pump_attack := 0.05 # seconds to snap up to peak scale (fast)

# Horn: classic squash-and-stretch, not a uniform scale pump -- at the
# peak it stretches wide left-right (X) while squashing a little
# vertically (Y), like it's ripping open sideways.
@export var pump_scale_x := 3.5 # peak horizontal stretch
@export var pump_scale_y := 2.0 # peak vertical squash (counter-motion)

# Box: just a vertical pulse, no horizontal stretch -- "위아래로".
@export var box_pump_scale_y := 1.4 # peak vertical stretch

var _time_offset: float

@onready var _horn: Sprite3D = $Horn
@onready var _box: Sprite3D = $Box

func _ready() -> void:
	_horn.rotation_degrees.z = 180.0
	_time_offset = randf() * pump_interval

func _process(_delta: float) -> void:
	if not StoryFlags.get_flag("gramophone_playing"):
		_horn.scale = Vector3.ONE
		_box.scale = Vector3.ONE
		return

	var t := fmod(Time.get_ticks_msec() / 1000.0 + _time_offset, pump_interval)
	var f: float
	if t < pump_attack:
		# quick snap out to the exaggerated stretch
		f = t / pump_attack
	else:
		# ease back to normal shape for the rest of the cycle
		f = 1.0 - smoothstep(0.0, 1.0, (t - pump_attack) / (pump_interval - pump_attack))
	_horn.scale = Vector3(lerp(1.0, pump_scale_x, f), lerp(1.0, pump_scale_y, f), 1.0)
	_box.scale = Vector3(1.0, lerp(1.0, box_pump_scale_y, f), 1.0)
