extends Node
## Player stats for eventual RPG-ish mechanics -- events for now, maybe
## combat later, still undecided. Dictionary-based like StoryFlags/
## Inventory so new stats can be added later without ever touching this
## file: call register_stat() once from wherever a stat is first needed
## (see entities/player/player.gd for the starting set), then
## get_stat/set_stat/add_stat freely from anywhere, including
## `$> Stats.add_stat("aggression", 1)` in a .dialogue file.
##
## Two kinds of stat, chosen per-register_stat call via clamp_to_max:
## - "Resource" stats (HP, aggression, flexibility) have a real ceiling
##   AND floor -- clamp_to_max=true keeps the actual value pinned to
##   [0, max] on every write, so the gauge needle and the number never
##   disagree (hitting the visual max really does mean "full").
## - "Growth" stats (level) have no real ceiling -- clamp_to_max=false
##   lets the value climb past max_value forever; max_value there is
##   just the gauge's needle scale, so the needle pins at full once
##   you're past it while the number keeps climbing. That's accepted
##   as fine for a stat that's just "however far you've gotten".
##
## Session-only, same as StoryFlags/Inventory -- no save/load yet.

signal stat_changed(stat_id: String, value: float)
## Purely additive on top of stat_changed above -- same "value changed"
## moments, but also carries the old value so listeners (e.g. a
## stat-loss popup) can tell a decrease from an increase without
## tracking their own previous-value cache. Only emitted when the value
## actually changed. stat_changed's own behavior/signature is untouched;
## existing listeners (items_page.gd) don't need to know this exists.
signal stat_delta_changed(stat_id: String, old_value: float, new_value: float)

var _definitions: Dictionary = {}  # id -> {display_name, description, default, max, clamp}
var _values: Dictionary = {}       # id -> float

func register_stat(id: String, display_name: String, default: float = 0.0, max_value: float = 10.0, clamp_to_max: bool = true, description: String = "") -> void:
	_definitions[id] = {"display_name": display_name, "description": description, "default": default, "max": max_value, "clamp": clamp_to_max}
	if not _values.has(id):
		_values[id] = clampf(default, 0.0, max_value) if clamp_to_max else default

func get_stat(id: String) -> float:
	if _values.has(id):
		return _values[id]
	if _definitions.has(id):
		return _definitions[id].default
	return 0.0

func get_max(id: String) -> float:
	return _definitions[id].max if _definitions.has(id) else 10.0

## Raises/lowers the ceiling itself -- e.g. a "level up" dialogue choice
## bumping max HP. Only re-clamps the current value if this stat clamps
## to its max (a lower max on a resource stat can push the current
## value back down; raising it never auto-fills the value, that's a
## separate set_stat/add_stat call if that's what's wanted too).
func set_max(id: String, max_value: float) -> void:
	if not _definitions.has(id):
		return
	_definitions[id].max = max_value
	if _definitions[id].clamp:
		var old_value := get_stat(id)
		var clamped := clampf(old_value, 0.0, max_value)
		if clamped != old_value:
			_values[id] = clamped
			stat_changed.emit(id, clamped)
			stat_delta_changed.emit(id, old_value, clamped)

func add_max(id: String, delta: float) -> void:
	set_max(id, get_max(id) + delta)

func set_stat(id: String, value: float) -> void:
	if _definitions.has(id) and _definitions[id].clamp:
		value = clampf(value, 0.0, _definitions[id].max)
	var old_value := get_stat(id)
	_values[id] = value
	stat_changed.emit(id, value)
	if value != old_value:
		stat_delta_changed.emit(id, old_value, value)

func add_stat(id: String, delta: float) -> void:
	set_stat(id, get_stat(id) + delta)

func get_display_name(id: String) -> String:
	return _definitions[id].display_name if _definitions.has(id) else id

func get_registered_stats() -> Array:
	return _definitions.keys()
