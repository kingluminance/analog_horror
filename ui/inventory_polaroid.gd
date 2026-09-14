extends Control
## One scattered Polaroid card in the inventory pile. Tilt/jitter is
## deterministic (hashed from the item id) so the pile looks the same
## every time it's opened, not different every session. Root is a plain
## Control (not the visual panel itself) so the description popup can sit
## beside the card without inheriting its random tilt.

signal clicked

@onready var card: PanelContainer = %Card
@onready var texture_rect: TextureRect = %TextureRect
@onready var caption: Label = %Caption
@onready var description_label: Label = %DescriptionLabel

var item_id := ""
var _description := ""
var _desc_tween: Tween

func _ready() -> void:
	card.gui_input.connect(_on_card_gui_input)
	card.mouse_entered.connect(show_description)

func setup(id: String, display_name: String, tex: Texture2D, description: String = "") -> void:
	item_id = id
	_description = description
	texture_rect.texture = tex
	caption.text = display_name
	var h := absi(hash(id))
	card.rotation_degrees = (h % 21) - 10
	var jitter := Vector2((h / 7 % 41) - 20, (h / 13 % 31) - 15)
	position += jitter

func set_focused(focused: bool) -> void:
	scale = Vector2(1.15, 1.15) if focused else Vector2.ONE
	z_index = 10 if focused else 0

func _on_card_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit()  # parent's focus-change handler shows the description

## Public so the parent can flash it on arrow-key focus changes too, not
## just on click/hover.
func show_description() -> void:
	if _description.is_empty():
		return
	description_label.text = _description
	if _desc_tween and _desc_tween.is_valid():
		_desc_tween.kill()
	description_label.modulate.a = 0.0
	_desc_tween = create_tween()
	_desc_tween.tween_property(description_label, "modulate:a", 1.0, 0.15)
	_desc_tween.tween_interval(1.8)
	_desc_tween.tween_property(description_label, "modulate:a", 0.0, 0.4)
