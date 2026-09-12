extends Node

var flags: Dictionary = {}
var visit_counts: Dictionary = {}

func get_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)

func set_flag(flag_name: String, value: bool) -> void:
	flags[flag_name] = value

func get_visit_count(id: String) -> int:
	return visit_counts.get(id, 0)

func increment_visit_count(id: String) -> void:
	visit_counts[id] = get_visit_count(id) + 1
