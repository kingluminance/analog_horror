extends Node3D
## Attach to a node whose descendants are plain scenery meshes (main.tscn's
## `Trees`): at startup every MeshInstance3D under it whose name matches
## `mesh_name_filter` gets an invisible StaticBody3D with a convex hull of its
## mesh, on the SIGHT-ONLY physics layer. For trees that's just the trunks --
## the foliage cones start above head height and the camera regularly sits
## inside one when you stand under a tree, which would block everything.
## Nothing collides with that layer -- the player still walks straight
## through trees exactly as before -- it only exists so Interactable's
## line-of-sight ray can tell "this NPC is behind a tree" (you can't talk to
## someone you can't see; added after Ellikonti's contract cutscene played
## with a trunk in the way).

const SIGHT_LAYER := Interactable.SIGHT_BLOCKER_LAYER

## Only meshes whose node name matches this (String.match pattern) block
## sight. "*" = all of them.
@export var mesh_name_filter := "Trunk"


func _ready() -> void:
	for mesh_instance in find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_instance as MeshInstance3D
		if mi.mesh == null or not String(mi.name).match(mesh_name_filter):
			continue
		var body := StaticBody3D.new()
		body.collision_layer = SIGHT_LAYER
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = mi.mesh.create_convex_shape()
		body.add_child(shape)
		mi.add_child(body)
