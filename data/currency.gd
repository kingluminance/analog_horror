class_name Currency
## Plain currency descriptor -- deliberately NOT an autoload, and there is
## no separate balance store. Currency IS just an Inventory item (unlimited
## stack, id = ID below) registered once at boot; from then on the balance
## is simply Inventory.get_count(Currency.ID) -- no new getter needed here.
## Mirrors data/save_system.gd's "기록지"(record_paper) precedent exactly:
## an autoload's _ready() registers + grants a placeholder starting supply
## of an Inventory item, marked as temporary/TODO until real content grants
## it properly.

const ID := "너"
const DISPLAY_NAME := "너"

## Registers 너 as an unlimited-max_count Inventory item and grants a
## starting placeholder balance. Called once from SaveSystem._ready() (see
## the record_paper call right above it in data/save_system.gd) -- same
## "the gate is real, the real acquisition path is future content" state
## record_paper and the log cabin's 발광체 are already in. Move/remove this
## seed once a real source of 너 (a merchant's sell-back, an event reward,
## etc.) exists.
static func register_and_seed(starting_amount: int = 10) -> void:
	Inventory.register_item(ID, DISPLAY_NAME, null,
		"이 세계에서 통용되는, 정체를 알 수 없는 무언가.", -1)
	Inventory.give_item(ID, starting_amount)
