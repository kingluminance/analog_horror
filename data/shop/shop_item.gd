class_name ShopItem
extends Resource
## Data-only description of one thing a merchant sells. Construct these as
## .tres resources (Inspector-editable, reusable/shareable across NPCs) or
## build them inline in a merchant's own script (`ShopItem.new()` with the
## fields set) -- either works, ShopWatcher/ShopUI only ever touch the
## exported fields below and don't care how the resource was made.
##
## Not itself an Inventory registration -- ShopUI's purchase handler
## registers item_id with Inventory the first time it's actually bought
## (idempotent, see ShopUI._attempt_purchase), so a ShopItem alone doesn't
## have to duplicate metadata Inventory will also want, and an item never
## sold yet doesn't pollute the inventory's registry.

@export var item_id: String = ""
@export var display_name: String = ""
@export var texture: Texture2D
@export var description: String = ""
@export var price: int = 0
