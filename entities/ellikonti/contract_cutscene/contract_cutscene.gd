extends Node3D
## Ellikonti's post-contract cutscene (user's storyboard "엘리콘티 계약 체결"):
##   1 black rubber arms burst out of her back and arc round to her mouth
##   2 camera eases in on the face, finger-ends grab the mouth corners
##   3 the mouth is torn wider in three beats -- camera pulls back FIRST,
##     then the mouth stretches ("약간" -> "좌악." -> "좌아악!")
##   4 the mouth gets big enough to swallow you (red inside)
##   5 it lunges, the view is sucked in -> black
##   6 pitch dark, one white line of light sweeps past (small bell)
##   7 ~5 s later stars burst up from below -> next scene
## Stays first person the whole way; the player is cutscene-locked from the
## instant the contract dialogue closes, and it can't be skipped (it can only
## ever play once anyway).
##
## Everything timed lives in the AnimationPlayer's "contract" animation:
## it keys the @export knobs below plus CamTarget/LookTarget positions, and
## has audio tracks for every SFX (entities/ellikonti/audio/) and method keys
## for the star burst / scene change. Retime things in the editor there, not
## in code. This script only turns those knobs into what Ellikonti's nodes
## actually do every frame.
##
## Spawned by ellikonti.gd as a child of the Ellikonti root and rotated to
## Visual's yaw, so local +Z always points from her toward the player and the
## camera keys are "in front of her" no matter where you stood.

const NEXT_SCENE := "res://scenes/ellikonti_contract_space.tscn"
const RETRO_SHADER := preload("res://shaders/retro_character.gdshader")
const INK_MATERIAL := preload("res://entities/ellikonti/materials/ek_ink.tres")

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
## 0 = head where it belongs, 1 = right in front of the camera (the lunge).
@export var head_push := 0.0
## Black overlay alpha.
@export var darkness := 0.0
## White line of light: <0 hidden, 0..1 sweeping left -> right.
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
@onready var _sweep: ColorRect = $Overlay/Sweep
@onready var _stars: Array[CPUParticles2D] = [$Overlay/StarsPink, $Overlay/StarsGreen]
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
	if cam_shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * cam_shake * 0.02
	_camera.look_at_from_position(pos, look)


func _update_head_and_mouth() -> void:
	_head.scale = _head_base_scale * head_scale
	if head_push > 0.0:
		# Lunge: drag the head toward a point just in front of the lens.
		var parent := _head.get_parent() as Node3D
		var in_front := _camera.global_position - _camera.global_basis.z * 0.5
		var target_local := parent.to_local(in_front) - Vector3(0, -0.066, 0.175) * _head.scale
		_head.position = _head_base_position.lerp(target_local, head_push)
	else:
		_head.position = _head_base_position
	_mouth.scale = Vector3(0.05 * mouth_size.x, 0.03 * mouth_size.y, 1.0)


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
	var size := get_viewport().get_visible_rect().size
	_black.color.a = darkness
	_sweep.visible = sweep >= 0.0 and sweep <= 1.0
	_sweep.position = Vector2(lerpf(-40.0, size.x + 40.0, sweep), 0.0)
	_sweep.size = Vector2(6.0, size.y)
	for s in _stars:
		s.position = Vector2(size.x * 0.5, size.y + 20.0)
		s.emission_rect_extents = Vector2(size.x * 0.45, 10.0)


# The torn mouth: black lip disc, red inside, dark throat -- a separate 3D
# piece on the head (the painted mouth layer is blanked for the cutscene) so
# it can actually stretch far past the face. Sits where the painted mouth is
# and tilts to the head's surface there.
func _build_mouth() -> Node3D:
	var mouth := Node3D.new()
	mouth.name = "TearMouth"
	mouth.position = Vector3(0.0, -0.066, 0.175)
	mouth.rotation.x = 0.37
	for layer in [[1.0, 0.0, Color(0.06, 0.03, 0.06)], [0.84, 0.004, Color(0.85, 0.05, 0.12)],
			[0.45, 0.008, Color(0.28, 0.0, 0.05)]]:
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = layer[0]
		cyl.bottom_radius = layer[0]
		cyl.height = 0.002
		cyl.radial_segments = 12
		cyl.rings = 1
		disc.mesh = cyl
		disc.rotation.x = PI / 2  # cylinder axis Y -> facing +Z
		disc.position.z = layer[1]
		var mat := ShaderMaterial.new()
		mat.shader = RETRO_SHADER
		mat.set_shader_parameter("albedo_tex", _flat_texture(layer[2]))
		mat.set_shader_parameter("shade_strength", 0.0)
		disc.material_override = mat
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mouth.add_child(disc)
	return mouth


func _flat_texture(c: Color) -> Texture2D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


# --- method-track callbacks -------------------------------------------------

func _emit_stars() -> void:
	for s in _stars:
		s.restart()
		s.emitting = true


func _finish() -> void:
	StoryFlags.set_flag("ellikonti_contract_cutscene_seen", true)
	# No set_cutscene_lock(false): the player goes away with this scene, and
	# unlocking would recapture/flash the mouse for one frame.
	get_tree().change_scene_to_file(NEXT_SCENE)
