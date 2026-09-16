extends Node
## Backing store for the binder UI's "세이브/로드" tab. A save consumes
## one "기록지"(record_paper) item -- capped at 1 in the inventory at a
## time via Inventory.register_item's max_count -- load is free/unlimited.
##
## Each slot is two files under user://saves/ (real disk persistence,
## unlike StoryFlags/Inventory/Stats which are session-memory only until
## a save actually writes them out):
##   slot_<n>.json  -- flags/visit counts/visual states/inventory/stats/
##                     scene path/player transform/note/timestamp
##   slot_<n>.png   -- the screenshot taken at save time
##
## Slot count is dynamic, not hardcoded to the starting count -- see
## get_max_slots(). Starts at 1; meant to grow via story flags as content
## like "기록된 날개와의 계약" gets built (add more flag checks there,
## no UI changes needed since the save/load page just asks this).

const SAVE_DIR := "user://saves/"
const RECORD_PAPER_ID := "record_paper"

signal saved(slot: int)
signal loaded(slot: int)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	Inventory.register_item(RECORD_PAPER_ID, "기록지",
		null,
		"이곳에서 있었던 일을 종이 한 장에 기록해 둘 수 있다. 한 번에 한 장만 지닐 수 있다.",
		1)
	# Placeholder starting supply so the save mechanic is actually usable
	# before any narrative source of 기록지 exists (nothing grants it
	# yet -- same "gate is real, source is future content" situation the
	# log cabin's 발광체 item is in). Move/remove once a real pickup or
	# dialogue reward exists.
	Inventory.give_item(RECORD_PAPER_ID, 1)

	# 너(Currency) -- same "gate is real, real acquisition path is future
	# content" placeholder situation as the 기록지 grant right above.
	# See Currency.register_and_seed() in data/currency.gd.
	Currency.register_and_seed()

## 1 to start; +2 once the first stage of "기록된 날개와의 계약" is done,
## +1 more on the second stage -- 1 -> 3 -> 4, matching the "3~4개까지
## 동적으로 확장" request. Neither flag is set by any content yet; wire
## them up from wherever that event ends up living.
func get_max_slots() -> int:
	var slots := 1
	if StoryFlags.get_flag("wings_contract_stage1"):
		slots = 3
	if StoryFlags.get_flag("wings_contract_stage2"):
		slots = 4
	return slots

func can_save() -> bool:
	return Inventory.has_item(RECORD_PAPER_ID)

func slot_path(slot: int, ext: String) -> String:
	return "%sslot_%d.%s" % [SAVE_DIR, slot, ext]

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot, "json"))

## Cheap metadata read for the slot list -- note/timestamp/scene/whether
## a screenshot exists -- without touching any live game state.
func get_slot_info(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(slot_path(slot, "json"), FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return {
		"note": data.get("note", ""),
		"timestamp": data.get("timestamp", ""),
		"scene": data.get("scene", ""),
		"screenshot_path": slot_path(slot, "png") if FileAccess.file_exists(slot_path(slot, "png")) else "",
	}

## A short Korean label for whatever scene the player is standing in
## right now, for the record card's text. Falls back to the scene's file
## name for anything not in this list, so a new scene never breaks it.
func describe_current_scene() -> String:
	var path := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	match path:
		"res://scenes/main.tscn":
			return "밝은 들판에서"
		"res://scenes/log_cabin_interior.tscn":
			return "어두운 오두막 안에서"
		_:
			return path.get_file().get_basename()

## Consumes one 기록지 and writes the slot. `screenshot` may be null (the
## record card animation just won't have a picture in it). Returns false
## without writing anything if there's no 기록지 to spend.
func save_to_slot(slot: int, screenshot: Image, note: String) -> bool:
	if not can_save():
		return false
	if not Inventory.remove_item(RECORD_PAPER_ID):
		return false

	var player := _find_player()
	var data := {
		"note": note,
		"timestamp": Time.get_datetime_string_from_system(),
		"scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "",
		"player_transform": _transform_to_array(player.global_transform) if player else [],
		"flags": StoryFlags.flags,
		"visit_counts": StoryFlags.visit_counts,
		"visual_states": StoryFlags.visual_states,
		"inventory_counts": Inventory.get_all_counts(),
		"stats": _dump_stats(),
	}
	var f := FileAccess.open(slot_path(slot, "json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	if screenshot:
		screenshot.save_png(slot_path(slot, "png"))
	saved.emit(slot)
	return true

## Restores flags/inventory/stats immediately, then the scene + player
## position (which may require an actual scene swap first).
func load_from_slot(slot: int) -> bool:
	if not has_save(slot):
		return false
	var f := FileAccess.open(slot_path(slot, "json"), FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return false

	StoryFlags.flags = data.get("flags", {})
	StoryFlags.visit_counts = data.get("visit_counts", {})
	StoryFlags.visual_states = data.get("visual_states", {})
	Inventory.set_all_counts(data.get("inventory_counts", {}))
	_restore_stats(data.get("stats", {}))

	var scene_path: String = data.get("scene", "")
	var xform_array: Array = data.get("player_transform", [])
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		loaded.emit(slot)
		return false

	if get_tree().current_scene and get_tree().current_scene.scene_file_path == scene_path:
		_apply_player_transform(xform_array)
	else:
		get_tree().change_scene_to_file(scene_path)
		# The new scene isn't actually in the tree yet this frame --
		# same reason cabin_door_watcher.gd waits for dialogue_ended
		# before switching scenes rather than doing it inline.
		await get_tree().process_frame
		await get_tree().process_frame
		_apply_player_transform(xform_array)
	loaded.emit(slot)
	return true

func _find_player() -> Node3D:
	var cam := get_viewport().get_camera_3d()
	return cam.get_parent() if cam else null

func _apply_player_transform(xform_array: Array) -> void:
	if xform_array.is_empty():
		return
	var player := _find_player()
	if player:
		player.global_transform = _array_to_transform(xform_array)

func _transform_to_array(t: Transform3D) -> Array:
	return [t.origin.x, t.origin.y, t.origin.z, t.basis.get_euler().y]

func _array_to_transform(arr: Array) -> Transform3D:
	if arr.size() < 4:
		return Transform3D.IDENTITY
	var t := Transform3D.IDENTITY.rotated(Vector3.UP, arr[3])
	t.origin = Vector3(arr[0], arr[1], arr[2])
	return t

func _dump_stats() -> Dictionary:
	var result := {}
	for id in Stats.get_registered_stats():
		result[id] = {"value": Stats.get_stat(id), "max": Stats.get_max(id)}
	return result

func _restore_stats(data: Dictionary) -> void:
	for id in data.keys():
		if Stats.get_registered_stats().has(id):
			Stats.set_max(id, data[id].get("max", Stats.get_max(id)))
			Stats.set_stat(id, data[id].get("value", Stats.get_stat(id)))
