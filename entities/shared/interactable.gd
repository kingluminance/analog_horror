class_name Interactable
extends Area3D
## Reusable E-to-talk component: proximity detection + facing-check gate +
## "[E]" hint + dialogue trigger. Any entity that wants dialogue instances
## `interactable.tscn` as a child (anywhere in its tree — doesn't have to be
## at the visual root; e.g. a bouncing object can anchor this at a fixed
## height instead of wherever the bouncing mesh currently is) and sets
## `dialogue_resource`. Leave `dialogue_resource` unset for a silent,
## fully-disabled interactable.
##
## Extracted from floating_photo.gd / orbiting_paddle.gd, which had each
## independently grown the same ~25-line block — this is now the one copy.

@export var dialogue_resource: DialogueResource
@export var dialogue_start_title := "start"

# Player must be looking roughly at this object (within this half-angle, in
# degrees, of dead-center) for E to work — proximity alone isn't enough.
@export var facing_angle_degrees := 35.0

@export var range_radius := 1.8:
	set(value):
		range_radius = value
		if _shape:
			_shape.shape.radius = value

@export var hint_offset := Vector3(0, 0.4, 0):
	set(value):
		hint_offset = value
		if _hint:
			_hint.position = value

var _player_in_range := false
# ponytail: DialogueManager exposes no "is running" property, only start/end signals —
# track it locally. Fine even with multiple instances since only one dialogue runs at a time.
var _dialogue_running := false

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _hint: Label3D = $InteractHint

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	_shape.shape.radius = range_radius
	_hint.position = hint_offset
	if dialogue_resource:
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
		DialogueManager.dialogue_started.connect(func(_res): _dialogue_running = true)
		DialogueManager.dialogue_ended.connect(func(_res): _dialogue_running = false)
	else:
		monitoring = false
		_hint.hide()

func _process(_delta: float) -> void:
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

# True when the active camera is pointed roughly at this object — proximity
# (Area3D range) alone isn't enough to let the player interact.
func _is_player_facing() -> bool:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return true
	var to_self := global_position - cam.global_position
	if to_self.length() < 0.001:
		return true
	var forward := -cam.global_transform.basis.z
	return forward.normalized().dot(to_self.normalized()) >= cos(deg_to_rad(facing_angle_degrees))
