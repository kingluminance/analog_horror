extends Control
## "설정" binder page -- migrated from the old standalone ui/pause_menu.gd
## (the CanvasLayer + Esc-toggle logic now lives in binder_ui.gd for all
## 3 tabs, this page just holds the volume/quit controls).

@onready var volume_slider: HSlider = %VolumeSlider

var binder: Node
var _master_bus := AudioServer.get_bus_index("Master")

func set_binder(b: Node) -> void:
	binder = b

func _ready() -> void:
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(_master_bus))
	volume_slider.value_changed.connect(_on_volume_changed)

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(_master_bus, linear_to_db(value))

func _on_resume_pressed() -> void:
	if binder and binder.has_method("close_ui"):
		binder.close_ui()

func _on_quit_to_title_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
