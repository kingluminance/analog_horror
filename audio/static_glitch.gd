extends AudioStreamPlayer
## VHS/radio-static interruption — plays at random, irregular intervals.

@export var min_interval := 12.0
@export var max_interval := 35.0

func _ready() -> void:
	_wait_and_play()

func _wait_and_play() -> void:
	await get_tree().create_timer(randf_range(min_interval, max_interval)).timeout
	volume_db = randf_range(-6.0, 2.0)
	play()
	_wait_and_play()
