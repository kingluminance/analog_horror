extends Node
## Player stats for eventual RPG-ish mechanics -- events for now, maybe
## combat later, still undecided. Dictionary-based like StoryFlags/
## Inventory so new stats can be added later without ever touching this
## file: call register_stat() once from wherever a stat is first needed
## (see entities/player/player.gd for the starting set), then
## get_stat/set_stat/add_stat freely from anywhere, including
## `$> Stats.add_stat("aggression", 1)` in a .dialogue file.
##
## Session-only, same as StoryFlags/Inventory -- no save/load yet.

signal stat_changed(stat_id: String, value: float)

var _definitions: Dictionary = {}  # id -> {display_name, description, default}
var _values: Dictionary = {}       # id -> float

func register_stat(id: String, display_name: String, default: float = 0.0, description: String = "") -> void:
	_definitions[id] = {"display_name": display_name, "description": description, "default": default}
	if not _values.has(id):
		_values[id] = default

func get_stat(id: String) -> float:
	if _values.has(id):
		return _values[id]
	if _definitions.has(id):
		return _definitions[id].default
	return 0.0

func set_stat(id: String, value: float) -> void:
	_values[id] = value
	stat_changed.emit(id, value)

func add_stat(id: String, delta: float) -> void:
	set_stat(id, get_stat(id) + delta)

func get_display_name(id: String) -> String:
	return _definitions[id].display_name if _definitions.has(id) else id

func get_registered_stats() -> Array:
	return _definitions.keys()
