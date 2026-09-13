extends CanvasLayer

@onready var panel: Control = %Panel
@onready var volume_slider: HSlider = %VolumeSlider

var _dialogue_active := false
var _master_bus := AudioServer.get_bus_index("Master")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	panel.hide()
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(_master_bus))
	volume_slider.value_changed.connect(_on_volume_changed)
	DialogueManager.dialogue_started.connect(func(_r): _dialogue_active = true)
	DialogueManager.dialogue_ended.connect(func(_r): _dialogue_active = false)

func is_modal_open() -> bool:
	return panel.visible

func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_active:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if panel.visible:
			_resume()
		else:
			for node in get_tree().get_nodes_in_group("modal_ui"):
				if node != self and node.has_method("is_modal_open") and node.is_modal_open():
					return
			_pause()

func _pause() -> void:
	panel.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume() -> void:
	panel.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(_master_bus, linear_to_db(value))

func _on_resume_pressed() -> void:
	_resume()

func _on_quit_to_title_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
