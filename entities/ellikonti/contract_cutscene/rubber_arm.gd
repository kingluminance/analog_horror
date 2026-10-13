class_name RubberArm
extends Node3D
## One of the black rubber arms from Ellikonti's contract cutscene: a tube
## rebuilt every frame along a cubic Bezier (p0 shoulder -> p3 mouth corner),
## jet black with a white inverted-hull edge like the storyboard ("완전
## 검은색에 흰 테두리선"), ending in a few finger-ish prongs that curl shut
## as `grip` goes 0 -> 1.
##
## Top-level node: the four control points are in GLOBAL space and are fed in
## by contract_cutscene.gd each frame (they follow the shoulders and the
## stretching mouth corners), so the arm never inherits anyone's tremble or
## scale twice.

const RINGS := 22
const SIDES := 7
const FINGERS := 3

@export var radius := 0.045
@export var outline := 0.014

var p0 := Vector3.ZERO
var p1 := Vector3.ZERO
var p2 := Vector3.ZERO
var p3 := Vector3.ZERO
## 0..1: how much of the curve exists yet (the arm "shooting out").
var reach := 0.0
## 0..1: fingers open -> closed around the mouth corner.
var grip := 0.0

var _body := MeshInstance3D.new()
var _edge := MeshInstance3D.new()
var _body_mesh := ImmediateMesh.new()
var _edge_mesh := ImmediateMesh.new()
var _wobble_seed := randf() * 10.0


func setup(body_material: Material, edge_material: Material) -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_body.mesh = _body_mesh
	_edge.mesh = _edge_mesh
	_body.material_override = body_material
	_edge.material_override = edge_material
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body)
	add_child(_edge)


func _process(_delta: float) -> void:
	_body_mesh.clear_surfaces()
	_edge_mesh.clear_surfaces()
	if reach <= 0.001:
		return
	var t := Time.get_ticks_msec() / 1000.0 + _wobble_seed
	var spine: Array[Vector3] = []
	var radii: Array[float] = []
	for i in RINGS + 1:
		var u := reach * float(i) / RINGS
		spine.append(_bezier(u))
		# rubbery: thickness bulges and travels along the arm
		var bulge := 1.0 + 0.18 * sin(u * 14.0 - t * 9.0)
		radii.append(radius * lerpf(1.0, 0.7, u) * bulge)
	_tube(_body_mesh, spine, radii, 0.0, false)
	_tube(_edge_mesh, spine, radii, outline, true)

	# Fingers: short tapered prongs fanning out from the tip, curling toward
	# the mouth corner as grip closes.
	var tip: Vector3 = spine[spine.size() - 1]
	var fwd: Vector3 = (tip - spine[spine.size() - 2]).normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var up := side.cross(fwd).normalized()
	for f in FINGERS:
		var spread := (float(f) / (FINGERS - 1) - 0.5) * 1.4
		var dir := (fwd + up * spread * (1.0 - grip * 0.7)).normalized()
		var curl := fwd.lerp(-up * sign(spread + 0.001), grip * 0.6).normalized()
		var pts: Array[Vector3] = []
		var rr: Array[float] = []
		for k in 5:
			var s := float(k) / 4.0
			pts.append(tip + dir * 0.07 * s + curl * 0.04 * s * s * grip)
			rr.append(radius * 0.45 * (1.0 - s * 0.8))
		_tube(_body_mesh, pts, rr, 0.0, false)
		_tube(_edge_mesh, pts, rr, outline * 0.8, true)


func _bezier(u: float) -> Vector3:
	var a := p0.lerp(p1, u)
	var b := p1.lerp(p2, u)
	var c := p2.lerp(p3, u)
	return a.lerp(b, u).lerp(b.lerp(c, u), u)


# Builds a closed-ish tube (open ends are hidden inside the shoulder / under
# the fingers). inside_out flips the winding so, with back-face culling, only
# the far side shows -- the inverted-hull outline trick.
func _tube(mesh: ImmediateMesh, spine: Array[Vector3], radii: Array[float], grow: float, inside_out: bool) -> void:
	var n := spine.size()
	if n < 2:
		return
	var rings: Array = []
	var ref := Vector3.UP
	for i in n:
		var tangent: Vector3 = (spine[mini(i + 1, n - 1)] - spine[maxi(i - 1, 0)]).normalized()
		if absf(tangent.dot(ref)) > 0.95:
			ref = Vector3.RIGHT
		var nx := tangent.cross(ref).normalized()
		var ny := nx.cross(tangent).normalized()
		ref = ny  # carry the frame along so the tube doesn't twist
		var ring: Array[Vector3] = []
		var r: float = radii[i] + grow
		for s in SIDES:
			var a := TAU * s / SIDES
			ring.append(spine[i] + (nx * cos(a) + ny * sin(a)) * r)
		rings.append(ring)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n - 1:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		for s in SIDES:
			var s2 := (s + 1) % SIDES
			var quad := [r0[s], r1[s], r1[s2], r0[s2]]
			_tri(mesh, quad[0], quad[1], quad[2], inside_out)
			_tri(mesh, quad[0], quad[2], quad[3], inside_out)
	mesh.surface_end()


func _tri(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, inside_out: bool) -> void:
	# The ring order above comes out back-facing in Godot's winding, so the
	# solid body is the one that gets flipped (verified in a capture: with it
	# the other way round only the white edge showed).
	if not inside_out:
		var tmp := b
		b = c
		c = tmp
	var nrm := (b - a).cross(c - a).normalized()
	for v in [a, b, c]:
		mesh.surface_set_normal(nrm)
		mesh.surface_set_uv(Vector2(0.5, 0.5))
		mesh.surface_add_vertex(v)
