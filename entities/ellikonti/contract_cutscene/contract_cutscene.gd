extends Node3D
## Ellikonti's post-contract cutscene (user's storyboard "엘리콘티 계약 체결"):
##   1 black rubber arms burst out of her back and arc round to her mouth
##   2 camera eases in on the face, finger-ends grab the mouth corners
##   3 the mouth is torn wider in three beats -- camera pulls back FIRST,
##     then the mouth stretches ("약간" -> "좌악." -> "좌아악!")
##   4 the face (stretching as much as the mouth) balloons up over you and
##     hangs at the top of the screen like a UFO, all-red mouth open downward
##   5 it drops onto you until the red fills the screen, then two red
##     half-circle jaws clamp shut over you (jaws_close.gdshader) -> black
##   6 pitch dark; each of the three bells sends a line of light over the
##     inside of a dome around you (dome_light.gdshader)
##   7 ~5 s later -> next scene, where the stars burst up from below once
##     ("쨔라라라랑~", see contract_space.gd)
## Stays first person the whole way; the player is cutscene-locked from the
## instant the contract dialogue closes, and it can't be skipped (it can only
## ever play once anyway).
##
## Everything timed lives in the AnimationPlayer's "contract" animation:
## it keys the @export knobs below plus CamTarget/LookTarget positions, and
## has audio tracks for every SFX (entities/ellikonti/audio/) and a method key
## for the scene change. Retime things in the editor there, not
## in code. This script only turns those knobs into what Ellikonti's nodes
## actually do every frame.
##
## Spawned by ellikonti.gd as a child of the Ellikonti root and rotated to
## Visual's yaw, so local +Z always points from her toward the player and the
## camera keys are "in front of her" no matter where you stood.

const NEXT_SCENE := "res://scenes/ellikonti_contract_space.tscn"
const RETRO_SHADER := preload("res://shaders/retro_character.gdshader")
const INK_MATERIAL := preload("res://entities/ellikonti/materials/ek_ink.tres")
## Where the painted mouth sits on the head mesh (head local space), and how
## far it tilts down to lie on the head's surface there.
const MOUTH_POS := Vector3(0.0, -0.066, 0.175)
const MOUTH_TILT := 0.37

## 0 = the player's own view, 1 = CamTarget/LookTarget. Keyed at the start
## so the cutscene camera eases off from exactly where you were looking.
@export var cam_blend := 0.0
@export var cam_shake := 0.0
@export var arm_reach := 0.0
@export var arm_grip := 0.0
## TearMouth size in "closed mouth widths" -- x wide, y open.
@export var mouth_size := Vector2(1.0, 0.25)
## Multiplies Head's own scale (the face stretches like rubber).
@export var head_scale := Vector3.ONE
## 0 = head where it belongs, 1 = hovering high over the camera (the "UFO").
@export var head_rise := 0.0
## 0 = head where head_rise put it, 1 = right in front of the lens (the drop).
@export var head_push := 0.0
## Screen-space jaws: <0 hidden, 0 = open at the screen edges, 1 = shut.
@export var jaw_close := -1.0
## How much the camera turns to look at the mouth instead of LookTarget.
@export var look_head := 0.0
## Black overlay alpha.
@export var darkness := 0.0
## Line of light over the dark dome: <0 hidden, 0..1 sweeping left -> right
## (keyed three times, once per bell).
@export var sweep := -1.0
## Fades the level's ambience (wind) out as the world goes quiet.
@export var world_volume := 1.0

var _ellikonti: Node3D
var _visual: Node3D
var _head: Node3D
var _head_base_position: Vector3
var _head_base_scale: Vector3
var _mouth: Node3D
var _player: Node
var _start_pos: Vector3
var _start_look: Vector3
var _wind: AudioStreamPlayer
var _wind_base_db := 0.0

@onready var _camera: Camera3D = $Camera3D
@onready var _cam_target: Node3D = $CamTarget
@onready var _look_target: Node3D = $LookTarget
@onready var _arm_l: RubberArm = $ArmL
@onready var _arm_r: RubberArm = $ArmR
@onready var _black: ColorRect = $Overlay/Black
@onready var _jaws: ColorRect = $Overlay/Jaws
@onready var _anim: AnimationPlayer = $AnimationPlayer


func start(ellikonti: Node3D, visual: Node3D, head: Node3D) -> void:
	_ellikonti = ellikonti
	_visual = visual
	_head = head
	_head_base_position = head.position
	_head_base_scale = head.scale

	var player_cam := get_viewport().get_camera_3d()
	_start_pos = player_cam.global_position
	_start_look = _start_pos - player_cam.global_basis.z * 2.0
	_camera.fov = player_cam.fov
	_player = player_cam.get_parent()
	if _player and _player.has_method("set_cutscene_lock"):
		_player.set_cutscene_lock(true)
	# set_cutscene_lock shows the cursor; nothing to click here, so hide it
	# (deferred: the player's own dialogue_ended handler may run after us).
	Input.call_deferred("set_mouse_mode", Input.MOUSE_MODE_HIDDEN)

	_camera.top_level = true
	_camera.current = true
	_update_camera()

	var white := ShaderMaterial.new()
	white.shader = RETRO_SHADER
	white.set_shader_parameter("albedo_tex", _flat_texture(Color.WHITE))
	white.set_shader_parameter("shade_strength", 0.0)
	_arm_l.setup(INK_MATERIAL, white)
	_arm_r.setup(INK_MATERIAL, white)

	_mouth = _build_mouth()
	_head.add_child(_mouth)

	_wind = get_tree().current_scene.find_child("WindAmbience", true, false) as AudioStreamPlayer
	if _wind:
		_wind_base_db = _wind.volume_db

	_anim.play("contract")


func _process(_delta: float) -> void:
	if _head == null:
		return
	_update_camera()
	_update_head_and_mouth()
	_update_arms()
	_update_overlay()
	if _wind:
		_wind.volume_db = _wind_base_db + linear_to_db(maxf(world_volume, 0.0001))


func _update_camera() -> void:
	var pos := _start_pos.lerp(_cam_target.global_position, cam_blend)
	var look := _start_look.lerp(_look_target.global_position, cam_blend)
	if look_head > 0.0 and _mouth:
		look = look.lerp(_mouth.global_position, look_head)
	if cam_shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * cam_shake * 0.02
	_camera.look_at_from_position(pos, look)


# The head is driven in global space for the whole cutscene: always turned
# so its face (+Z) points at the camera, scaled by head_scale (it stretches
# with the mouth), then carried up over the camera (head_rise) and finally
# down onto the lens (head_push). ellikonti.gd stops its own look-up pitch
# while _in_cutscene so the two never fight over the head.
func _update_head_and_mouth() -> void:
	var parent := _head.get_parent() as Node3D
	var cam := _camera.global_position
	var pos := parent.to_global(_head_base_position)
	if head_rise > 0.0:
		var toward_her := Vector3(pos.x - cam.x, 0.0, pos.z - cam.z).normalized()
		var overhead := cam + Vector3.UP * 2.4 + toward_her * 1.6
		pos = pos.lerp(overhead, head_rise)
	var global_scale := parent.global_basis.get_scale() * _head_base_scale * head_scale
	var face := (cam - pos).normalized()
	var up := Vector3.UP if absf(face.y) < 0.98 else Vector3.FORWARD
	var rot := Basis.looking_at(-face, up)
	if head_push > 0.0:
		# Turn the MOUTH (not the head centre) square onto the lens, so no
		# forehead slides in between, and stop with the dome's tip just short
		# of the camera -- inside the back-face-culled dome you would see the
		# world behind it. The jaws overlay finishes the swallow from there.
		rot = rot.slerp(rot * Basis(Vector3.RIGHT, -MOUTH_TILT), head_push)
	var basis := rot * Basis.from_scale(global_scale)
	if head_push > 0.0:
		var normal := (basis * _mouth.transform.basis.z).normalized()
		var dome_depth := 0.02 * maxf(mouth_size.x, mouth_size.y) * global_scale.z
		var apex := cam - _camera.global_basis.z * 0.15
		var rim_centre := apex - normal * dome_depth
		pos = pos.lerp(rim_centre - basis * MOUTH_POS, head_push)
	_head.global_transform = Transform3D(basis, pos)
	_mouth.scale = Vector3(0.05 * mouth_size.x, 0.03 * mouth_size.y,
			0.02 * maxf(mouth_size.x, mouth_size.y))


func _update_arms() -> void:
	var basis := _visual.global_basis
	var side := basis.x.normalized()
	var up := basis.y.normalized()
	var fwd := basis.z.normalized()
	var span := _visual.global_basis.get_scale().x
	for arm_side in [-1.0, 1.0]:
		var arm: RubberArm = _arm_l if arm_side < 0.0 else _arm_r
		var shoulder := _visual.to_global(Vector3(0.07 * arm_side, 0.42, -0.08))
		var corner := _mouth.to_global(Vector3(arm_side, 0.0, 0.02))
		var reach_out := maxf(0.8, (corner - shoulder).length())
		arm.p0 = shoulder
		arm.p1 = shoulder + (side * arm_side * 0.9 + up * 0.55 - fwd * 0.35) * span * reach_out
		arm.p2 = corner + (side * arm_side * 0.55 + up * 0.25 + fwd * 0.45) * span * reach_out
		arm.p3 = corner
		arm.reach = arm_reach
		arm.grip = arm_grip


func _update_overlay() -> void:
	var dome := _black.material as ShaderMaterial
	dome.set_shader_parameter("darkness", darkness)
	dome.set_shader_parameter("sweep", sweep)
	(_jaws.material as ShaderMaterial).set_shader_parameter("close", jaw_close)


# The torn mouth: a red half-dome (rounded like the face, not a flat plate)
# swelling out of the head where the painted mouth was. All red, no black
# (user asked): bright at the rim, deeper red toward the middle so it still
# reads as an open hole. Separate 3D piece because the painted mouth layer
# can't open; mouth_size stretches it and the dome depth grows with it.
func _build_mouth() -> Node3D:
	var mouth := Node3D.new()
	mouth.name = "TearMouth"
	mouth.position = MOUTH_POS
	mouth.rotation.x = MOUTH_TILT
	var dome := MeshInstance3D.new()
	dome.mesh = _half_dome_mesh(7, 16)
	var grad := Image.create(1, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		var k := y / 15.0  # 0 = middle of the mouth, 1 = rim
		grad.set_pixel(0, y, Color(0.55, 0.0, 0.06).lerp(Color(0.92, 0.06, 0.11), k))
	var mat := ShaderMaterial.new()
	mat.shader = RETRO_SHADER
	mat.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(grad))
	mat.set_shader_parameter("shade_strength", 0.15)
	dome.material_override = mat
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mouth.add_child(dome)
	return mouth


# Unit half-sphere bulging toward +Z (rim on z=0). UV.y runs 0 at the
# centre -> 1 at the rim, for the gradient above.
func _half_dome_mesh(rings: int, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for r in rings + 1:
		var t := float(r) / rings
		var a := t * PI / 2.0
		var row: Array[Vector3] = []
		for sgm in segments + 1:
			var ang := TAU * sgm / segments
			row.append(Vector3(cos(ang) * sin(a), sin(ang) * sin(a), cos(a)))
		grid.append(row)
	for r in rings:
		for sgm in segments:
			var v00: Vector3 = grid[r][sgm]
			var v01: Vector3 = grid[r][sgm + 1]
			var v10: Vector3 = grid[r + 1][sgm]
			var v11: Vector3 = grid[r + 1][sgm + 1]
			var t0 := float(r) / rings
			var t1 := float(r + 1) / rings
			for v in [[v00, t0], [v01, t0], [v11, t1], [v00, t0], [v11, t1], [v10, t1]]:
				st.set_normal((v[0] as Vector3).normalized())
				st.set_uv(Vector2(0.5, v[1]))
				st.add_vertex(v[0])
	return st.commit()


func _flat_texture(c: Color) -> Texture2D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


# --- method-track callbacks -------------------------------------------------

func _finish() -> void:
	StoryFlags.set_flag("ellikonti_contract_cutscene_seen", true)
	# No set_cutscene_lock(false): the player goes away with this scene, and
	# unlocking would recapture/flash the mouse for one frame.
	get_tree().change_scene_to_file(NEXT_SCENE)
