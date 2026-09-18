class_name SellOverride
extends Resource
## One hand-configured exception to a merchant's default sell price/line
## -- see entities/shared/sell_watcher.gd's sell_overrides export. Any
## Inventory item not listed here still sells fine, just at
## default_sell_price with default_sell_line as the merchant's reaction.

@export var item_id: String = ""
@export var price: int = 0
## Leave blank to just use the merchant's default_sell_line instead of a
## per-item reaction.
@export var line: String = ""
## Set false to make this specific item something the merchant flatly
## won't buy -- it still shows up in the sell list (marked "판매 불가"
## instead of a price) so the player can see why, and clicking it plays
## `line` as a refusal instead of completing a sale. `price` is ignored
## when this is false.
@export var sellable: bool = true
