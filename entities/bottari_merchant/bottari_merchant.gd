extends Node3D
## Root of "보따리로 판매합니다" (Bottari Merchant) -- a padlock-with-lips
## face floating above the ground, with two independent eyeball-keyring
## sprites drifting lazily nearby.
##
## Three separate ways to interact with this NPC:
## 1. Walk within entrance_trigger_radius -- auto-opens the greeting
##    dialogue (bottari_merchant.dialogue) and snaps the camera to the
##    merchant's face, cutscene-style. Uses two radii with hysteresis
##    (trigger vs. entrance_reset_radius), not a single Area3D
##    body_entered/exited pair -- wandering near one fixed boundary inside
##    a cramped tent re-crossed it constantly and re-fired the greeting
##    over and over. Only re-arms once the player has gone all the way
##    out past the larger reset radius.
## 2. Press E directly on the merchant (its own Interactable) -- plays
##    bottari_merchant_chat.dialogue, ordinary small talk, no camera
##    snap.
## 3. Press E on one of the CounterItems -- opens that item's own
##    *_confirm.dialogue ("사시겠소?"); choosing yes runs the delivery
##    cutscene (see _run_delivery below).
## 4. bottari_merchant_chat.dialogue's "아이템을 판매한다" choice opens a
##    reusable sell list (entities/shared/sell_watcher.gd, dropped in as a
##    child in bottari_merchant.tscn -- config lives there, not in this
##    script, so any future merchant can reuse the exact same component).
##
## Face bob reuses floating_photo.gd's exact sine-bob idiom (same formula,
## same per-instance randf() phase offset so it doesn't sync with other
## bobbing NPCs) -- just applied to the Face child Sprite3D's position
## instead of the script's own node, since this entity's root is a plain
## Node3D (so Interactable/EntranceTrigger can sit as still siblings, same
## reasoning ellikonti.gd documents for why Interactable never wants to be
## nested under something that moves every frame).
##
## Companions (CompanionA/CompanionB) do NOT use recorded_wings.gd's
## root-only look_at() trick -- that trick only earns its complexity when
## several sprites are hand-posed at fixed relative angles to each other
## and need to turn as one rigid unit (see recorded_wings.gd's docstring).
## These two have no fixed relative pose at all, they just wander near the
## face independently -- so each is simply billboard = 1 on its own (set in
## bottari_merchant.tscn) and this script never touches their rotation.
## Each companion gets its own randomized phase/speed per axis in _ready()
## (same "randf() per instance so synced motion doesn't read as artificial"
## spirit as floating_photo.gd's _time_offset) so CompanionA and CompanionB
## read as two independent drifters, not mirrored twins.

@export var bob_height := 0.15
@export var bob_speed := 0.6

## Roughly how far (meters) each companion wanders from its own resting
## spot -- a slow lazy wander, not a fast tilted orbit like
## orbiting_paddle.gd.
@export var companion_drift_radius := 0.35
@export var companion_drift_speed_min := 0.15 # rad/s
@export var companion_drift_speed_max := 0.35 # rad/s

class CompanionDrift:
	var sprite: Sprite3D
	var base_position: Vector3
	var phase: Vector3
	var speed: Vector3

var _base_face_y: float
var _face_time_offset: float
var _companions: Array[CompanionDrift] = []
# Sprite3D -> bool. A companion running the delivery cutscene (see below)
# is skipped by the idle-drift math in _process() until it is done, same
# reasoning as everywhere else in this project that a moving/tweened node
# must not also be driven by a second, competing per-frame formula.
var _companion_busy: Dictionary = {}
# Tracked purely so the entrance check doesn't stack a second dialogue on
# top of one already running (e.g. the player wandering close while mid
# purchase-confirm) -- DialogueManager exposes no "is running" getter,
# only start/end signals, same workaround interactable.gd already uses.
var _dialogue_active := false

## Distance (meters) that triggers the auto-greeting.
@export var entrance_trigger_radius := 4.5
## Must be bigger than entrance_trigger_radius. The player has to cross
## back out past THIS distance before the greeting can fire again --
## the gap between the two radii is the hysteresis band that stops
## boundary-jitter from re-triggering it while just moving around inside.
@export var entrance_reset_radius := 7.0
var _has_greeted_this_visit := false

@onready var _face: Sprite3D = $Face
var _greeting_dialogue: DialogueResource = preload("res://entities/bottari_merchant/bottari_merchant.dialogue")

# Which counter Interactable maps to which ShopItem resource, and which
# StoryFlags flag its confirm dialogue's "예" choice sets. Bespoke to this
# one merchant (not the reusable ShopWatcher/ShopUI path another merchant
# will use later) -- see bottari_merchant.tscn's CounterItems group and
# entities/bottari_merchant/dialogue/*_confirm.dialogue.
const PURCHASE_FLAGS := {
	"bottari_buy_loose_key": "res://entities/bottari_merchant/shop_items/loose_key.tres",
	"bottari_buy_eye_charm": "res://entities/bottari_merchant/shop_items/eye_charm.tres",
	"bottari_buy_locked_padlock": "res://entities/bottari_merchant/shop_items/locked_padlock.tres",
}

func _ready() -> void:
	_base_face_y = _face.position.y
	_face_time_offset = randf() * TAU
	for node in [$CompanionA, $CompanionB]:
		var c := CompanionDrift.new()
		c.sprite = node
		c.base_position = node.position
		c.phase = Vector3(randf(), randf(), randf()) * TAU
		c.speed = Vector3(
			randf_range(companion_drift_speed_min, companion_drift_speed_max),
			randf_range(companion_drift_speed_min, companion_drift_speed_max),
			randf_range(companion_drift_speed_min, companion_drift_speed_max)
		)
		_companions.append(c)
		_companion_busy[node] = false
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_face.position.y = _base_face_y + sin(t * bob_speed + _face_time_offset) * bob_height
	for c in _companions:
		if _companion_busy.get(c.sprite, false):
			continue
		c.sprite.position = c.base_position + Vector3(
			sin(t * c.speed.x + c.phase.x) * companion_drift_radius,
			sin(t * c.speed.y + c.phase.y) * companion_drift_radius * 0.7,
			sin(t * c.speed.z + c.phase.z) * companion_drift_radius * 0.5
		)
	_check_entrance_trigger()

func _get_player() -> Node:
	var cam := get_viewport().get_camera_3d()
	return cam.get_parent() if cam else null

## Checked every frame instead of an Area3D signal -- see the hysteresis
## note on entrance_trigger_radius/entrance_reset_radius above for why.
func _check_entrance_trigger() -> void:
	var player := _get_player()
	if player == null:
		return
	var dist := global_position.distance_to(player.global_position)
	if not _has_greeted_this_visit and dist <= entrance_trigger_radius:
		if _dialogue_active:
			return
		_has_greeted_this_visit = true
		DialogueManager.show_dialogue_balloon(_greeting_dialogue, "start")
	elif _has_greeted_this_visit and dist > entrance_reset_radius:
		_has_greeted_this_visit = false

## Snaps the camera toward the merchant's face the instant its own greeting
## dialogue (not just any dialogue anywhere in the game) opens -- filtered
## by resource identity since DialogueManager.dialogue_started is global.
## Also the one place _dialogue_active is tracked, for
## _on_entrance_trigger_body_entered's guard above.
func _on_dialogue_started(resource: DialogueResource) -> void:
	_dialogue_active = true
	if resource != _greeting_dialogue:
		return
	var player := _get_player()
	if player and player.has_method("force_look_at"):
		player.force_look_at(_face.global_position)

## Mirrors ShopWatcher's own "dialogue sets a flag, a sibling node acts on
## it" split (see entities/shared/shop_watcher.gd) -- except here the flag
## comes from one of this merchant's own *_confirm.dialogue files
## (entities/bottari_merchant/dialogue/), and "acts on it" means running
## the delivery cutscene below instead of opening a UI.
func _on_dialogue_ended(_resource: DialogueResource) -> void:
	_dialogue_active = false
	for flag_name in PURCHASE_FLAGS:
		if StoryFlags.get_flag(flag_name):
			StoryFlags.set_flag(flag_name, false)
			var item := load(PURCHASE_FLAGS[flag_name]) as ShopItem
			if item:
				_start_delivery(item)
			return

func _start_delivery(item: ShopItem) -> void:
	if not Inventory.has_item(Currency.ID, item.price):
		return # cannot afford -- silently no-op for now, no dedicated feedback yet
	var item_node := $CounterItems.find_child(item.item_id, false, false) as Node3D
	if item_node == null:
		return
	var companion := _pick_nearest_companion(item_node.global_position)
	if companion == null:
		return # both companions already busy delivering something else
	Inventory.remove_item(Currency.ID, item.price)
	_run_delivery(companion, item_node, item)

func _pick_nearest_companion(target_position: Vector3) -> Sprite3D:
	var best: Sprite3D = null
	var best_dist := INF
	for node in [$CompanionA, $CompanionB]:
		if _companion_busy.get(node, false):
			continue
		var d: float = node.global_position.distance_to(target_position)
		if d < best_dist:
			best_dist = d
			best = node
	return best

## The camera-tracked delivery mini-cutscene: nearest companion flies to
## the picked item, "carries" it (reparented so it visually rides along)
## to the player, hands it over (real Inventory.give_item -- the usual
## item_added toast fires on its own, nothing extra needed here), then
## returns to its resting spot and resumes normal idle drift. Player input
## is fully locked for the whole thing via player.set_cutscene_lock() --
## see entities/player/player.gd for why this needs a separate flag from
## _dialogue_active.
func _run_delivery(companion: Sprite3D, item_node: Node3D, item: ShopItem) -> void:
	_companion_busy[companion] = true
	var base_local_position := companion.position
	var player := _get_player()
	if player and player.has_method("set_cutscene_lock"):
		player.set_cutscene_lock(true)

	await _tween_companion_tracked(companion, item_node.global_position, 1.0, player)

	var carry_parent := item_node.get_parent()
	carry_parent.remove_child(item_node)
	companion.add_child(item_node)
	item_node.position = Vector3(0, -0.1, 0)

	if player:
		await _tween_companion_tracked(companion, player.global_position + Vector3(0, 1.2, 0), 1.4, player)

	Inventory.give_item(item.item_id)
	item_node.queue_free()

	await _tween_companion_tracked(companion, companion.get_parent().to_global(base_local_position), 1.2, player)
	companion.position = base_local_position # snap exactly, clears any tween float drift

	if player and player.has_method("set_cutscene_lock"):
		player.set_cutscene_lock(false)
	_companion_busy[companion] = false

## Runs a global_position tween on `node` while continuously re-aiming the
## player's forced camera look at wherever `node` currently is -- the
## "player tracks it like a cutscene" effect the delivery sequence wants,
## reusing player.gd's force_look_at() every frame instead of building a
## second camera system.
func _tween_companion_tracked(node: Node3D, target: Vector3, duration: float, player: Node) -> void:
	var t := create_tween()
	t.tween_property(node, "global_position", target, duration)
	while t.is_running():
		if player and player.has_method("force_look_at"):
			player.force_look_at(node.global_position)
		await get_tree().process_frame
