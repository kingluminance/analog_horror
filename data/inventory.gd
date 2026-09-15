extends Node
## Plain quantity-tracking inventory, same "session-memory only" spirit as
## StoryFlags -- game state itself doesn't autosave, only what SaveSystem
## explicitly writes out on a "세이브" action (see data/save_system.gd).
## Metadata (name/texture/description/max_count) is registered separately
## from ownership counts so any feature can register its own item without
## touching what other features registered.

var _counts: Dictionary = {}
var _metadata: Dictionary = {}

signal item_added(id: String, count: int)
signal item_removed(id: String, count: int)

#func _ready() -> void:
	# Temporary smoke-test seed so the inventory UI has something to show
	# before any real feature grants items via dialogue. Real features
	# should call register_item() themselves and grant items with
	# `using Inventory` + `$> Inventory.give_item("id")` from their own
	# .dialogue files (see ping_pong_bottle.dialogue for an example).


## max_count caps how many of this item can ever be held at once
## (-1 = unlimited, the default). "기록지"(record_paper) registers with
## max_count=1 via data/save_system.gd -- give_item() silently clamps
## instead of erroring, since narrative code shouldn't have to check
## first before handing one over.
func register_item(id: String, display_name: String, texture: Texture2D, description: String = "", max_count: int = -1) -> void:
	_metadata[id] = {"display_name": display_name, "texture": texture, "description": description, "max_count": max_count}

func give_item(id: String, count: int = 1) -> void:
	var max_count: int = _metadata.get(id, {}).get("max_count", -1)
	var new_count := get_count(id) + count
	if max_count >= 0:
		new_count = mini(new_count, max_count)
	var actual_delta := new_count - get_count(id)
	if actual_delta <= 0:
		return
	_counts[id] = new_count
	item_added.emit(id, actual_delta)

func remove_item(id: String, count: int = 1) -> bool:
	if get_count(id) < count:
		return false
	_counts[id] = get_count(id) - count
	if _counts[id] <= 0:
		_counts.erase(id)
	item_removed.emit(id, count)
	return true

func has_item(id: String, count: int = 1) -> bool:
	return get_count(id) >= count

func get_count(id: String) -> int:
	return _counts.get(id, 0)

func get_display_name(id: String) -> String:
	return _metadata.get(id, {}).get("display_name", id)

func get_owned_items() -> Array:
	var result: Array = []
	for id in _counts.keys():
		if _counts[id] <= 0:
			continue
		var meta: Dictionary = _metadata.get(id, {})
		result.append({
			"id": id,
			"display_name": meta.get("display_name", id),
			"texture": meta.get("texture", null),
			"description": meta.get("description", ""),
			"count": _counts[id],
		})
	return result

## Save/load support (data/save_system.gd) -- reaches in as a whole
## snapshot rather than replaying give_item/remove_item calls, so a load
## doesn't re-trigger item_added/item_removed toasts for everything.
func get_all_counts() -> Dictionary:
	return _counts.duplicate(true)

func set_all_counts(counts: Dictionary) -> void:
	_counts = counts.duplicate(true)
