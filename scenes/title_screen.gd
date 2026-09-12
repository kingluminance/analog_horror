extends Control

@onready var prompt: Label = %Prompt

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tween := create_tween().set_loops()
	tween.tween_property(prompt, "modulate:a", 0.15, 0.8)
	tween.tween_property(prompt, "modulate:a", 1.0, 0.8)

func _unhandled_input(event: InputEvent) -> void:
	# is_pressed()/is_echo() are base InputEvent methods — safe across key/mouse/joypad
	# without the "event as InputEventKey" type-narrowing GDScript can't infer through `:=`.
	if event.is_pressed() and not event.is_echo():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
