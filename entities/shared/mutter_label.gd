class_name MutterLabel
extends Node3D
## Reusable ambient "mutter" text: a floating Label3D that fades in, holds,
## and fades out near an entity own position. Styled like Interactable own
## [E] hint (billboard, no_depth_test, small outline) -- see
## entities/shared/interactable.tscn -- but meant for short ambient lines an
## entity says on its own initiative (an idle mumble, a reaction to something
## the player did nearby), independent of any dialogue balloon/conversation
## being open. Any entity instances mutter_label.tscn as a child (same
## instancing convention as interactable.tscn) and calls .say("...") from its
## own script whenever it wants a mutter to appear.
##
## No queue -- deliberately simple, per the plan this was built from. A new
## say() call while one is still showing just kills the running tween and
## restarts from a fresh fade-in. An entity that actually needs a queue
## (several mutters that must play back to back) should build that in its own
## script and just keep calling say() one at a time -- this component stays a
## dumb one-shot.

## Time to fade the text in from fully transparent.
@export var fade_in_time := 0.25

## How long the text stays fully visible before fading out, when say() is
## called with its default duration (-1).
@export var hold_time := 1.1

## Time to fade the text out to fully transparent.
@export var fade_out_time := 0.25

@onready var _label: Label3D = $Label3D

var _tween: Tween


## Show text near this node position, fading in / holding / fading out.
## duration <= 0 (the default) uses hold_time above, for a total runtime of
## fade_in_time + hold_time + fade_out_time (~1.6s with the defaults). Passing
## a positive duration replaces only the hold portion -- fade_in_time /
## fade_out_time stay as configured -- so callers can lengthen or shorten a
## specific line without also changing how briskly it fades.
func say(text: String, duration: float = -1.0) -> void:
	if is_instance_valid(_tween) and _tween.is_valid():
		_tween.kill()

	_label.text = text
	_label.modulate.a = 0.0
	_label.visible = true

	var hold: float = hold_time if duration <= 0.0 else maxf(0.0, duration - fade_in_time - fade_out_time)

	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, fade_in_time)
	_tween.tween_interval(hold)
	_tween.tween_property(_label, "modulate:a", 0.0, fade_out_time)
	_tween.tween_callback(func(): _label.visible = false)
