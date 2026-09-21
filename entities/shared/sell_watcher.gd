class_name SellWatcher
extends Node
## Reusable "dialogue opens a sell list" trigger -- the sell-side mirror
## of entities/shared/shop_watcher.gd's exact "dialogue sets a flag / a
## sibling watcher acts on it" split (see that file's own docstring, and
## entities/log_cabin/cabin_door_watcher.gd, the pattern both are built
## on). A merchant's own .dialogue file sets this watcher's uniquely-named
## open_flag from a "판매합니다" (or similar) choice
## (`$> StoryFlags.set_flag(open_flag_value, true)`); this node notices
## the dialogue ending with that flag set and opens the shared sell-list
## UI (ui/shop/sell_list_ui.gd), found via its "sell_list_ui" group the
## same way ShopWatcher finds "shop_ui".
##
## Any merchant just drops sell_watcher.tscn in as a child, sets
## default_sell_price/default_sell_line/sell_overrides/open_flag in the
## Inspector, and has its own .dialogue set that flag -- no other code
## needed. Everything sellable comes straight from the player's own
## Inventory (see _build_rows) -- there's no per-merchant "what do they
## buy back" list to configure beyond the overrides.

## Price paid for anything in the player's Inventory that isn't listed in
## sell_overrides below.
@export var default_sell_price := 1
## Reaction line said for anything not listed in sell_overrides.
@export var default_sell_line := ""
## Whether this merchant buys ANYTHING it doesn't have an explicit
## sell_overrides entry for. true (default) = sells everything the player
## owns unless a specific override says otherwise. false = the opposite
## stance -- refuses everything by default, and only items explicitly
## listed in sell_overrides with sellable=true can be sold here (a
## curated whitelist instead of an exception list).
@export var default_sellable := true
## Hand-configured exceptions -- specific items at their own price/line.
## Anything the player owns that ISN'T in this list still sells fine, just
## at default_sell_price/default_sell_line.
@export var sell_overrides: Array[SellOverride] = []
## Merchant sets a unique flag name here, e.g. "bottari_wants_sell" -- see
## shop_watcher.gd's own open_flag for why this must not collide with any
## other flag in the game.
@export var open_flag: String = ""

func _ready() -> void:
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	if open_flag == "" or not StoryFlags.get_flag(open_flag):
		return
	StoryFlags.set_flag(open_flag, false)
	var sell_list := get_tree().get_first_node_in_group("sell_list_ui")
	if sell_list == null or not sell_list.has_method("open_list"):
		return
	if not sell_list.sell_requested.is_connected(_on_sell_requested):
		sell_list.sell_requested.connect(_on_sell_requested)
	sell_list.open_list(_build_rows()) # open_list() itself clears any leftover reaction -- nothing shows until the player actually tries to sell something

func _build_rows() -> Array[Dictionary]:
	var overrides_by_id := {}
	for o in sell_overrides:
		overrides_by_id[o.item_id] = o
	var rows: Array[Dictionary] = []
	for entry in Inventory.get_owned_items():
		if entry.id == Currency.ID:
			continue
		var sellable := default_sellable
		var price: int = default_sell_price
		if overrides_by_id.has(entry.id):
			var o: SellOverride = overrides_by_id[entry.id]
			sellable = o.sellable
			price = o.price
		rows.append({
			"id": entry.id,
			"display_name": entry.display_name,
			"count": entry.count,
			"price": price,
			"sellable": sellable,
		})
	return rows

## Resolves both the sale price AND the reaction line for one item id --
## an override's own line wins if set, otherwise default_sell_line is used
## for EITHER outcome (a successful sale or a refusal). Deliberately no
## separate hardcoded refusal string: the user wants one merchant-wide
## default line that reads naturally in both cases (e.g. a noncommittal
## "미안 이런건 괜찮아~" works as both "thanks, I'll pass" and "no thanks").
func _on_sell_requested(item_id: String) -> void:
	var sellable := default_sellable
	var price: int = default_sell_price
	var line: String = default_sell_line
	for o in sell_overrides:
		if o.item_id == item_id:
			sellable = o.sellable
			price = o.price
			line = o.line if o.line != "" else default_sell_line
			break

	var sell_list := get_tree().get_first_node_in_group("sell_list_ui")

	if not sellable:
		if sell_list:
			sell_list.show_reaction(line)
		return # merchant won't buy this one -- no Inventory/Currency change at all

	if not Inventory.remove_item(item_id, 1):
		return
	Inventory.give_item(Currency.ID, price)
	if sell_list:
		sell_list.open_list(_build_rows()) # refresh counts/removal FIRST --
		sell_list.show_reaction(line) # -- open_list() no longer clears this, but order still matters for clarity
