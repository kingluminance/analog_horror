class_name DialogueVisibility
extends Node
## Generic "a dialogue can show/hide this whole entity" toggle, built on
## the same StoryFlags.visual_state mechanism trash_angel uses to swap its
## body. Any entity adds this as a plain child node and sets `entity_id`
## (usually the same id it already uses for StoryFlags visit-count/visual
## state calls). From any .dialogue file (this entity's own, or another
## entity's — the id is global), toggle it with:
##
##   using StoryFlags
##   $> StoryFlags.set_visual_state("<entity_id>", "visible", false)
##   $> StoryFlags.set_visual_state("<entity_id>", "visible", true)
##
## While hidden, the entity's own Interactable child (if it has one) is
## also disabled so a hidden object can't still be talked to. State is
## session-only, same as every other StoryFlags value — resets on restart.

@export var entity_id: String = ""

func _ready() -> void:
	if entity_id == "":
		push_warning("DialogueVisibility on '%s' has no entity_id set" % get_parent().name)
		return
	StoryFlags.visual_state_changed.connect(_on_visual_state_changed)
	_apply(StoryFlags.get_visual_state(entity_id, "visible", true))

func _on_visual_state_changed(id: String, key: String, value) -> void:
	if id == entity_id and key == "visible":
		_apply(value)

func _apply(is_visible: bool) -> void:
	var parent: Node3D = get_parent()
	parent.visible = is_visible
	var interactable: Area3D = parent.get_node_or_null("Interactable")
	if interactable:
		interactable.monitoring = is_visible
		if not is_visible:
			var hint: Label3D = interactable.get_node_or_null("InteractHint")
			if hint:
				hint.hide()
