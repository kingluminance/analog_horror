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

# Generic "has this NPC's dialogue exhausted its conversation topics" mechanism --
# a .dialogue file calls `$> StoryFlags.mark_choice_seen(id, choice_id)` inside
# whichever response branch, and checks `StoryFlags.has_seen_all_choices(id,
# [choice_id, ...])` (e.g. in the routing at `~ start`) to gate a follow-up
# dialogue phase once every listed choice has been picked at least once across
# any number of visits. `id`/`choice_id` are just caller-chosen strings, same
# namespacing convention as `flags`/`visit_counts` -- no per-character setup.
var seen_choices: Dictionary = {}

func mark_choice_seen(id: String, choice_id: String) -> void:
	if not seen_choices.has(id):
		seen_choices[id] = {}
	seen_choices[id][choice_id] = true

func has_seen_choice(id: String, choice_id: String) -> bool:
	return seen_choices.get(id, {}).get(choice_id, false)

func has_seen_all_choices(id: String, choice_ids: Array) -> bool:
	for choice_id in choice_ids:
		if not has_seen_choice(id, choice_id):
			return false
	return true
