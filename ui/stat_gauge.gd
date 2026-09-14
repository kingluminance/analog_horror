extends Control
## One analog VU-meter-style dial for a single stat -- a swept arc +
## needle drawn with _draw() (no image assets, same spirit as this
## project's synthesized audio), instead of a plain progress bar. Fits
## the game's overall "old analog equipment" look better than an HP bar
## would.

@export var sweep_degrees := 270.0
@export var start_angle_degrees := 135.0  # Godot's draw_arc angles: 0=+x, clockwise

var value := 0.0
var max_value := 10.0
var _needle_angle := 0.0  # radians, animated
var _tween: Tween

@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel

func setup(display_name: String, v: float, max_v: float) -> void:
	_name_label.text = display_name
	max_value = max(max_v, 0.001)
	_needle_angle = deg_to_rad(start_angle_degrees)
	set_value(v, true)

func set_value(v: float, instant: bool = false) -> void:
	value = v
	_value_label.text = _format_value(v)
	var frac: float = clamp(v / max_value, 0.0, 1.0)
	var target_rad: float = deg_to_rad(start_angle_degrees + sweep_degrees * frac)
	if _tween and _tween.is_valid():
		_tween.kill()
	if instant:
		_needle_angle = target_rad
		queue_redraw()
	else:
		_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_set_needle_angle, _needle_angle, target_rad, 0.6)

func _set_needle_angle(rad: float) -> void:
	_needle_angle = rad
	queue_redraw()

func _draw() -> void:
	var dial_size: float = min(size.x, size.y - 26.0)
	var center := Vector2(size.x / 2.0, dial_size / 2.0 + 4.0)
	var radius := dial_size / 2.0 - 6.0

	var start_rad := deg_to_rad(start_angle_degrees)
	var end_rad := deg_to_rad(start_angle_degrees + sweep_degrees)
	draw_arc(center, radius, start_rad, end_rad, 40, Color(0.4, 0.32, 0.2, 0.55), 2.0, true)

	var frac: float = clamp(value / max_value, 0.0, 1.0)
	if frac > 0.0:
		draw_arc(center, radius, start_rad, start_rad + deg_to_rad(sweep_degrees) * frac, 40, Color(0.85, 0.62, 0.28, 0.95), 3.0, true)

	for i in range(6):
		var t := i / 5.0
		var ang := start_rad + deg_to_rad(sweep_degrees) * t
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(center + dir * (radius - 5.0), center + dir * (radius + 2.0), Color(0.65, 0.52, 0.3, 0.7), 1.5)

	var tip := center + Vector2(cos(_needle_angle), sin(_needle_angle)) * (radius - 5.0)
	draw_line(center, tip, Color(0.95, 0.8, 0.45, 1.0), 2.5)
	draw_circle(center, 3.5, Color(0.95, 0.8, 0.45, 1.0))

static func _format_value(v: float) -> String:
	if v == round(v):
		return str(int(v))
	return "%.1f" % v
