extends AudioStreamPlayer3D
## Plays the composite gramophone track (audio/gramophone_song.wav) near
## this object -- but only once the player turns it on via dialogue
## (StoryFlags flag "gramophone_playing"), not automatically. Loops
## indefinitely once started -- restarts on finish, the same trick
## audio/looping_player.gd uses for its 2D player, just for a 3D one
## here (avoids fiddling with per-import WAV loop settings).
##
## Also simulates a scratched record stuck repeating a short window
## mid-song: once playback crosses skip_loop_end_sec, playback keeps
## getting seeked back to skip_loop_start_sec, and the "gramophone_stuck"
## flag is set so gramophone.dialogue knows to offer the "고쳐볼게" choice
## only while it's actually stuck -- not permanently. Fixed by that
## choice setting "gramophone_loop_fixed" (which also clears "stuck").

@export var skip_loop_start_sec := 9.0
@export var skip_loop_end_sec := 9.6

var _started := false

func _ready() -> void:
	finished.connect(play)

func _process(_delta: float) -> void:
	if not _started:
		if StoryFlags.get_flag("gramophone_playing"):
			_started = true
			play()
		return
	if not playing:
		return
	if StoryFlags.get_flag("gramophone_loop_fixed"):
		if StoryFlags.get_flag("gramophone_stuck"):
			StoryFlags.set_flag("gramophone_stuck", false)
		return
	if get_playback_position() >= skip_loop_end_sec:
		seek(skip_loop_start_sec)
		StoryFlags.set_flag("gramophone_stuck", true)
