"""Builds Ellikonti's low-poly 3D model in Blender and exports ellikonti.glb.

Run headless (Blender 5.x):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup \
      --python entities/ellikonti/model/build_ellikonti.py

The character is literally the user's sketch made solid: every shape in the
drawing (triangle hat, round head, the left-pointing torso triangle, the
teardrop hand, the long diagonal sliver, the circle) becomes one low-poly
piece, laid out on the sketch's 2D coordinates and pushed into 3D by giving
each piece some depth. Nothing is "interpreted" anatomically -- the sketch is
a character made of shapes, so the model is too.

The thick black marker lines of the sketch become inverted-hull ink shells
(<part>_Ink objects: a copy pushed out along the normals with flipped faces;
with back-face culling only the rim shows). The sketch's curly purple hair
behind the hat was tried and then removed at the user's request.

Materials are only named here (ek_<part>); the actual look -- painted
textures, vertex snapping, face layers -- lives in Godot materials that the
.glb import maps onto these names (see ellikonti.glb.import).

UVs are a plain front projection per object, normalised to the object's
bounds, so the painted texture's top-to-bottom gradient always runs
top-to-bottom on the part.

Axes: Blender is Z-up and the character faces -Y, which glTF/Godot turns into
Y-up facing +Z. Ink and named pivot objects (Head, Hat, Bell, Star) keep
their origin at their own pivot so Godot can animate them in place.
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "ellikonti.glb")

# Sketch pixel -> metres. The sketch (720x780) spans ~675px from star tip to
# the bottom of the purple; this makes the whole character ~1.1 m tall.
S = 0.0016
SKETCH_CX = 410.0
SKETCH_GROUND = 700.0
INK = 0.011  # ink shell thickness (m)


def sk(px, py):
    """Sketch pixel (x right, y down) -> Blender (X, Z)."""
    return ((px - SKETCH_CX) * S, (SKETCH_GROUND - py) * S)


# ------------------------------------------------------------------ helpers
def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


_materials = {}

# Viewport/preview colours only -- the real look is the Godot materials.
PREVIEW_COLORS = {
    "hat": (0.22, 0.02, 0.24, 1), "head": (0.2, 0.28, 0.58, 1),
    "torso": (0.12, 0.33, 0.12, 1), "hand": (0.11, 0.3, 0.11, 1), "knee": (0.24, 0.02, 0.72, 1),
    "leg": (0.15, 0.1, 0.5, 1), "star": (0.88, 0.85, 0.45, 1), "bell": (0.78, 0.62, 0.25, 1),
    "ink": (0.01, 0.01, 0.01, 1),
}


def mat(name):
    if name not in _materials:
        m = bpy.data.materials.new("ek_" + name)
        m.use_backface_culling = True
        m.diffuse_color = PREVIEW_COLORS.get(name, (1, 0, 1, 1))
        _materials[name] = m
    return _materials[name]


def obj_from_bmesh(name, bm, material, location=(0, 0, 0), smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    ob.location = location
    bpy.context.collection.objects.link(ob)
    me.materials.append(mat(material))
    front_project_uv(ob)
    return ob


def front_project_uv(ob):
    me = ob.data
    xs = [v.co.x for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    x0, x1 = min(xs), max(xs)
    z0, z1 = min(zs), max(zs)
    w = max(x1 - x0, 1e-6)
    h = max(z1 - z0, 1e-6)
    uv = me.uv_layers.new(name="UVMap")
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = ((co.x - x0) / w, (co.z - z0) / h)


def add_ink(ob, thickness=INK):
    """Inverted-hull outline: copy pushed out along normals, faces flipped."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * thickness
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    me = bpy.data.meshes.new(ob.name + "_Ink")
    bm.to_mesh(me)
    bm.free()
    me.materials.clear()
    me.materials.append(mat("ink"))
    for p in me.polygons:
        p.use_smooth = True
    ink = bpy.data.objects.new(ob.name + "_Ink", me)
    bpy.context.collection.objects.link(ink)
    ink.parent = ob
    front_project_uv(ink)
    return ink


def extrude_polygon(points_xz, depth, taper=0.0):
    """2D outline in the XZ plane -> prism along Y centred on Y=0.
    taper shrinks the back cap a bit so pieces look carved, not cut-out."""
    bm = bmesh.new()
    front = [bm.verts.new((x, -depth / 2, z)) for x, z in points_xz]
    cx = sum(p[0] for p in points_xz) / len(points_xz)
    cz = sum(p[1] for p in points_xz) / len(points_xz)
    k = 1.0 - taper
    back = [bm.verts.new((cx + (x - cx) * k, depth / 2, cz + (z - cz) * k)) for x, z in points_xz]
    n = len(points_xz)
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def centred(points_xz):
    cx = sum(p[0] for p in points_xz) / len(points_xz)
    cz = sum(p[1] for p in points_xz) / len(points_xz)
    return [(x - cx, z - cz) for x, z in points_xz], (cx, cz)


def uv_sphere(radius, segments, rings, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    return bm


# ------------------------------------------------------------------ parts
def build():
    clear_scene()
    root = bpy.data.objects.new("Ellikonti", None)
    bpy.context.collection.objects.link(root)

    def parent(ob):
        ob.parent = root
        return ob

    # Head: round, a bit squashed. Origin at the head centre -- the Godot
    # face-layer shader projects the face along this object's local +Z.
    hx, hz = sk(415, 355)
    head = parent(obj_from_bmesh("Head", uv_sphere(0.2, 12, 8, (1.0, 0.92, 0.92)), "head",
                                 (hx, 0.0, hz), smooth=True))
    add_ink(head)

    # Hat: 8-sided cone sitting low over the head, tilted like the sketch
    # (right side of the brim higher). Origin at the brim centre.
    bx, bz = sk(407, 322)
    hat_h = 0.39
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=8,
                          radius1=0.215, radius2=0.0, depth=hat_h)
    bmesh.ops.translate(bm, vec=(0, 0, hat_h / 2), verts=bm.verts)
    hat = parent(obj_from_bmesh("Hat", bm, "hat", (bx, 0.0, bz)))
    hat.rotation_euler = (math.radians(-6), math.radians(-10), 0)
    add_ink(hat)

    # Bell on the front of the hat (the bell drawn on it in the sketch),
    # pivot at its top so Godot can swing it.
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.045, radius2=0.022, depth=0.07)
    bmesh.ops.translate(bm, vec=(0, 0, -0.035), verts=bm.verts)
    knob = bmesh.new()
    bmesh.ops.create_uvsphere(knob, u_segments=6, v_segments=4, radius=0.013)
    # clapper peeking out under the bell
    clap = bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=4, radius=0.016)
    bmesh.ops.translate(bm, vec=(0, 0, -0.078), verts=clap["verts"])
    top = bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=4, radius=0.012)
    bmesh.ops.translate(bm, vec=(0, 0, 0.004), verts=top["verts"])
    knob.free()
    bell = obj_from_bmesh("Bell", bm, "bell", (0.0, -0.118, 0.17))
    bell.parent = hat
    add_ink(bell, 0.006)

    # Star: little 5-point star floating off the hat tip.
    sx, sz = sk(340, 72)
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = 0.04 if i % 2 == 0 else 0.019
        pts.append((math.cos(a) * r, math.sin(a) * r))
    star = parent(obj_from_bmesh("Star", extrude_polygon(pts, 0.022), "star", (sx, -0.02, sz)))
    star.rotation_euler = (0, math.radians(-14), 0)
    add_ink(star, 0.006)

    # Torso: the left-pointing triangle under the head.
    tri = [sk(412, 430), sk(238, 512), sk(532, 545)]
    pts, (cx, cz) = centred(tri)
    torso = parent(obj_from_bmesh("Torso", extrude_polygon(pts, 0.13, taper=0.25), "torso",
                                  (cx, 0.0, cz)))
    add_ink(torso)

    # Teardrop hand on the right, tail pointing back at the torso corner.
    tear = []
    c = (590, 508)
    for i in range(12):
        a = math.radians(-150 + i * 26)
        tear.append((c[0] + math.cos(a) * 58, c[1] - math.sin(a) * 52))
    tear.insert(0, (522, 548))
    tear_xz = [sk(px, py) for px, py in tear]
    tear_xz.reverse()
    pts, (cx, cz) = centred(tear_xz)
    hand = parent(obj_from_bmesh("Hand", extrude_polygon(pts, 0.10, taper=0.3), "hand",
                                 (cx, -0.02, cz)))
    add_ink(hand)

    # Circle: the round shape bottom-left, a squashed ball.
    kx, kz = sk(300, 618)
    knee = parent(obj_from_bmesh("Knee", uv_sphere(0.088, 10, 7, (1.0, 0.65, 1.0)), "knee",
                                 (kx, 0.0, kz), smooth=True))
    add_ink(knee)

    # The long diagonal sliver from under the head down to the bottom-right,
    # in front of everything (the sketch draws its lines over the rest).
    sliver = [sk(276, 426), sk(302, 438), sk(497, 686), sk(470, 699), sk(380, 667), sk(356, 640)]
    pts, (cx, cz) = centred(sliver)
    leg = parent(obj_from_bmesh("Leg", extrude_polygon(pts, 0.06, taper=0.15), "leg",
                                (cx, -0.085, cz)))
    add_ink(leg)

    # Sit the lowest point on the ground (Z=0).
    bpy.context.view_layer.update()
    low = min((ob.matrix_world @ v.co).z for ob in bpy.data.objects if ob.type == "MESH"
              for v in ob.data.vertices)
    root.location.z -= low


def export():
    bpy.ops.export_scene.gltf(
        filepath=OUT,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_image_format="NONE",
        export_materials="EXPORT",
    )
    print("exported", OUT)


def preview(path):
    """Workbench renders (front, 3/4, side) for a quick shape check."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_backface_culling = True
    scene.render.resolution_x = 480
    scene.render.resolution_y = 560
    scene.world = bpy.data.worlds.new("w")
    scene.world.color = (0.75, 0.75, 0.75)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.35
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    for name, yaw in (("front", 0), ("q", 40), ("side", 90), ("back", 180)):
        a = math.radians(yaw)
        cam.location = (math.sin(a) * 4, -math.cos(a) * 4, 0.55)
        cam.rotation_euler = (math.radians(90), 0, a)
        scene.render.filepath = path + "_" + name + ".png"
        bpy.ops.render.render(write_still=True)


build()
export()
if os.environ.get("EK_PREVIEW"):
    preview(os.environ["EK_PREVIEW"])
