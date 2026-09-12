extends Sprite3D

# ponytail: shared per-frame sine bob; if dozens of these end up on screen at once
# and the synced motion reads as artificial, give each instance its own noise curve instead.
@export var bob_height := 0.15
@export var bob_speed := 0.6

# Optional — leave unset for a silent floating photo with no interaction.
@export var dialogue_resource: DialogueResource
@export var dialogue_start_title := "start"

var _base_y: float
var _time_offset: float
var _player_in_range := false
# ponytail: DialogueManager exposes no "is running" property, only start/end signals —
# track it locally. Fine even with multiple instances since only one dialogue runs at a time.
var _dialogue_running := false

@onready var _range: Area3D = $InteractRange
@onready var _hint: Label3D = $InteractRange/InteractHint

func _ready() -> void:
	_base_y = position.y
	_time_offset = randf() * TAU
	if dialogue_resource:
		_range.body_entered.connect(_on_body_entered)
		_range.body_exited.connect(_on_body_exited)
		DialogueManager.dialogue_started.connect(func(_res): _dialogue_running = true)
		DialogueManager.dialogue_ended.connect(func(_res): _dialogue_running = false)
	else:
		_range.monitoring = false
		_hint.hide()

func _process(_delta: float) -> void:
	position.y = _base_y + sin(Time.get_ticks_msec() / 1000.0 * bob_speed + _time_offset) * bob_height
	
func _unhandled_input(event: InputEvent) -> void:
	if not dialogue_resource or not _player_in_range:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		if not _dialogue_running:
			DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_start_title)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_in_range = true
		_hint.show()

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_in_range = false
		_hint.hide()
