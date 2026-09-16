extends "res://ui/inventory_polaroid.gd"
## Shop-item variant of the Polaroid card (ui/inventory_polaroid.gd/.tscn) --
## shop_item_card.tscn is a Godot "New Inherited Scene" of
## inventory_polaroid.tscn (not a from-scratch rebuild of the card layout),
## adding a price label and an affordability-dimmed state on top of the
## same Polaroid look/tilt/jitter and the same `clicked`/hover-description
## behavior. inventory_polaroid.gd declares no class_name, so this extends
## it by path instead of by class -- `super.setup()` below still reaches
## the base implementation the normal way.
##
## Deliberately does not override _ready() -- the base script's _ready()
## (wiring card.gui_input / card.mouse_entered) is inherited unchanged, and
## every @onready var here (including the base class's own `card`) resolves
## before _ready runs regardless of which script in the chain defines it.

@onready var price_label: Label = %PriceLabel

var affordable := true

## Called instead of setup() directly -- fills in the base Polaroid fields
## (item_id/display_name/texture/description) AND the price/afford state
## this subclass adds.
func setup_shop(item: ShopItem, can_afford: bool) -> void:
	setup(item.item_id, item.display_name, item.texture, item.description)
	price_label.text = "%d 너" % item.price
	set_affordable(can_afford)

## Public so ShopUI can re-dim every card after a purchase changes what's
## still affordable, without re-running the whole setup_shop() (tilt/jitter
## are id-hashed and would look identical anyway, so no need to redo them).
func set_affordable(value: bool) -> void:
	affordable = value
	modulate = Color(1, 1, 1, 1) if value else Color(0.55, 0.55, 0.55, 0.85)
	price_label.modulate = Color(0.15, 0.12, 0.08, 1) if value else Color(0.75, 0.25, 0.2, 1)

## Brief side-to-side shake on a failed purchase click -- a separate Tween
## on `card` (the base script's PanelContainer) so it never fights the base
## class's own _desc_tween (which only ever touches description_label).
func flash_unaffordable() -> void:
	var base_x: float = card.position.x
	var tw := create_tween()
	for i in 4:
		var dir := 1 if i % 2 == 0 else -1
		tw.tween_property(card, "position:x", base_x + dir * 6.0, 0.04)
	tw.tween_property(card, "position:x", base_x, 0.04)
