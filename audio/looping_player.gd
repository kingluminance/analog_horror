extends AudioStreamPlayer
## Restarts on finish — avoids fiddling with per-import WAV loop settings.

func _ready() -> void:
	finished.connect(play)
