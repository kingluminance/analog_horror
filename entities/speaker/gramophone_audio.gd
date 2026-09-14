extends AudioStreamPlayer3D
## Plays the composite gramophone track (audio/gramophone_song.wav) near
## this object, looping indefinitely -- restarts on finish, the same
## trick audio/looping_player.gd uses for its 2D player, just for a 3D
## one here (avoids fiddling with per-import WAV loop settings).
##
## Also simulates a scratched record stuck repeating a short window
## mid-song: until StoryFlags.get_flag("gramophone_loop_fixed") is set
## (see the "고쳐볼게" choice in gramophone.dialogue), playback keeps
## getting seeked back to skip_loop_start_sec every time it crosses
## skip_loop_end_sec.

@export var skip_loop_start_sec := 9.0
@export var skip_loop_end_sec := 9.6

func _ready() -> void:
	finished.connect(play)
	play()

func _process(_delta: float) -> void:
	if not playing or StoryFlags.get_flag("gramophone_loop_fixed"):
		return
	if get_playback_position() >= skip_loop_end_sec:
		seek(skip_loop_start_sec)
