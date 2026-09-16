class_name ShopWatcher
extends Node
## Reusable "dialogue opens a shop" trigger -- generalizes the exact
## dialogue-sets-a-flag / a-separate-watcher-acts-on-it split
## entities/log_cabin/cabin_door_watcher.gd already uses for the cabin's
## door (see that file + entities/log_cabin/cabin_door.dialogue). A
## `.dialogue` file's `$>` mutations can only call methods on autoloads/
## game-state objects -- never reach a UI node or get_tree() directly --
## so a merchant's dialogue just sets its own uniquely-named flag on
## whichever choice should open the shop
## (`$> StoryFlags.set_flag(open_flag_value, true)`), and this node --
## dropped in as a plain child of the merchant, the same instancing
## convention entities/shared/interactable.tscn already established --
## notices the dialogue ending with that flag set and actually opens the
## shop UI.
##
## Any merchant just drops shop_watcher.tscn in as a child, sets
## shop_items/shop_title/open_flag in the Inspector, and has its own
## .dialogue set that flag -- no other code needed. Locates the live
## ShopUI instance via the "shop_ui" group (ui/shop/shop_ui.tscn's root
## adds itself to that group) rather than a direct node reference, since
## this component and the ShopUI instance are never guaranteed to be in
## the same branch of the scene tree.

@export var shop_items: Array[ShopItem] = []
@export var shop_title: String = ""
## Merchant sets a unique flag name here, e.g. "shop_wants_open_bottari" --
## StoryFlags is one flat namespace, so this must not collide with any
## other flag in the game.
@export var open_flag: String = ""

func _ready() -> void:
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	if open_flag == "" or not StoryFlags.get_flag(open_flag):
		return
	StoryFlags.set_flag(open_flag, false)
	var shop_ui := get_tree().get_first_node_in_group("shop_ui")
	if shop_ui and shop_ui.has_method("open_shop"):
		shop_ui.open_shop(shop_items, shop_title)
