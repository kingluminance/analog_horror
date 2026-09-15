class_name AnalogDialogueLabel
extends DialogueLabel
## Thin subclass of the addon own DialogueLabel that adds an ambient
## "trembling text" look. tremble_level (0 = off, the default) is a plain
## top-level @export -- AnalogDialogueBalloon copies its own tremble_level
## onto this field right before assigning dialogue_line each new line (see
## analog_dialogue_balloon.gd apply_dialogue_line()), the same push pattern
## used for reveal_chars_per_second -> seconds_per_step.
##
## Godot RichTextLabel already ships a built-in [shake rate=.. level=..]...
## [/shake] BBCode effect, so this subclass only has to wrap the line text in
## [shake] tags when trembling is on -- no custom RichTextEffect resource
## needed. The base DialogueLabel explicitly documents _update_text() as an
## override point for exactly this kind of thing.
##
## The trickiest part: DialogueLabel drives its typewriter reveal through
## visible_characters / get_total_character_count(), which (with
## bbcode_enabled = true, as set on the base scene) count parsed/rendered
## glyphs, not raw source bytes -- BBCode tag characters like [shake ...] and
## [/shake] are consumed by the parser and never counted. Verified with a
## headless test (see the throwaway _tmp_test_dialogue_extensions scene used
## while building this) rather than assumed: wrapping the text in [shake]
## does not shift where visible_characters lands relative to the actual
## dialogue letters, so the reveal timing/indexing in the base class is
## undisturbed.

## How violently to shake (BBCode `level=`). 0 = no shake -- the default, so
## _update_text() below falls through to the exact same `text = ...` the base
## class would have set, byte-identical to today output.
@export var tremble_level: float = 0.0

## How fast to shake (BBCode `rate=`). Not exposed per-line from .dialogue
## files -- in practice one rate reads as "trembling" and there has been no
## need yet to tune it per NPC, so it is a constant rather than another
## @export to keep the balloon-facing surface small.
const TREMBLE_RATE := 14.0


func _update_text() -> void:
	super._update_text()
	if tremble_level > 0.0 and text != "":
		text = "[shake rate=%s level=%s]%s[/shake]" % [TREMBLE_RATE, tremble_level, text]
