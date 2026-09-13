extends Node
## Plain quantity-tracking inventory, same "session-memory only" spirit as
## StoryFlags — no save/load yet. Metadata (name/texture/description) is
## registered separately from ownership counts so any feature can register
## its own item without touching what other features registered.

var _counts: Dictionary = {}
var _metadata: Dictionary = {}

signal item_added(id: String, count: int)
signal item_removed(id: String, count: int)

func _ready() -> void:
	# Temporary smoke-test seed so the inventory UI has something to show
	# before any real feature grants items via dialogue. Real features
	# should call register_item() themselves and grant items with
	# `using Inventory` + `$> Inventory.give_item("id")` from their own
	# .dialogue files (see ping_pong_bottle.dialogue for an example).
	register_item("test_polaroid", "정체불명의 폴라로이드", preload("res://entities/floating_photo/photos/ping_pong_bottle_180.png"), "언제 찍었는지 기억나지 않는 사진.")
	register_item("test_bottlecap", "떨어진 뚜껑", preload("res://entities/orbiting_paddle/paddle.png"), "주웠는데 왜 주웠는지 모르겠다.")
	give_item("test_bottlecap")

func register_item(id: String, display_name: String, texture: Texture2D, description: String = "") -> void:
	_metadata[id] = {"display_name": display_name, "texture": texture, "description": description}

func give_item(id: String, count: int = 1) -> void:
	_counts[id] = get_count(id) + count
	item_added.emit(id, count)

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
