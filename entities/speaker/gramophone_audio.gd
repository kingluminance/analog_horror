extends AudioStreamPlayer3D
## Plays the composite gramophone track (audio/gramophone_song.wav) near
## this object, following the StoryFlags flag "gramophone_playing" every
## frame: starts when it's true, stops when it's false -- so the "그만
## 듣는다" choice in gramophone.dialogue can actually silence it, not
## just end the conversation. Loops indefinitely while playing --
## restarts on finish, the same trick audio/looping_player.gd uses for
## its 2D player, just for a 3D one here (avoids fiddling with
## per-import WAV loop settings).
##
## Also simulates a scratched record stuck repeating a short window
## mid-song: once playback crosses skip_loop_end_sec, playback keeps
## getting seeked back to skip_loop_start_sec, and the "gramophone_stuck"
## flag is set so gramophone.dialogue knows to offer the "고쳐볼게" choice
## only while it's actually stuck -- not permanently. Fixed by that
## choice setting "gramophone_loop_fixed" (which also clears "stuck").

@export var skip_loop_start_sec := 9.0
@export var skip_loop_end_sec := 9.6

func _ready() -> void:
	finished.connect(play)

func _process(_delta: float) -> void:
	if not StoryFlags.get_flag("gramophone_playing"):
		if playing:
			stop()
		return
	if not playing:
		play()
		return
	if StoryFlags.get_flag("gramophone_loop_fixed"):
		if StoryFlags.get_flag("gramophone_stuck"):
			StoryFlags.set_flag("gramophone_stuck", false)
		return
	if get_playback_position() >= skip_loop_end_sec:
		seek(skip_loop_start_sec)
		StoryFlags.set_flag("gramophone_stuck", true)
