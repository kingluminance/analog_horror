extends "res://ui/stat_gauge.gd"
## Stat-loss variant of the analog gauge (ui/stat_gauge.gd/.tscn) -- reuses
## the same hand-drawn dial (_draw() lives entirely in the base class and
## is untouched here) but replaces the base's smooth TRANS_ELASTIC sweep
## with a discrete stepped-DOWN animation for showing a stat LOSS: the
## needle jumps through one whole-point step at a time instead of
## gliding, for the mechanical "딸깍딸깍" feel ui/stat_loss_toast.gd wants.
##
## stat_gauge.gd declares no class_name, so this extends it by path --
## same pattern ui/shop/shop_item_card.gd already uses off
## ui/inventory_polaroid.gd. stat_loss_gauge.tscn is a Godot "New
## Inherited Scene" of stat_gauge.tscn the same way shop_item_card.tscn is
## an inherited scene of inventory_polaroid.tscn: just a script override
## on the instanced root, which is safe without [editable path=...]
## (that marker is only needed for overrides on a NESTED child of an
## instanced scene -- see CLAUDE.md's "인스턴스된 씬의 중첩 자식 노드"
## pitfall; a root-level script override, like AnalogDialogueLabel there,
## survives editor re-saves fine).

signal stepped(step_value: float)  ## fires once per discrete jump, with the value the needle just landed on -- stat_loss_toast.gd uses this to fire a tick sound per jump
signal stepping_finished  ## fires once the needle has landed exactly on to_value

@export var step_interval := 0.12  ## seconds between jumps

var _step_tween: Tween

## How many discrete jumps a loss from from_value down to to_value should
## take: one jump per whole point lost, minimum 1 for any nonzero loss,
## fractional remainders round up (a -2.5 loss still gets 3 jumps, not
## 2.5 or 2). Static and shared with ui/stat_loss_toast.gd so the popup
## can schedule its hold/fade-out around the same jump count without
## re-deriving it separately and risking the two disagreeing.
static func compute_jump_count(from_value: float, to_value: float) -> int:
	var loss := from_value - to_value
	if loss <= 0.0:
		return 0
	# small epsilon so float noise (e.g. a "4.0" that actually landed at
	# 3.999999997 after a few add_stat() calls) doesn't round up to an
	# extra, unearned jump
	return max(1, int(ceil(loss - 0.0001)))

## Moves the needle from from_value down to to_value in
## compute_jump_count() discrete jumps instead of the base class's smooth
## elastic tween: snaps to from_value first (no tween), then jumps down
## step_interval apart, emitting `stepped` after every jump and
## `stepping_finished` once it lands exactly on to_value.
func animate_stepped(from_value: float, to_value: float, max_v: float) -> void:
	max_value = max(max_v, 0.001)
	set_value(from_value, true)  # snap to the starting value, no smooth tween

	var num_jumps := compute_jump_count(from_value, to_value)
	if num_jumps <= 0:
		stepping_finished.emit()
		return
	var step_size: float = (from_value - to_value) / num_jumps

	if _step_tween and _step_tween.is_valid():
		_step_tween.kill()
	_step_tween = create_tween()
	for i in range(num_jumps):
		_step_tween.tween_interval(step_interval)
		var is_last := i == num_jumps - 1
		var step_value: float = to_value if is_last else from_value - step_size * (i + 1)
		_step_tween.tween_callback(_apply_step.bind(step_value))
	await _step_tween.finished
	stepping_finished.emit()

func _apply_step(v: float) -> void:
	set_value(v, true)
	stepped.emit(v)
