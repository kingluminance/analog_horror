extends Control
## "세이브/로드" binder page. Slot count is fully dynamic
## (SaveSystem.get_max_slots()) -- rebuilt every time this page becomes
## the front page so newly unlocked slots show up right away.
##
## Saving needs the binder itself to hide the whole panel for a frame so
## the screenshot is the game world, not this UI -- set via set_binder()
## by binder_ui.gd right after this page is instanced.

const SaveSlotCardScene := preload("res://ui/binder/save_slot_card.tscn")
const SaveSound := preload("res://audio/record_save.wav")

@onready var slots_row: Control = %SlotsRow
@onready var record_frame: Control = %RecordFrame
@onready var record_screenshot: TextureRect = %RecordScreenshot
@onready var record_text: RichTextLabel = %RecordText
@onready var sound_player: AudioStreamPlayer = %SoundPlayer
@onready var hint: Label = %Hint

var binder: Node
var _slot_cards: Array = []
var _busy := false

func set_binder(b: Node) -> void:
	binder = b

func refresh() -> void:
	for c in _slot_cards:
		c.queue_free()
	_slot_cards.clear()
	record_frame.hide()
	record_frame.modulate.a = 1.0
	record_frame.scale = Vector2.ONE

	var max_slots := SaveSystem.get_max_slots()
	for i in max_slots:
		var card: Control = SaveSlotCardScene.instantiate()
		slots_row.add_child(card)
		card.setup(i, SaveSystem.get_slot_info(i))
		card.set_can_save(SaveSystem.can_save() and not _busy)
		card.save_pressed.connect(_on_save_pressed.bind(i))
		card.load_pressed.connect(_on_load_pressed.bind(i))
		_slot_cards.append(card)
	_update_hint()

func _update_hint() -> void:
	if SaveSystem.can_save():
		hint.text = "기록지 보유 중 -- 슬롯을 선택하면 그 자리에 기록한다."
	else:
		hint.text = "기록지가 없어서 지금은 기록할 수 없다. (불러오기는 언제든 가능)"

func _on_save_pressed(slot: int) -> void:
	if _busy or not SaveSystem.can_save():
		return
	_busy = true
	var screenshot: Image = await binder.capture_world_screenshot()
	var note := SaveSystem.describe_current_scene()
	if SaveSystem.save_to_slot(slot, screenshot, note):
		await _play_record_animation(screenshot, note, slot)
	_busy = false
	refresh()

func _on_load_pressed(slot: int) -> void:
	if _busy:
		return
	_busy = true
	await SaveSystem.load_from_slot(slot)
	_busy = false
	if binder and binder.has_method("close_ui"):
		binder.close_ui()

func _play_record_animation(screenshot: Image, note: String, slot: int) -> void:
	record_frame.show()
	record_frame.modulate.a = 1.0
	record_frame.scale = Vector2.ONE
	if screenshot:
		record_screenshot.texture = ImageTexture.create_from_image(screenshot)
	record_screenshot.modulate.a = 0.0
	record_text.text = "%s\n%s" % [note, Time.get_datetime_string_from_system()]
	record_text.visible_ratio = 0.0
	sound_player.stream = SaveSound
	sound_player.play()

	var tw := create_tween()
	tw.tween_property(record_screenshot, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(record_text, "visible_ratio", 1.0, 0.6).set_delay(0.15)
	await tw.finished
	await get_tree().create_timer(0.5).timeout

	var target: Control = _slot_cards[slot] if slot < _slot_cards.size() else null
	var settle := create_tween()
	if target:
		settle.tween_property(record_frame, "global_position", target.global_position, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		settle.parallel().tween_property(record_frame, "scale", Vector2(0.15, 0.15), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	settle.parallel().tween_property(record_frame, "modulate:a", 0.0, 0.3).set_delay(0.15)
	await settle.finished
	record_frame.hide()
