"""Baroque's travertine app icons, modelled and rendered in Blender after the user's Pinterest pin
(215046950953591573): a slab of stone per icon with its object raised on it, lit from the upper left.

The slab is a rounded square (the iOS icon shape), its top edge rounded, faced with the stone textures from
../make.py. Objects are either outlines from glyphs.json (traced from SF Symbols and type by glyphs.swift and
trace.py, or drawn procedurally there) extruded with rounded edges, or modelled from shapes (the flower, the camera,
the notepad, the compass, the calendar, the clock, the gem, the Notion cube, the weather's sun, AllTrails' faceted
peaks, Netflix's folded N, Find My's rings).

ICONS covers the user's own apps (dock, then pages one to three) and the pin's others, which the home screen no longer
shows. Stones alternate light and dark across each page, so no two neighbours share one.

Run (from anywhere):
    /Applications/Blender.app/Contents/MacOS/Blender -b -P MockLab/Textures/travertine/icons/build.py -- [slugs...]
Writes <slug>.png (512 x 512, transparent outside the tile) next to this file. Deterministic; no network.
With ICON_SET=rococo it takes its stones from ../../rococo/ (painted in The Bathing Pool's colours), brushes the
objects' paint, and writes the user's apps to ../../rococo/icons/.
"""
import json
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
SET = os.environ.get("ICON_SET", "travertine")
STONES = os.path.join(os.path.dirname(os.path.dirname(HERE)), SET)
OUT = HERE if SET == "travertine" else os.path.join(STONES, "icons")
PAINTED = SET == "rococo"
GLYPHS = json.load(open(os.path.join(HERE, "glyphs.json")))
TOP = 0.1          # the slab's thickness; its face is at z = TOP
RES = 512


# MARK: - Scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = "GPU"
    except Exception as e:  # CPU is fine, only slower
        print("GPU unavailable:", e)
    sc.cycles.samples = 128
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = RES
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0

    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = 1.0
    co = bpy.data.objects.new("cam", cam)
    co.location = (0, 0, 6)
    sc.collection.objects.link(co)
    sc.camera = co

    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.4
    sun.angle = math.radians(14)
    sun.color = (1.0, 0.96, 0.9)
    so = bpy.data.objects.new("sun", sun)
    d = Vector((1.0, -1.05, -0.95)).normalized()   # light from the upper left, falling to the lower right
    so.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(so)

    world = bpy.data.worlds.new("world")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.95, 0.9, 0.84, 1)
    bg.inputs["Strength"].default_value = 0.42


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


# MARK: - Materials

_mats = {}


def principled(name, color, rough=0.5, metal=0.0, coat=0.0):
    key = (name, color, rough, metal, coat)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*srgb(color), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if coat:
        b.inputs["Coat Weight"].default_value = coat
    if PAINTED:
        brushed(m, color)
    _mats[key] = m
    return m


def brushed(m, color):
    """Oil paint: the colour broken by long strokes (noise stretched along x) and their ridges in the bump."""
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (9, 70, 9)
    mp.inputs["Rotation"].default_value = (0, 0, math.radians(14))
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 1.0
    noise.inputs["Detail"].default_value = 4
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], noise.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    lo, hi = srgb(color), srgb(color)
    ramp.color_ramp.elements[0].color = (*[c * 0.84 for c in lo], 1)
    ramp.color_ramp.elements[1].color = (*[min(1, c * 1.14) for c in hi], 1)
    ramp.color_ramp.elements[0].position = 0.3
    ramp.color_ramp.elements[1].position = 0.7
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.25
    bump.inputs["Distance"].default_value = 0.003
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])


def srgb(h):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin((h >> 16) & 255), lin((h >> 8) & 255), lin(h & 255))


def stone(name):
    key = ("stone", name)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new("stone-" + name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.78
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Location"].default_value = (0.5, 0.5, 0)
    mp.inputs["Scale"].default_value = (0.62, 0.62, 1)
    if PAINTED:  # box projection lays the image on its side; turn it so the strokes run level, as painted
        mp.inputs["Rotation"].default_value = (0, 0, math.radians(90))
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(os.path.join(STONES, name + ".jpg"))
    img.projection = "BOX"
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], img.inputs["Vector"])
    nt.links.new(img.outputs["Color"], b.inputs["Base Color"])
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 140
    noise.inputs["Detail"].default_value = 6
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.12
    bump.inputs["Distance"].default_value = 0.004
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    _mats[key] = m
    return m


CREAM = lambda: principled("cream", 0xF2EADC, 0.42, coat=0.15)
GOLD = lambda: principled("gold", 0xE9B864, 0.3, metal=1.0)
TERRA = lambda: principled("terracotta", 0x9A5233, 0.48, coat=0.1)
BROWN = lambda: principled("brown", 0x6E3E22, 0.45, coat=0.1)
UMBER = lambda: principled("umber", 0x3E3128, 0.5)
INK = lambda: principled("ink", 0x14110E, 0.12, coat=0.6)
OLIVE = lambda: principled("olive", 0x6F7A4E, 0.5, coat=0.1)
SAGE = lambda: principled("sage", 0x96A271, 0.5, coat=0.1)


# MARK: - The slab

def rounded_square(half, radius, seg=18):
    pts = []
    for cx, cy, a0 in [(half - radius, half - radius, 0), (-half + radius, half - radius, 90),
                       (-half + radius, -half + radius, 180), (half - radius, -half + radius, 270)]:
        for i in range(seg + 1):
            a = math.radians(a0 + 90 * i / seg)
            pts.append((cx + radius * math.cos(a), cy + radius * math.sin(a)))
    return pts


def prism(points, z0, z1, name):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bot = [bm.verts.new((x, y, z0)) for x, y in points]
    top = [bm.verts.new((x, y, z1)) for x, y in points]
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)
    n = len(points)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([bot[i], bot[j], top[j], top[i]])
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    for p in me.polygons:
        p.use_smooth = True
    return ob


def bevel(ob, width, segments=5, angle=40):
    mod = ob.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    mod.harden_normals = True
    return mod


def slab(name):
    ob = prism(rounded_square(0.5, 0.225), 0, TOP, "slab")
    bevel(ob, 0.055, 8)
    ob.data.materials.append(stone(name))
    return ob


# MARK: - Extruded outlines

def outline(glyph, size, depth, round_, mat, at=(0.0, 0.0), rot=0.0, z=TOP, rings=None):
    """An outline from glyphs.json extruded `depth` and rounded `round_`, its larger side `size`, standing on z."""
    cu = bpy.data.curves.new("glyph", "CURVE")
    cu.dimensions = "2D"
    cu.fill_mode = "BOTH"
    cu.extrude = depth / 2
    cu.bevel_depth = round_
    cu.bevel_resolution = 5
    cu.offset = -round_
    for ring in (rings or GLYPHS[glyph]):
        sp = cu.splines.new("POLY")
        sp.points.add(len(ring) - 1)
        for i, (x, y) in enumerate(ring):
            sp.points[i].co = (x * size, y * size, 0, 1)
        sp.use_cyclic_u = True
        sp.use_smooth = True
    ob = link(bpy.data.objects.new(glyph, cu))
    ob.location = (at[0], at[1], z + depth / 2 + round_)
    ob.rotation_euler = (0, 0, math.radians(rot))
    ob.data.materials.append(mat)
    return ob


# MARK: - Modelled objects

def ellipsoid(sx, sy, sz, at, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=1, location=at)
    ob = bpy.context.active_object
    ob.scale = (sx, sy, sz)
    ob.rotation_euler = [math.radians(r) for r in rot]
    bpy.ops.object.shade_smooth()
    ob.data.materials.append(mat)
    return ob


def box(sx, sy, sz, at, mat, round_=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    ob = bpy.context.active_object
    ob.scale = (sx, sy, sz)
    ob.rotation_euler = [math.radians(r) for r in rot]
    bpy.ops.object.transform_apply(scale=True, rotation=False, location=False)
    if round_:
        bevel(ob, round_, 4, angle=60)
        bpy.ops.object.shade_smooth()
    ob.data.materials.append(mat)
    return ob


def disc(r, h, at, mat, round_=0.0, verts=96):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=at)
    ob = bpy.context.active_object
    if round_:
        bevel(ob, round_, 4, angle=60)
    bpy.ops.object.shade_smooth()
    ob.data.materials.append(mat)
    return ob


def ring(major, minor, at, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=96, minor_segments=24,
                                     location=at, rotation=[math.radians(r) for r in rot])
    ob = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    ob.data.materials.append(mat)
    return ob


def flower(at=(0, 0), r=0.31, petals=5):
    # Five broad petals cupped a little, a gold ring at the heart and a dark centre, as in the pin.
    for k in range(petals):
        a = 2 * math.pi * k / petals + math.pi / 2
        ellipsoid(r * 0.52, r * 0.46, 0.032, (at[0] + r * 0.55 * math.cos(a), at[1] + r * 0.55 * math.sin(a), TOP + 0.035),
                  CREAM(), rot=(0, -12, math.degrees(a)))
    ring(r * 0.22, r * 0.07, (at[0], at[1], TOP + 0.075), GOLD())
    disc(r * 0.17, 0.03, (at[0], at[1], TOP + 0.065), principled("eye", 0x3A2A1C, 0.5))
    box(0.014, r * 0.55, 0.01, (at[0] + 0.01, at[1] - r * 1.05, TOP + 0.01), principled("stem", 0x6F7A4E, 0.6), round_=0.004)


def camera():
    # A cream body with brown dials, a big black lens in a dark ring.
    box(0.74, 0.5, 0.12, (0, -0.04, TOP + 0.06), CREAM(), round_=0.07)
    box(0.26, 0.1, 0.07, (-0.06, 0.24, TOP + 0.05), CREAM(), round_=0.03)
    for x in (-0.27, 0.26):
        disc(0.045, 0.05, (x, 0.21, TOP + 0.06), BROWN(), round_=0.012)
    disc(0.235, 0.07, (0, -0.06, TOP + 0.13), principled("lensring", 0x2B2620, 0.35), round_=0.025)
    ring(0.215, 0.014, (0, -0.06, TOP + 0.17), principled("bronze", 0x8C6B48, 0.3, metal=1.0))
    ellipsoid(0.17, 0.17, 0.06, (0, -0.06, TOP + 0.15), INK())
    ellipsoid(0.04, 0.03, 0.012, (-0.06, -0.0, TOP + 0.21), principled("glint", 0xFFFFFF, 0.1))


def notepad():
    box(0.52, 0.66, 0.04, (0, -0.04, TOP + 0.02), CREAM(), round_=0.035)
    for i in range(5):
        box(0.34, 0.009, 0.004, (0.0, 0.12 - i * 0.085, TOP + 0.045), principled("rule", 0xA89276, 0.6))
    for i in range(4):
        ring(0.04, 0.011, (-0.18 + i * 0.12, 0.29, TOP + 0.055), GOLD(), rot=(90, 0, 0))


def compass():
    ring(0.33, 0.035, (0, 0, TOP + 0.03), GOLD())
    disc(0.31, 0.025, (0, 0, TOP + 0.015), principled("face", 0x3C4630, 0.55))
    for k in range(12):
        a = 2 * math.pi * k / 12
        long_ = k % 3 == 0
        box(0.006, 0.04 if long_ else 0.025, 0.008, (0.23 * math.cos(a), 0.23 * math.sin(a), TOP + 0.03), GOLD(),
            rot=(0, 0, math.degrees(a) + 90))
    for sign, mat in [(1, GOLD()), (-1, CREAM())]:
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.045, radius2=0, depth=0.22,
                                        location=(sign * 0.075, sign * 0.075, TOP + 0.045), rotation=(0, math.radians(90), math.radians(45 if sign > 0 else 225)))
        ob = bpy.context.active_object
        ob.scale = (1, 1, 1)
        ob.rotation_euler = (math.radians(-90), 0, math.radians(-45 if sign > 0 else 135))
        ob.scale = (1.0, 0.35, 1.0)
        ob.data.materials.append(mat)
    disc(0.025, 0.03, (0, 0, TOP + 0.055), GOLD(), round_=0.01)


def gear():
    outline("gear", 0.74, 0.06, 0.016, GOLD())


def calendar():
    for text, size, y, font in [("NOV", 0.24, 0.24, "/System/Library/Fonts/Supplemental/Futura.ttc"),
                                ("4", 0.92, -0.08, "/System/Library/Fonts/Supplemental/Futura.ttc")]:
        cu = bpy.data.curves.new("t", "FONT")
        cu.body = text
        cu.font = bpy.data.fonts.load(font)
        cu.size = size
        cu.align_x = "CENTER"
        cu.align_y = "CENTER"
        cu.extrude = 0.004
        cu.bevel_depth = 0.0025
        cu.bevel_resolution = 3
        cu.offset = -0.0025
        if text == "NOV":
            cu.space_character = 1.15
        ob = link(bpy.data.objects.new(text, cu))
        ob.location = (0, y, TOP + 0.02)
        ob.data.materials.append(BROWN())


def clock():
    disc(0.31, 0.045, (0, 0, TOP + 0.022), CREAM(), round_=0.016)
    for k in range(12):
        a = 2 * math.pi * k / 12
        disc(0.012 if k % 3 else 0.018, 0.012, (0.21 * math.cos(a), 0.21 * math.sin(a), TOP + 0.045), BROWN())
    box(0.022, 0.15, 0.012, (0, 0.06, TOP + 0.05), BROWN(), round_=0.006)
    box(0.12, 0.022, 0.012, (0.05, 0, TOP + 0.06), BROWN(), round_=0.006)
    disc(0.025, 0.02, (0, 0, TOP + 0.065), GOLD(), round_=0.006)


def gem():
    # A crystal lying on the stone: six long facets round its length, a point at each end, tilted to the light.
    me = bpy.data.meshes.new("gem")
    bm = bmesh.new()
    ring_ = [bm.verts.new((0.19 * math.cos(math.radians(60 * k + 30)), 0.0, 0.19 * math.sin(math.radians(60 * k + 30))))
             for k in range(6)]
    up = bm.verts.new((0, 0.4, 0))
    down = bm.verts.new((0, -0.3, 0))
    for k in range(6):
        a, b = ring_[k], ring_[(k + 1) % 6]
        bm.faces.new([a, b, up])
        bm.faces.new([b, a, down])
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new("gem", me))
    ob.location = (0, 0.02, TOP + 0.08)
    ob.rotation_euler = (math.radians(8), math.radians(14), math.radians(-24))
    ob.data.materials.append(principled("gem", 0xE2B259, 0.14, metal=1.0))


def notion_cube():
    bpy.ops.mesh.primitive_cube_add(size=0.44, location=(0, 0, TOP + 0.24))
    cube = bpy.context.active_object
    bevel(cube, 0.04, 5, angle=60)
    bpy.ops.object.shade_smooth()
    cube.data.materials.append(CREAM())
    cube.rotation_euler = (math.radians(22), math.radians(-22), 0)
    n = outline("notion-n", 0.26, 0.02, 0.006, UMBER(), z=0)
    n.parent = cube
    n.rotation_euler = (0, 0, 0)
    n.location = (0, 0, 0.22)


def spotify():
    disc(0.33, 0.05, (0, 0, TOP + 0.025), GOLD(), round_=0.018)
    outline("spotify-arcs", 1.0, 0.012, 0.004, principled("arcs", 0x3A3A26, 0.5), z=TOP + 0.05,
            rings=[[[x * 0.5, y * 0.5 - 0.06] for x, y in r] for r in GLYPHS["spotify-arcs"]])


def facet_peak(apex, left, right, heights, mat):
    """A mountain in relief: a triangle whose top is two planes meeting along the ridge from the summit to the middle
    of its foot, so the light catches one face and leaves the other. heights = (foot corners, ridge foot, summit)."""
    he, hm, ha = heights
    mid = ((left[0] + right[0]) / 2, (left[1] + right[1]) / 2)
    me = bpy.data.meshes.new("peak")
    bm = bmesh.new()
    b = [bm.verts.new((x, y, TOP)) for x, y in (apex, left, mid, right)]
    t = [bm.verts.new((apex[0], apex[1], TOP + ha)), bm.verts.new((left[0], left[1], TOP + he)),
         bm.verts.new((mid[0], mid[1], TOP + hm)), bm.verts.new((right[0], right[1], TOP + he))]
    bm.faces.new([t[0], t[1], t[2]])
    bm.faces.new([t[0], t[2], t[3]])
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new([b[i], b[j], t[j], t[i]])
    bm.faces.new(list(reversed(b)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new("peak", me))
    bevel(ob, 0.008, 3, angle=30)
    ob.data.materials.append(mat)
    return ob


def weather():
    # The sun up and to the left, half hidden by a cloud standing in front of it.
    sx, sy = -0.13, 0.12
    disc(0.15, 0.05, (sx, sy, TOP + 0.025), GOLD(), round_=0.02)
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        box(0.034, 0.07, 0.022, (sx + 0.225 * math.cos(a), sy + 0.225 * math.sin(a), TOP + 0.011), GOLD(), round_=0.012,
            rot=(0, 0, math.degrees(a) + 90))
    outline("cloud", 0.6, 0.06, 0.035, CREAM(), at=(0.07, -0.1))


def alltrails():
    # Two peaks, the larger in front and standing higher so it hides the foot of the other.
    facet_peak((-0.17, 0.12), (-0.41, -0.24), (0.07, -0.24), (0.01, 0.035, 0.07), CREAM())
    facet_peak((0.08, 0.3), (-0.27, -0.24), (0.41, -0.24), (0.06, 0.1, 0.15), CREAM())


def gmail():
    # The M: two olive posts, the terracotta flap standing a little proud of them.
    outline("gmail-posts", 0.68, 0.045, 0.018, OLIVE())
    outline("gmail-v", 0.68, 0.065, 0.018, TERRA())


def ubereats():
    outline("uber", 0.64, 0.035, 0.009, INK())
    outline("eats", 0.64, 0.035, 0.009, principled("eats", 0x55663A, 0.45, coat=0.15))


def netflix():
    # The N as a ribbon: two dark posts, the bright diagonal folded over them and cut flush with their ends.
    dark = principled("netflix-dark", 0x7A2D1C, 0.45, coat=0.15)
    red = principled("netflix-red", 0xB4472E, 0.38, coat=0.25)
    for x in (-0.15, 0.15):
        box(0.13, 0.62, 0.04, (x, 0, TOP + 0.02), dark, round_=0.01)
    ob = prism([(0.085, -0.31), (0.215, -0.31), (-0.085, 0.31), (-0.215, 0.31)], TOP, TOP + 0.065, "diagonal")
    bevel(ob, 0.01, 4, angle=40)
    ob.data.materials.append(red)


def findmy():
    # Rings spreading from a gold dot.
    ring(0.3, 0.03, (0, 0, TOP + 0.03), OLIVE())
    ring(0.18, 0.034, (0, 0, TOP + 0.034), OLIVE())
    disc(0.075, 0.06, (0, 0, TOP + 0.03), GOLD(), round_=0.022)


def slack():
    # Four colours, as Slack's own: red, blue, green, yellow become terracotta, cream, sage and gold.
    for k, mat in enumerate([principled("slack-red", 0xB4553A, 0.42, coat=0.15), CREAM(), SAGE(), GOLD()]):
        outline(f"slack-{k}", 0.66, 0.045, 0.016, mat)


def half_ring(major, minor, a0, a1, at, mat):
    """A stretch of a ring lying on the stone, from angle a0 to a1 (degrees, 0 to the right, 90 up), its ends capped."""
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=192, minor_segments=24,
                                     location=at)
    ob = bpy.context.active_object
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    cut = [v for v in bm.verts if not (a0 - 0.5 <= (math.degrees(math.atan2(v.co.y, v.co.x)) % 360) <= a1 + 0.5)]
    bmesh.ops.delete(bm, geom=cut, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    bpy.ops.object.shade_smooth()
    ob.data.materials.append(mat)
    for a in (a0, a1):
        ellipsoid(minor, minor, minor, (at[0] + major * math.cos(math.radians(a)), at[1] + major * math.sin(math.radians(a)), at[2]), mat)
    return ob


def terra_sunarc():
    # Baroque's own icon: Sun Arc. The sun's path as on the widget: the day gone inlaid in gold, the rest a dark groove,
    # the gold sun where it is now, a gold horizon at the arc's feet.
    c, r, done = (0.0, -0.17), 0.27, 112
    half_ring(r, 0.016, done, 180, (c[0], c[1], TOP + 0.016), GOLD())
    half_ring(r, 0.007, 0, done, (c[0], c[1], TOP + 0.001), principled("groove", 0x4A3C2C, 0.8))
    box(0.64, 0.014, 0.012, (0, c[1] - 0.01, TOP + 0.006), GOLD(), round_=0.005)
    sx, sy = c[0] + r * math.cos(math.radians(done)), c[1] + r * math.sin(math.radians(done))
    disc(0.062, 0.045, (sx, sy, TOP + 0.036), GOLD(), round_=0.018)
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        box(0.022, 0.042, 0.018, (sx + 0.1 * math.cos(a), sy + 0.1 * math.sin(a), TOP + 0.027), GOLD(), round_=0.008,
            rot=(0, 0, math.degrees(a) + 90))


def youtube():
    # The red frame and, in its window, the cream play triangle.
    outline("play", 0.64, 0.05, 0.02, TERRA())
    outline("play-triangle", 0.64, 0.03, 0.01, CREAM(), rings=[GLYPHS["play"][1]])


# MARK: - The icons

def glyph(name, size, mat, depth=0.05, round_=0.018, at=(0, 0), rot=0):
    return lambda: outline(name, size, depth, round_, mat(), at=at, rot=rot)


APPS = {
    # The dock.
    "claude": ("terracotta", glyph("claude", 0.68, CREAM, 0.05, 0.02)),
    "messages": ("moss", glyph("bubble", 0.66, CREAM, 0.06, 0.035)),
    "safari": ("travertine", compass),
    "obsidian": ("umber", gem),
    # Page one, under the large widget.
    "gmail": ("travertine", gmail),
    "photos": ("moss", flower),
    "camera": ("travertine", camera),
    "youtube": ("umber", youtube),
    "settings": ("olive", gear),
    "spotify": ("umber", spotify),
    "maps": ("olive", glyph("pin", 0.64, CREAM, 0.06, 0.03)),
    "calendar": ("travertine", calendar),
    # Page two, between the medium widgets.
    "weather": ("travertine", weather),
    "alltrails": ("moss", alltrails),
    "ubereats": ("travertine", ubereats),
    "netflix": ("umber", netflix),
    "equinox": ("umber", glyph("eqx", 0.7, CREAM, 0.045, 0.012)),
    "findmy": ("travertine", findmy),
    "slack": ("umber", slack),
    "clock": ("travertine", clock),
    # Page three.
    "wallet": ("umber", glyph("wallet", 0.6, CREAM, 0.04, 0.016)),
    "appstore": ("olive", glyph("appstore", 0.6, CREAM, 0.05, 0.02)),
    "files": ("tan", glyph("folder", 0.64, CREAM, 0.05, 0.022)),
    "venmo": ("verde", glyph("venmo", 0.58, CREAM, 0.05, 0.02)),
}
# Baroque's own app icon, rendered opaque at 1024 px, framed inside the slab's flat face (iOS rounds the corners).
APP_ICON = {"appicon": ("travertine", terra_sunarc)}
# The pin's others, no longer on the home screen.
OTHERS = {
    "phone": ("olive", glyph("phone", 0.62, CREAM, 0.05, 0.03)),
    "baroque": ("olive", glyph("mountain", 0.68, CREAM, 0.04, 0.016)),
    "notes": ("umber", notepad),
    "mail": ("umber", lambda: (outline("envelope", 0.66, 0.045, 0.016, CREAM()),
                               outline("envelope-lines", 0.66, 0.012, 0.006, GOLD(), z=TOP + 0.035))),
    "music": ("travertine", glyph("music", 0.62, BROWN, 0.05, 0.02)),
    "notion": ("terracotta", notion_cube),
    "pinterest": ("terracotta", glyph("pinterest", 0.62, CREAM, 0.05, 0.022)),
    "instagram": ("tan", glyph("instagram", 0.6, CREAM, 0.04, 0.016)),
    "health": ("travertine", glyph("heart", 0.6, TERRA, 0.06, 0.035)),
    "podcasts": ("umber", glyph("mic", 0.62, GOLD, 0.05, 0.02)),
}
ICONS = {**APPS, **OTHERS, **APP_ICON}


def build(slug):
    reset()
    _mats.clear()
    stone_name, make = ICONS[slug]
    slab(stone_name)
    make()
    if slug in APP_ICON:
        sc = bpy.context.scene
        sc.render.resolution_x = sc.render.resolution_y = 1024
        sc.render.film_transparent = False
        sc.camera.data.ortho_scale = 0.74
    bpy.context.scene.render.filepath = os.path.join(OUT, slug + ".png")
    bpy.ops.render.render(write_still=True)
    print("rendered", slug)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for slug in (argv or list(ICONS if SET == "travertine" else APPS)):
        build(slug)


main()
