extends PanelContainer
## One scattered Polaroid card in the inventory pile. Tilt/jitter is
## deterministic (hashed from the item id) so the pile looks the same
## every time it's opened, not different every session.

@onready var texture_rect: TextureRect = %TextureRect
@onready var caption: Label = %Caption

var item_id := ""

func setup(id: String, display_name: String, tex: Texture2D) -> void:
	item_id = id
	texture_rect.texture = tex
	caption.text = display_name
	var h := absi(hash(id))
	rotation_degrees = (h % 21) - 10
	var jitter := Vector2((h / 7 % 41) - 20, (h / 13 % 31) - 15)
	position += jitter

func set_focused(focused: bool) -> void:
	scale = Vector2(1.15, 1.15) if focused else Vector2.ONE
	z_index = 10 if focused else 0
