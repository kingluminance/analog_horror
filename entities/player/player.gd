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

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	DialogueManager.dialogue_started.connect(func(_res):
		_dialogue_active = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	)
	DialogueManager.dialogue_ended.connect(func(_res):
		_dialogue_active = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)

func _unhandled_input(event: InputEvent) -> void:
	# Escape/mouse-mode while playing is the pause menu's job now (ui/pause_menu.gd).
	if _dialogue_active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)

func _physics_process(delta: float) -> void:
	if _dialogue_active:
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
