extends Control
## One save slot card in the "세이브/로드" page -- either an empty slot
## with just a 기록 (save) button, or an occupied slot showing its
## screenshot thumbnail + note/timestamp with both 기록(overwrite) and
## 불러오기 buttons.

signal save_pressed
signal load_pressed

@onready var thumbnail: TextureRect = %Thumbnail
@onready var empty_label: Label = %EmptyLabel
@onready var note_label: Label = %NoteLabel
@onready var timestamp_label: Label = %TimestampLabel
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton

func _ready() -> void:
	save_button.pressed.connect(func(): save_pressed.emit())
	load_button.pressed.connect(func(): load_pressed.emit())

func setup(slot: int, info: Dictionary) -> void:
	var occupied: bool = not info.is_empty()
	thumbnail.visible = occupied
	empty_label.visible = not occupied
	note_label.visible = occupied
	timestamp_label.visible = occupied
	load_button.disabled = not occupied

	if occupied:
		note_label.text = info.get("note", "")
		timestamp_label.text = info.get("timestamp", "")
		var shot_path: String = info.get("screenshot_path", "")
		if shot_path != "" and FileAccess.file_exists(shot_path):
			var img := Image.new()
			if img.load(shot_path) == OK:
				thumbnail.texture = ImageTexture.create_from_image(img)
	else:
		empty_label.text = "빈 슬롯 %d" % (slot + 1)

func set_can_save(can_save: bool) -> void:
	save_button.disabled = not can_save
