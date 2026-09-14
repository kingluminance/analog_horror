extends CanvasLayer
## Always-on corner readout of whatever stats are currently registered in
## Stats (data/stats.gd) -- no hardcoded stat names here, same spirit as
## Stats itself, so a new register_stat() call elsewhere just shows up.
## Rebuilds on Stats.stat_changed and once at startup.

@onready var label: Label = %Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Stats.stat_changed.connect(func(_id, _value): _rebuild())
	_rebuild()

func _rebuild() -> void:
	var lines: Array[String] = []
	for id in Stats.get_registered_stats():
		lines.append("%s %s" % [Stats.get_display_name(id), _format_value(Stats.get_stat(id))])
	label.text = "\n".join(lines)

static func _format_value(value: float) -> String:
	if value == round(value):
		return str(int(value))
	return "%.1f" % value
