extends Node3D

# Body texture variants, keyed by the same short names the dialogue file
# passes to StoryFlags.set_visual_state("trash_angel", "body", <name>).
const BODY_TEXTURES := {
	"open_lid_eyes": preload("res://entities/trash_angel_wing_animation/sprites/body_open_lid_eyes.png"),
	"closed_lid_eyes": preload("res://entities/trash_angel_wing_animation/sprites/body_closed_lid_eyes.png"),
	"closed_lid_noeyes": preload("res://entities/trash_angel_wing_animation/sprites/body_closed_lid_noeyes.png"),
}
const DEFAULT_BODY_VARIANT := "open_lid_eyes"

# ponytail: shared per-frame sine bob, same idea as floating_photo.gd but
# applied to the whole rig's root instead of a single Sprite3D.
@export var bob_height := 0.15
@export var bob_speed := 0.6

var _base_y: float
var _time_offset: float

@onready var _body: Sprite3D = $Body

func _ready() -> void:
	_base_y = position.y
	_time_offset = randf() * TAU
	StoryFlags.visual_state_changed.connect(_on_visual_state_changed)
	var starting_variant: String = StoryFlags.get_visual_state("trash_angel", "body", DEFAULT_BODY_VARIANT)
	_apply_body_variant(starting_variant)

func _process(_delta: float) -> void:
	position.y = _base_y + sin(Time.get_ticks_msec() / 1000.0 * bob_speed + _time_offset) * bob_height

func _on_visual_state_changed(id: String, key: String, value) -> void:
	if id == "trash_angel" and key == "body":
		_apply_body_variant(value)

func _apply_body_variant(variant: String) -> void:
	if BODY_TEXTURES.has(variant):
		_body.texture = BODY_TEXTURES[variant]
