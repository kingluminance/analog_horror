extends Node3D
## Novelty gramophone-style prop: a large box body with a brass horn on
## top, flipped upside-down. Both pump along with the composite track
## while it's actually playing (StoryFlags flag "gramophone_playing")
## -- horn does a squash-and-stretch (stretches wide left-right while
## squashing vertically), box just stretches vertically -- and sit
## still (scale 1) whenever the song isn't on. No real audio analysis --
## just a fast repeating envelope, since it only needs to feel roughly
## in time, not be exact.
##
## Also gives chase once the song is on: walks toward the player (camera
## position, same proxy interactable.gd already uses -- no "player"
## group exists in this project) up to chase_radius away from its own
## spawn point, then walks back home once that leash is hit (or the
## song stops). Interactable/GramophoneAudio are children, so the E
## range and the 3D audio panning move along with it for free. The very
## first time it ever reaches the player it closes in all the way (a
## one-time jump-scare beat) -- every chase after that keeps
## chase_stop_distance away instead, since crowding the camera every
## single time just made the [E] hint hard to see.

@export var pump_interval := 0.28 # seconds per pump cycle -- fast on purpose
@export var pump_attack := 0.05 # seconds to snap up to peak scale (fast)

# Horn: classic squash-and-stretch, not a uniform scale pump -- at the
# peak it stretches wide left-right (X) while squashing a little
# vertically (Y), like it's ripping open sideways.
@export var pump_scale_x := 3.5 # peak horizontal stretch
@export var pump_scale_y := 2.0 # peak vertical squash (counter-motion)

# Box: just a vertical pulse, no horizontal stretch -- "위아래로".
@export var box_pump_scale_y := 1.4 # peak vertical stretch

@export var chase_speed := 3.0 # m/s while giving chase
@export var chase_radius := 8.0 # how far from home it'll stray before giving up
@export var chase_stop_distance := 2.0 # keeps at least this far from the
	# player on every chase after the first
@export var return_speed := 2.0 # m/s while walking back home

var _time_offset: float
var _home_position: Vector3
# Once true, commits to walking all the way home before it'll consider
# chasing again -- without this, hovering right at chase_radius
# flip-flops chase/return every single frame and gets stuck in place.
var _returning_home := false
# Set once it ever actually reaches the player (closes to near 0m) --
# from then on chase_stop_distance applies instead of closing all the way.
var _has_closed_in_once := false

@onready var _horn: Sprite3D = $Horn
@onready var _box: Sprite3D = $Box

func _ready() -> void:
	_horn.rotation_degrees.z = 180.0
	_time_offset = randf() * pump_interval
	_home_position = global_position

func _process(delta: float) -> void:
	_update_pump()
	_update_chase(delta)

func _update_pump() -> void:
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

func _update_chase(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var dist_from_home := global_position.distance_to(_home_position)

	if not _returning_home and cam and StoryFlags.get_flag("gramophone_playing") and dist_from_home < chase_radius:
		var to_player := cam.global_position - global_position
		to_player.y = 0.0
		var stop_at := 0.05 if not _has_closed_in_once else chase_stop_distance
		if to_player.length() > stop_at:
			global_position += to_player.normalized() * chase_speed * delta
		else:
			_has_closed_in_once = true
		if global_position.distance_to(_home_position) >= chase_radius:
			_returning_home = true
		return

	# not playing, or hit the end of its leash -- commit to walking all
	# the way back home before it'll chase again
	var to_home := _home_position - global_position
	to_home.y = 0.0
	if to_home.length() > 0.05:
		global_position += to_home.normalized() * return_speed * delta
	else:
		global_position = _home_position
		_returning_home = false
