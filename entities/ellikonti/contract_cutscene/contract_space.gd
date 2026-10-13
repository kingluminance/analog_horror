extends Node
## The place Ellikonti's contract cutscene drops you into
## (scenes/ellikonti_contract_space.tscn). For now it is only the arrival:
## the stars burst up from below exactly once, here (not in the cutscene --
## the user wanted one burst, not two), with the "쨔라라라랑~" sting
## (StarBurstSfx, autoplay), while the black lifts off the drifting
## background. Then Ellikonti's explanation BGM fades in under it (Bgm:
## contract_space_bgm.wav -- a seamless 48 s "돌림노래" loop meant to sit
## under her talking: E minor 3/4, bassoon oom + pizzicato pah-pah, sparse
## music-box/celesta melody; source C:/Users/my/Documents/music/
## ellikonti_explain_loop.py/.mid/.pdf, a mix of the earlier LMMS march and
## MIDI waltz drafts).
## Ellikonti talking to you in the middle of it (and where you go afterwards)
## is not built yet.

const BGM_DELAY := 1.4  # let the "쨔라라라랑~" ring first
const BGM_FADE := 2.5
const BGM_VOLUME_DB := -6.0

@onready var _black: ColorRect = $Overlay/Black
@onready var _stars: Array[CPUParticles2D] = [$Overlay/StarsPink, $Overlay/StarsGreen]
@onready var _bgm: AudioStreamPlayer = $Bgm


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var size := get_viewport().get_visible_rect().size
	for s in _stars:
		s.position = Vector2(size.x * 0.5, size.y + 20.0)
		s.emission_rect_extents = Vector2(size.x * 0.45, 10.0)
		s.emitting = true
	var tween := create_tween()
	tween.tween_property(_black, "color:a", 0.0, 1.2).set_delay(0.3)
	var music := create_tween()
	music.tween_interval(BGM_DELAY)
	music.tween_callback(_bgm.play)
	music.tween_property(_bgm, "volume_db", BGM_VOLUME_DB, BGM_FADE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
