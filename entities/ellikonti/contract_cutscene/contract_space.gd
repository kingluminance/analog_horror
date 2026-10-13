extends Node
## The place Ellikonti's contract cutscene drops you into
## (scenes/ellikonti_contract_space.tscn). For now it is only the arrival:
## the stars that burst at the end of the cutscene keep bursting here while
## the black lifts off the drifting background. Ellikonti talking to you in
## the middle of it (and where you go afterwards) is not built yet.

@onready var _black: ColorRect = $Overlay/Black
@onready var _stars: Array[CPUParticles2D] = [$Overlay/StarsPink, $Overlay/StarsGreen]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var size := get_viewport().get_visible_rect().size
	for s in _stars:
		s.position = Vector2(size.x * 0.5, size.y + 20.0)
		s.emission_rect_extents = Vector2(size.x * 0.45, 10.0)
		s.emitting = true
	var tween := create_tween()
	tween.tween_property(_black, "color:a", 0.0, 1.2).set_delay(0.3)
