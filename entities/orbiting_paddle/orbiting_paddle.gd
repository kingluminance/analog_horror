extends Sprite3D
## Circles around its parent's origin at a fixed radius/height, on a tilted
## orbit plane — used to make the ping pong paddle orbit around the bottle
## creature. Also supports E-to-talk (same pattern as floating_photo.gd), but
## with a much tighter facing cone since this target keeps moving — the
## player has to actually track it, not just be nearby.

@export var orbit_radius := 1.3
@export var orbit_speed := 3.5 # radians per second
@export var orbit_height := 0.0 # local Y offset from the parent's origin (orbit center)
@export var tilt_degrees := 30.0 # how far the orbit plane leans from flat/horizontal

# Optional — leave unset for a silent orbiting paddle with no interaction.
@export var dialogue_resource: DialogueResource
@export var dialogue_start_title := "start"
@export var facing_angle_degrees := 10.0 # tight on purpose — must be aimed right at the paddle

var _angle := 0.0
var _player_in_range := false
# ponytail: DialogueManager exposes no "is running" property, only start/end signals —
# track it locally. Fine even with multiple instances since only one dialogue runs at a time.
var _dialogue_running := false

@onready var _range: Area3D = $InteractRange
@onready var _hint: Label3D = $InteractRange/InteractHint

func _ready() -> void:
	_angle = randf() * TAU # avoid every orbiter starting at the same spot
	if dialogue_resource:
		_range.body_entered.connect(_on_body_entered)
		_range.body_exited.connect(_on_body_exited)
		DialogueManager.dialogue_started.connect(func(_res): _dialogue_running = true)
		DialogueManager.dialogue_ended.connect(func(_res): _dialogue_running = false)
	else:
		_range.monitoring = false
		_hint.hide()

func _process(delta: float) -> void:
	_angle += orbit_speed * delta
	var flat := Vector3(cos(_angle) * orbit_radius, 0.0, sin(_angle) * orbit_radius)
	var tilted := flat.rotated(Vector3.RIGHT, deg_to_rad(tilt_degrees))
	position = tilted + Vector3(0.0, orbit_height, 0.0)
	if dialogue_resource and _player_in_range:
		_hint.visible = _is_player_facing()

func _unhandled_input(event: InputEvent) -> void:
	if not dialogue_resource or not _player_in_range or not _is_player_facing():
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		if not _dialogue_running:
			DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_start_title)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_in_range = true

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_in_range = false
		_hint.hide()

# True when the active camera is pointed (tightly) at the paddle right now —
# it's a moving target, so proximity alone isn't nearly enough.
func _is_player_facing() -> bool:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return true
	var to_self := global_position - cam.global_position
	if to_self.length() < 0.001:
		return true
	var forward := -cam.global_transform.basis.z
	return forward.normalized().dot(to_self.normalized()) >= cos(deg_to_rad(facing_angle_degrees))
