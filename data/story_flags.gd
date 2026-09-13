extends Node

var flags: Dictionary = {}
var visit_counts: Dictionary = {}

# Generic "dialogue can drive an NPC's visual/body state" mechanism — a
# .dialogue file does `using StoryFlags` + `$> StoryFlags.set_visual_state(id, key, value)`
# at any branch point; the owning entity subscribes to `visual_state_changed`,
# filters by its own id, and reacts (e.g. swaps a texture). Not tied to any
# one character — any entity can use its own id/key namespace.
signal visual_state_changed(id: String, key: String, value)
var visual_states: Dictionary = {}

func get_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)

func set_flag(flag_name: String, value: bool) -> void:
	flags[flag_name] = value

func get_visit_count(id: String) -> int:
	return visit_counts.get(id, 0)

func increment_visit_count(id: String) -> void:
	visit_counts[id] = get_visit_count(id) + 1

func set_visual_state(id: String, key: String, value) -> void:
	if not visual_states.has(id):
		visual_states[id] = {}
	visual_states[id][key] = value
	visual_state_changed.emit(id, key, value)

func get_visual_state(id: String, key: String, default = null):
	return visual_states.get(id, {}).get(key, default)
