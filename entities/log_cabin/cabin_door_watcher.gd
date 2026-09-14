extends Node
## Companion to the cabin's DoorInteractable, which uses dialogue_resource
## (cabin_door.dialogue) instead of Interactable's scene_to_load -- a
## .dialogue file's `$>` mutations can only call methods on autoloads/
## game-state objects, never get_tree(), so the actual scene transition
## can't happen inline in the dialogue. Instead, the "그래." choice just
## sets the "cabin_wants_enter" flag, and this watches for the dialogue
## balloon closing with that flag set to actually perform the change.

@export_file("*.tscn") var scene_to_load := ""

func _ready() -> void:
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	if StoryFlags.get_flag("cabin_wants_enter"):
		StoryFlags.set_flag("cabin_wants_enter", false)
		get_tree().change_scene_to_file(scene_to_load)
