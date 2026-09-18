extends CharacterBody3D

const SPEED := 5.0
const MOUSE_SENSITIVITY := 0.003
const STEP_DISTANCE := 1.7

@onready var camera: Camera3D = $Camera3D
@onready var footstep_player: AudioStreamPlayer = $FootstepPlayer

var footstep_sounds: Array[AudioStream] = [
	preload("res://audio/footstep_0.wav"),
	preload("res://audio/footstep_1.wav"),
	preload("res://audio/footstep_2.wav"),
]

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
# Dialogue owns the mouse (for choosing responses) and pauses movement while it's up.
var _dialogue_active := false
var _step_distance := 0.0

const FORCED_LOOK_TURN_SPEED := 4.0 # lerp weight/sec, tuned by feel not physics
# A scripted "look toward this point" nudge (e.g. the bottari merchant
# snapping the camera to itself when its greeting dialogue opens). Not a
# hard lock -- any mouse motion cancels it immediately, same spirit as
# skippable dialogue lines elsewhere in this project. Runs during dialogue
# too (that's the whole point), so it's driven from _physics_process
# regardless of _dialogue_active.
var _forced_look_active := false
var _forced_look_target := Vector3.ZERO

# Separate from _dialogue_active: a real DialogueManager dialogue (like a
# merchant's "구매하시겠어요?" confirm) naturally ends and clears
# _dialogue_active right when a scripted cutscene (e.g. a delivery
# mini-cutscene) needs the lock to keep holding -- so cutscenes call
# set_cutscene_lock() instead of piggybacking on the dialogue flag.
var _cutscene_locked := false

func _is_input_locked() -> bool:
	return _dialogue_active or _cutscene_locked

## Nudges the camera to face `target_position`, breakable by any mouse
## motion. Call again each frame with a moving target (e.g. a companion
## mid-flight) to get a "camera tracks the moving thing" cutscene effect.
func force_look_at(target_position: Vector3) -> void:
	_forced_look_active = true
	_forced_look_target = target_position

## Cutscenes (e.g. the bottari merchant's delivery sequence) call this
## instead of relying on _dialogue_active, since that flag clears the
## instant the triggering dialogue balloon closes -- before the cutscene
## itself is done. Mirrors _dialogue_active's own mouse-mode handling.
func set_cutscene_lock(locked: bool) -> void:
	_cutscene_locked = locked
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if locked else Input.MOUSE_MODE_CAPTURED

func _update_forced_look(delta: float) -> void:
	var to_target := _forced_look_target - camera.global_position
	var horizontal := Vector2(to_target.x, to_target.z)
	if horizontal.length() < 0.05:
		_forced_look_active = false
		return
	# Yaw: reuse the same look_at()-based technique recorded_wings.gd
	# already uses for "which way should this face to see the camera" --
	# safer than hand-deriving atan2 sign conventions here.
	var desired_basis := Transform3D(Basis(), global_position).looking_at(_forced_look_target, Vector3.UP).basis
	rotation.y = lerp_angle(rotation.y, desired_basis.get_euler().y, clamp(delta * FORCED_LOOK_TURN_SPEED, 0.0, 1.0))
	# Pitch is frame-independent of the body's yaw, so plain trig is simpler
	# and just as correct here.
	var target_pitch := atan2(to_target.y, horizontal.length())
	camera.rotation.x = lerp_angle(camera.rotation.x, clamp(target_pitch, -PI / 2, PI / 2), clamp(delta * FORCED_LOOK_TURN_SPEED, 0.0, 1.0))

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Starting RPG-ish stats -- values/roster are placeholders, add more
	# with another register_stat() call whenever a new one is needed.
	Stats.register_stat("hp", "HP", 1,5)
	Stats.register_stat("aggression", "공격성", 1, 5)
	Stats.register_stat("flexibility", "유연성", 1, 5)
	Stats.register_stat("level", "레벨", 5, 5, false) # no cap -- ordinary level growth
	DialogueManager.dialogue_started.connect(func(_res):
		_dialogue_active = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	)
	DialogueManager.dialogue_ended.connect(func(_res):
		_dialogue_active = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _forced_look_active:
		_forced_look_active = false
	# Escape/mouse-mode while playing is the binder UI's job now (ui/binder/binder_ui.gd).
	if _is_input_locked():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)

func _physics_process(delta: float) -> void:
	if _forced_look_active:
		_update_forced_look(delta)

	if _is_input_locked():
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	input_dir = input_dir.normalized()

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if direction and is_on_floor():
		_step_distance += Vector2(velocity.x, velocity.z).length() * delta
		if _step_distance >= STEP_DISTANCE:
			_step_distance = 0.0
			footstep_player.stream = footstep_sounds.pick_random()
			footstep_player.pitch_scale = randf_range(0.9, 1.1)
			footstep_player.play()
	else:
		_step_distance = STEP_DISTANCE  # step right away on the next move

	move_and_slide()
