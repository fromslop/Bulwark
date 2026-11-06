"""Hoardsman enemy models: one low-poly glTF per character, built in Blender from code.

Run from the project folder:
    blender --background --python tools/enemy_models.py            (all twelve)
    blender --background --python tools/enemy_models.py -- footman  (just one)

Every model is split into the parts the game's rig expects, each its own object:
    Torso, Head, RightHand, LeftHand   geometry in that rig node's local space
    PauldronL, PauldronR               the armour that breaks off: the object sits at the
                                       shoulder (in torso space) and its geometry is local to it
    Weapon                             held by RightHand; Shield is held by LeftHand
Anything else named <Part>_<thing> (Head_Hat, Torso_Belt...) is hung on that part.

Coordinates in this file are Godot's: +x right, +y up, +z towards the camera, metres,
with each part's origin at its rig node (the torso node sits at y 1.22, the head at 1.68).
Materials are flat colours. A material named tint_* is blended with the character's
data.color in the game; glow_* materials are emissive (eyes, enchanted blades) and are
left alone by wounds. Everything is flat shaded: silhouette and big shapes carry it,
since the world grade recolours the whole 3D layer anyway.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "enemies"))
TAU = math.tau


# --- mesh kit -------------------------------------------------------------------------

def to_blender(p):
    """Godot (x, y up, z front) to Blender (x, -z, y): the glTF exporter turns it back."""
    return Vector((p[0], -p[2], p[1]))


def rot_matrix(rot):
    if not rot:
        return Matrix.Identity(3)
    return Matrix.Rotation(rot[2], 3, "Z") @ Matrix.Rotation(rot[1], 3, "Y") @ Matrix.Rotation(rot[0], 3, "X")


class Part:
    """One exported object: a bmesh plus the list of materials its faces use."""

    def __init__(self, name, origin=(0, 0, 0)):
        self.name = name
        self.origin = Vector(origin)
        self.bm = bmesh.new()
        self.mats = []
        self.turn = 0.0  # radians about the part's own +Y (Godot), applied when it's finished

    def _mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _face(self, verts, mi):
        try:
            f = self.bm.faces.new(verts)
        except ValueError:
            return None
        f.material_index = mi
        f.smooth = False
        return f

    def loft(self, rings, mat, pos=(0, 0, 0), rot=None, cap=True):
        """Skin a stack of rings (lists of points, all the same length) into a solid.
        A ring that is a single point is an apex: the faces come to it in a fan."""
        mi = self._mi(mat)
        R = rot_matrix(rot)
        pos = Vector(pos)
        vr = []
        for ring in rings:
            if isinstance(ring[0], (int, float)):
                vr.append(self.bm.verts.new(to_blender(R @ Vector(ring) + pos)))
            else:
                vr.append([self.bm.verts.new(to_blender(R @ Vector(p) + pos)) for p in ring])
        for a, b in zip(vr, vr[1:]):
            a_apex = isinstance(a, bmesh.types.BMVert)
            b_apex = isinstance(b, bmesh.types.BMVert)
            if a_apex and b_apex:
                continue
            if a_apex:
                n = len(b)
                for i in range(n):
                    self._face((a, b[(i + 1) % n], b[i]), mi)
            elif b_apex:
                n = len(a)
                for i in range(n):
                    self._face((a[i], a[(i + 1) % n], b), mi)
            else:
                n = len(a)
                for i in range(n):
                    self._face((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]), mi)
        if cap:
            if not isinstance(vr[0], bmesh.types.BMVert):
                self._face(list(reversed(vr[0])), mi)
            if not isinstance(vr[-1], bmesh.types.BMVert):
                self._face(vr[-1], mi)

    def lathe(self, profile, sides, mat, pos=(0, 0, 0), rot=None, phase=0.0, scale=(1, 1), cap=True, jitter=None):
        """Spin a profile of (radius, y) pairs, bottom to top, around y. A radius of 0 is an
        apex. A third value on a pair scales every other vertex: fluting, fur, jagged hems.
        scale squashes the ring (x, z); jitter is a Random that dents every vertex."""
        rings = []
        for pr in profile:
            r, y = pr[0], pr[1]
            alt = pr[2] if len(pr) > 2 else 1.0
            if r <= 1e-5:
                rings.append((0.0, y, 0.0))
                continue
            ring = []
            for i in range(sides):
                a = phase + i * TAU / sides
                rr = r * (alt if i % 2 else 1.0)
                if jitter:
                    rr *= 1.0 + jitter.uniform(-0.1, 0.1)
                ring.append((math.sin(a) * rr * scale[0], y, math.cos(a) * rr * scale[1]))
            rings.append(ring)
        self.loft(rings, mat, pos, rot, cap)

    def box(self, size, pos=(0, 0, 0), mat="", rot=None, taper=(1, 1), chamfer=0.0):
        """A block; taper scales the top (x, z); chamfer bevels the top and bottom edges."""
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2

        def ring(y, kx, kz):
            return [(-hx * kx, y, -hz * kz), (hx * kx, y, -hz * kz), (hx * kx, y, hz * kz), (-hx * kx, y, hz * kz)]

        if chamfer > 0:
            c = chamfer
            rings = [ring(-hy, 1 - c, 1 - c), ring(-hy + c * hy, 1, 1),
                     ring(hy - c * hy, taper[0], taper[1]), ring(hy, taper[0] * (1 - c), taper[1] * (1 - c))]
        else:
            rings = [ring(-hy, 1, 1), ring(hy, taper[0], taper[1])]
        self.loft(rings, mat, pos, rot)

    def poly(self, pts, depth, mat, pos=(0, 0, 0), rot=None, taper=1.0):
        """A flat outline (x, y), counter-clockwise, extruded along z: blades, shields, feathers."""
        rings = [[(x, y, -depth / 2) for x, y in pts], [(x * taper, y * taper, depth / 2) for x, y in pts]]
        self.loft(rings, mat, pos, rot)

    def sphere(self, r, pos=(0, 0, 0), mat="", segs=8, rings=4, scale=(1, 1, 1), rot=None):
        prof = [(0, -r * scale[1])]
        for k in range(1, rings):
            t = math.pi * k / rings
            prof.append((math.sin(t) * r, -math.cos(t) * r * scale[1]))
        prof.append((0, r * scale[1]))
        self.lathe(prof, segs, mat, pos, rot, scale=(scale[0], scale[2]))

    def finish(self, palette):
        if self.turn:
            # (Godot +Y is Blender +Z: to_blender is a plain rotation)
            bmesh.ops.rotate(self.bm, verts=self.bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(self.turn, 3, "Z"))
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        mesh.update()
        for m in self.mats:
            mesh.materials.append(material(m, palette))
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.location = to_blender(self.origin)
        return obj


def material(key, palette):
    col = palette[key]
    name = "%s@%.3f,%.3f,%.3f" % (key, col[0], col[1], col[2])  # (the game reads the prefix: tint_, glow_)
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (col[0], col[1], col[2], 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    if key.startswith("glow"):
        bsdf.inputs["Emission Color"].default_value = (col[0], col[1], col[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    return mat


class Char:
    def __init__(self, slug, palette):
        self.slug = slug
        self.palette = palette
        self.parts = []

    def part(self, name, origin=(0, 0, 0)):
        p = Part(name, origin)
        self.parts.append(p)
        return p


def shade(c, k):
    """Darken (k < 0) or lighten (k > 0) a colour, like Godot's darkened/lightened."""
    if k < 0:
        return tuple(v * (1 + k) for v in c)
    return tuple(v + (1 - v) * k for v in c)


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


# --- shared body pieces ---------------------------------------------------------------

def capsule(P, a, b, r, mat, segs=6, r2=None, rings=2):
    """A rounded rod from a to b (Godot coordinates), radius r tapering to r2: fingers,
    thumbs, straps. Ends are domed."""
    a, b = Vector(a), Vector(b)
    d = b - a
    ln = d.length
    if ln < 1e-6:
        return
    ax = d / ln
    up = Vector((0, 1, 0)) if abs(ax.y) < 0.9 else Vector((1, 0, 0))
    u = ax.cross(up).normalized()
    v = ax.cross(u).normalized()
    r2 = r if r2 is None else r2

    def ring(t, rad):
        c = a + d * t
        return [tuple(c + (u * math.cos(TAU * i / segs) + v * math.sin(TAU * i / segs)) * rad) for i in range(segs)]

    cap = min(0.3, r / max(ln, 1e-6))
    stack = [tuple(a - ax * r * 0.5)]
    for k in range(rings + 1):
        t = cap + (1 - 2 * cap) * k / rings
        stack.append(ring(t, r + (r2 - r) * t))
    stack.append(tuple(b + ax * r2 * 0.5))
    P.loft(stack, mat)


def fist(P, mat, s=0.12, side=1, knuckles=None, thumb=True):
    """A hand closed round a grip, built the way a VR controller is held, so recorded wrists
    turn it the right way: the grip (and the weapon) runs along +Y through the fist and the
    arm leaves out of the bottom (-Y); the thumb lies along the top (+Z); the fingers curl
    underneath (-Z); the back of the hand faces outward (+x for the right hand, side=+1)
    with the knuckles along its lower edge. A few chunky forms, so it reads at a glance
    from any side."""
    kn = knuckles or mat
    o = side
    P.box((s * 0.42, s * 0.95, s * 0.74), (o * s * 0.24, -s * 0.02, -s * 0.02), mat, chamfer=0.45)  # the back of the hand
    P.box((s * 0.66, s * 0.84, s * 0.36), (0, -s * 0.04, -s * 0.28), mat, chamfer=0.5)  # the fingers, curled under the grip
    P.box((s * 0.3, s * 0.8, s * 0.46), (-o * s * 0.24, -s * 0.04, -s * 0.06), mat, chamfer=0.5)  # their tips, tucked into the palm
    P.box((s * 0.22, s * 0.92, s * 0.22), (o * s * 0.3, -s * 0.02, -s * 0.3), kn, chamfer=0.45)  # the knuckles
    if thumb:
        capsule(P, (o * s * 0.2, -s * 0.28, s * 0.26), (-o * s * 0.04, s * 0.3, s * 0.3), s * 0.13, mat, segs=6, r2=s * 0.11)
    P.lathe([(s * 0.26, -s * 0.78), (s * 0.3, -s * 0.46)], 8, mat)  # the wrist


def open_hand(P, mat, s=0.11, side=1, finger_mat=None, length=0.1):
    """A palm with four long jointed fingers and a thumb: wraiths, bare hands."""
    P.box((s, s * 0.9, s * 0.4), (0, 0, 0), mat, chamfer=0.4)
    fm = finger_mat or mat
    for k in range(4):
        x = -s * 0.36 + k * s * 0.24
        ln = length * (0.85 if k in (0, 3) else 1.0)
        a = (x, -s * 0.42, s * 0.04)
        b = (x * 1.1, -s * 0.42 - ln * 0.55, s * 0.1)
        c = (x * 1.15, -s * 0.42 - ln, s * 0.2)
        capsule(P, a, b, s * 0.09, fm, segs=5)
        capsule(P, b, c, s * 0.08, fm, segs=5, r2=s * 0.05)
    capsule(P, (-side * s * 0.45, -s * 0.05, s * 0.05), (-side * s * 0.75, -s * 0.4, s * 0.15), s * 0.1, fm, segs=5, r2=s * 0.07)


def gauntlet(P, steel, dark, s=0.12, side=1):
    """An armoured fist (see fist() for how it's held): a flared cuff at the wrist, a
    knuckle plate along the knuckles, lames across the back of the hand."""
    fist(P, steel, s, side, knuckles=dark)
    P.lathe([(s * 0.42, -s * 0.55), (s * 0.66, -s * 0.98)], 8, dark)  # flared cuff, below the wrist
    P.box((s * 0.16, s * 0.98, s * 0.16), (side * s * 0.4, -s * 0.02, -s * 0.38), dark, chamfer=0.4)  # the knuckle plate
    for k in range(3):
        P.box((s * 0.08, s * 0.14, s * 0.62), (side * s * 0.47, s * (0.28 - 0.24 * k), -s * 0.02), dark, chamfer=0.3)  # lames on the back


def sword(P, blade, guard, grip, length=0.85, width=0.06, thick=0.02, fuller=False):
    """A straight sword held point-up along +y: diamond-section blade, crossguard, grip, pommel."""
    y0 = 0.1
    def ring(y, w, t):
        return [(-w / 2, y, 0), (0, y, t / 2), (w / 2, y, 0), (0, y, -t / 2)]
    P.loft([ring(y0, width, thick), ring(y0 + length * 0.75, width * 0.82, thick),
            ring(y0 + length * 0.93, width * 0.45, thick * 0.7), (0, y0 + length, 0)], blade)
    P.box((0.2, 0.03, 0.045), (0, y0 - 0.01, 0), guard, chamfer=0.3)
    P.lathe([(0.02, -0.12), (0.023, 0.08)], 6, grip)
    P.sphere(0.03, (0, -0.14, 0), guard, segs=6, rings=3)


def crown(P, gold, r=0.14, y=0.2):
    P.lathe([(r, y - 0.03), (r * 0.95, y + 0.04)], 8, gold)
    for k in range(6):
        a = k * TAU / 6
        P.loft([[(math.sin(a) * r - 0.02, y + 0.03, math.cos(a) * r - 0.02), (math.sin(a) * r + 0.02, y + 0.03, math.cos(a) * r - 0.02),
                 (math.sin(a) * r + 0.02, y + 0.03, math.cos(a) * r + 0.02), (math.sin(a) * r - 0.02, y + 0.03, math.cos(a) * r + 0.02)],
                (math.sin(a) * r, y + 0.12, math.cos(a) * r)], gold)


def face(P, skin, dark, w=0.24, h=0.3, nose=True, brow=True, eyes=True, mouth=None):
    """A bare head: an eight-sided lathe with a jaw, and no face on it. Modelled human
    faces never looked right, so a head without a helmet or a hood is left blank (a
    helmet's slits and a hood's shadowed features are fine). The feature arguments are
    kept so old calls still read, and ignored."""
    P.lathe([(w * 0.3, -h * 0.5), (w * 0.44, -h * 0.35), (w * 0.5, -h * 0.05), (w * 0.52, h * 0.25),
             (w * 0.42, h * 0.45), (0, h * 0.52)], 8, skin, scale=(1, 0.92), phase=TAU / 16)


def eye_slit(P, dark, w=0.24, y=0.03, z=0.16):
    P.box((w, 0.028, 0.02), (0, y, z), dark)


# --- the characters -------------------------------------------------------------------

def footman():
    cloth = (0.3, 0.38, 0.58)  # a faded blue levy coat: it reads against the warm stone of the first rooms
    leather = (0.35, 0.22, 0.12)
    skin = (0.8, 0.62, 0.5)
    c = Char("footman", {"tint_cloth": cloth, "tint_cloth_dark": shade(cloth, -0.3), "leather": leather,
                         "leather_light": shade(leather, 0.1), "skin": skin, "dark": (0.05, 0.03, 0.02), "beard": (0.3, 0.2, 0.12),
                         "iron": (0.4, 0.4, 0.42), "iron_dark": (0.35, 0.35, 0.37), "brass": (0.6, 0.55, 0.4),
                         "steel": (0.6, 0.6, 0.62), "wood": (0.3, 0.25, 0.18), "sash": (0.6, 0.14, 0.1)})
    T = c.part("Torso")
    # a quilted gambeson: every other ring pinched in, so the quilting shows in the silhouette
    prof = []
    for k in range(7):
        y = -0.34 + k * 0.11
        r = 0.27 + 0.03 * math.sin(k / 6 * math.pi)
        prof.append((r if k % 2 else r * 0.93, y))
    prof.append((0.2, 0.36))
    T.lathe(prof, 8, "tint_cloth", phase=TAU / 16)
    T.lathe([(0.13, 0.3), (0.15, 0.42)], 8, "tint_cloth_dark")  # collar
    T.box((0.54, 0.08, 0.5), (0, -0.26, 0), "leather", chamfer=0.2)
    T.box((0.08, 0.06, 0.02), (0, -0.26, 0.26), "brass")
    T.box((0.04, 0.3, 0.02), (0, 0.05, 0.27), "tint_cloth_dark")  # the front seam
    for row in range(5):  # quilting: rows of stitches across the gambeson
        for k in range(6):
            T.box((0.035, 0.008, 0.008), (-0.19 + k * 0.076, -0.17 + row * 0.11, 0.27 - 0.03 * abs(k - 2.5) / 2.5), "tint_cloth_dark")
    # the levy's red sash, shoulder to hip, with a pouch and the lord's brass badge
    T.box((0.07, 0.72, 0.02), (0.02, 0.0, 0.285), "sash", rot=(0, 0, 0.62))
    T.box((0.1, 0.09, 0.05), (0.17, -0.2, 0.27), "leather", chamfer=0.3)  # the pouch
    T.box((0.1, 0.02, 0.055), (0.17, -0.16, 0.27), "leather_light")
    T.lathe([(0.032, -0.006), (0.036, 0.0), (0.032, 0.006)], 8, "brass", pos=(-0.1, 0.16, 0.3), rot=(math.pi / 2, 0, 0))
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.3, 0.22, 0))
        P.lathe([(0.1, -0.03), (0.13, 0.0), (0.1, 0.05), (0, 0.07)], 7, "leather_light", scale=(0.9, 1.3), rot=(0, 0, -sx * 0.3))
        P.box((0.14, 0.02, 0.06), (0, 0.04, 0), "leather", rot=(0, 0, -sx * 0.3))  # the strap over it
    H = c.part("Head")
    face(H, "skin", "dark", mouth="dark")
    H.lathe([(0.17, 0.11), (0.14, 0.15), (0.09, 0.24), (0, 0.27)], 8, "iron")  # kettle hat
    H.lathe([(0.26, 0.1), (0.25, 0.125)], 8, "iron_dark")  # its wide brim
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        fist(hand, "leather", 0.11, sx, knuckles="leather_light")
    W = c.part("Weapon")
    sword(W, "steel", "wood", "leather", 0.8, 0.06)
    return c


def woodcutter():
    wool = (0.3, 0.4, 0.22)
    leather = (0.38, 0.24, 0.12)
    skin = (0.82, 0.6, 0.48)
    c = Char("woodcutter", {"tint_wool": wool, "tint_wool_dark": shade(wool, -0.3), "leather": leather,
                            "leather_light": shade(leather, 0.12), "skin": skin, "dark": (0.05, 0.03, 0.02),
                            "beard": (0.55, 0.3, 0.12), "cap": (0.6, 0.15, 0.1), "fur": (0.5, 0.42, 0.32),
                            "wood": (0.42, 0.3, 0.18), "iron": (0.45, 0.45, 0.47), "edge": (0.78, 0.78, 0.8),
                            "patch": (0.62, 0.5, 0.3), "chip": (0.85, 0.72, 0.5)})
    T = c.part("Torso")
    # a thick wool tunic, barrel-chested, with a fur collar and a rope belt
    T.lathe([(0.29, -0.36), (0.32, -0.15), (0.33, 0.1), (0.29, 0.28), (0.18, 0.36)], 8, "tint_wool", phase=TAU / 16)
    T.lathe([(0.17, 0.27), (0.22, 0.32), (0.16, 0.4)], 8, "fur")
    T.box((0.6, 0.06, 0.52), (0, -0.24, 0), "leather", chamfer=0.3)
    T.box((0.07, 0.07, 0.03), (0.1, -0.24, 0.27), "leather_light")
    for sx in (-1, 1):  # leather braces over the shoulders, buttoned at the belt
        T.box((0.05, 0.62, 0.025), (sx * 0.12, 0.02, 0.3 - 0.01), "leather", rot=(0, 0, sx * 0.08))
        T.sphere(0.018, (sx * 0.13, -0.19, 0.32), "iron", segs=5, rings=2)
    T.box((0.1, 0.09, 0.01), (-0.04, 0.05, 0.305), "patch", rot=(0, 0, 0.15))  # a patch, sewn on crooked
    for k in range(4):
        T.box((0.022, 0.006, 0.006), (-0.08 + k * 0.026, 0.05 + (k % 2) * 0.04 - 0.02, 0.312), "tint_wool_dark")  # its stitches
    for k, (x, y) in enumerate([(0.15, 0.12), (-0.18, -0.05), (0.06, -0.12), (0.2, -0.02)]):
        T.box((0.025, 0.012, 0.008), (x, y, 0.3), "chip", rot=(0, 0, k * 0.9))  # wood chips caught in the wool
    # a hatchet hung at the belt
    T.lathe([(0.016, -0.42), (0.016, -0.2)], 6, "wood", pos=(-0.22, 0, 0.24), rot=(0, 0, 0.2))
    T.poly([(0, 0), (0.07, -0.02), (0.08, 0.05), (0, 0.05)], 0.018, "iron", pos=(-0.2, -0.24, 0.24), rot=(0, 0, 0.2))
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.3, 0.22, 0))
        P.lathe([(0.11, -0.04), (0.14, 0.0), (0.11, 0.05), (0, 0.07)], 7, "fur", scale=(0.9, 1.2), rot=(0, 0, -sx * 0.3))
    H = c.part("Head")
    face(H, "skin", "dark", mouth="dark")
    # a knitted cap with a slumped point
    H.lathe([(0.17, 0.1), (0.17, 0.16), (0.13, 0.24), (0.06, 0.29), (0, 0.3)], 8, "cap")
    H.lathe([(0.18, 0.08), (0.18, 0.13)], 8, "fur")
    H.box((0.08, 0.14, 0.08), (0.08, 0.28, -0.04), "cap", chamfer=0.3, rot=(0, 0, -0.9))
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        fist(hand, "leather", 0.12, sx, knuckles="leather_light")
    W = c.part("Weapon")
    # a felling axe: long haft, a narrow wedge of a head
    W.lathe([(0.032, -0.12), (0.03, 0.9)], 6, "wood")
    W.poly([(0, -0.08), (0.14, -0.13), (0.24, -0.12), (0.26, 0.04), (0.24, 0.14), (0.12, 0.1), (0, 0.08)], 0.04, "iron", pos=(0.0, 0.84, 0))
    W.poly([(0.22, -0.12), (0.26, -0.12), (0.28, 0.04), (0.26, 0.15), (0.23, 0.14), (0.25, 0.04)], 0.048, "edge", pos=(0.0, 0.84, 0))
    W.box((0.08, 0.1, 0.08), (0, 0.84, 0), "iron", chamfer=0.3)
    return c


def knight(slug="knight", tint=(0.6, 0.62, 0.68), cloth=(0.55, 0.12, 0.1), crest=False, gilded=False):
    steel = tint
    c = Char(slug, {"tint_steel": steel, "tint_steel_light": shade(steel, 0.12), "steel_dark": shade(steel, -0.25),
                    "cloth": cloth, "dark": (0.01, 0.01, 0.01), "gold": (0.95, 0.75, 0.2),
                    "blade": (0.82, 0.84, 0.9), "wood": (0.35, 0.3, 0.2), "leather": (0.3, 0.2, 0.12), "cream": (0.88, 0.84, 0.72)})
    T = c.part("Torso")
    # a breastplate with a chest and a waist, over a plackart of lames
    T.lathe([(0.25, -0.36), (0.3, -0.2), (0.33, 0.02), (0.31, 0.2), (0.22, 0.33), (0.15, 0.38)], 8, "tint_steel", scale=(1, 0.8), phase=TAU / 16)
    for k in range(3):
        T.lathe([(0.3 - k * 0.01, -0.36 + k * 0.06), (0.32 - k * 0.01, -0.33 + k * 0.06)], 8, "steel_dark", scale=(1, 0.8), phase=TAU / 16)
    T.lathe([(0.14, 0.34), (0.17, 0.44)], 8, "steel_dark")  # gorget
    # a tabard with a dagged hem, a cream cross on it, gold trim, and a sword belt over it
    hem = [(-0.16 + k * 0.04, -0.32 - (0.03 if k % 2 else 0.0)) for k in range(9)]
    T.poly(hem + [(0.16, 0.18), (0, 0.22), (-0.16, 0.18)], 0.025, "cloth", pos=(0, 0, 0.27))
    if not gilded:
        T.box((0.05, 0.4, 0.01), (0, -0.04, 0.287), "cream")  # the cross
        T.box((0.24, 0.05, 0.01), (0, 0.04, 0.287), "cream")
        for sx in (-1, 1):
            T.box((0.012, 0.5, 0.012), (sx * 0.155, -0.07, 0.285), "gold")  # trim down the edges
    T.box((0.5, 0.05, 0.36), (0, -0.2, 0.0), "leather", chamfer=0.3)  # sword belt
    T.box((0.06, 0.06, 0.02), (0.05, -0.2, 0.29), "gold" if gilded else "steel_dark", chamfer=0.3)
    for k in range(4):  # rivets along the breastplate's edge
        T.sphere(0.012, ((-1) ** k * 0.24, 0.16 - (k // 2) * 0.22, 0.2), "steel_dark", segs=5, rings=2)
    if gilded:
        T.lathe([(0.0, 0.0), (0.09, 0.0), (0.0, 0.0)], 8, "gold", pos=(0, 0.04, 0.29), rot=(math.pi / 2, 0, 0), phase=0)
        for k in range(8):
            a = k * TAU / 8
            T.box((0.02, 0.07, 0.015), (math.sin(a) * 0.1, 0.04 + math.cos(a) * 0.1, 0.29), "gold", rot=(0, 0, -a))
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.33, 0.22, 0))
        if gilded:
            P.lathe([(0.15, -0.04, 0.88), (0.16, 0.0, 0.88), (0.12, 0.08, 0.88), (0, 0.11)], 10, "tint_steel_light", scale=(1, 1.15), rot=(0, 0, -sx * 0.35))
        else:
            P.lathe([(0.15, -0.04), (0.16, 0.0), (0.12, 0.08), (0, 0.11)], 8, "tint_steel_light", scale=(1, 1.15), rot=(0, 0, -sx * 0.35))
        P.lathe([(0.17, -0.07), (0.17, -0.04)], 8, "steel_dark", scale=(1, 1.15), rot=(0, 0, -sx * 0.35))  # the rim
    H = c.part("Head")
    if gilded:
        # a sallet: a smooth skull swept back into a tail, with a visor
        H.lathe([(0.15, -0.14), (0.17, -0.02), (0.17, 0.12), (0.12, 0.2), (0, 0.24)], 8, "tint_steel_light", scale=(1, 1.2), phase=TAU / 16)
        H.poly([(-0.17, -0.04), (0.17, -0.04), (0.19, 0.06), (0.1, 0.1), (-0.1, 0.1), (-0.19, 0.06)], 0.08, "tint_steel", pos=(0, 0, 0.14))
        eye_slit(H, "dark", 0.26, 0.0, 0.185)
        H.poly([(0, 0), (0.3, 0.1), (0.34, 0.2), (0.14, 0.14), (0.05, 0.09)], 0.03, "cloth", pos=(0, 0.2, -0.05), rot=(0, -math.pi / 2, 0))
    else:
        # the great helm: a flat-topped bucket with a cross of reinforcing bands
        H.lathe([(0.16, -0.18), (0.165, 0.12), (0.15, 0.2), (0.08, 0.24), (0, 0.25)], 8, "tint_steel_light", phase=TAU / 16)
        eye_slit(H, "dark", 0.24, 0.03, 0.165)
        H.box((0.03, 0.14, 0.02), (0, -0.07, 0.165), "dark")
        H.box((0.2, 0.025, 0.02), (0, -0.08, 0.165), "steel_dark")
        H.box((0.025, 0.4, 0.02), (0, 0.0, 0.165), "steel_dark")
        H.poly([(0, 0), (0.28, 0.12), (0.26, 0.3), (0.06, 0.24), (-0.1, 0.2)], 0.04, "cloth", pos=(0, 0.22, -0.02), rot=(0, -math.pi / 2, 0))
    if crest:
        crown(H, "gold", 0.15, 0.24)
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        gauntlet(hand, "tint_steel", "steel_dark", 0.12, sx)
    W = c.part("Weapon")
    sword(W, "blade", "gold" if gilded else "wood", "leather", 0.85, 0.06)
    return c


def brute():
    skin = (0.75, 0.55, 0.42)
    fur = (0.13, 0.11, 0.1)  # near-black fur, and blue woad on the skin: he reads against brown stone
    iron = (0.3, 0.3, 0.33)
    c = Char("brute", {"tint_skin": skin, "tint_skin_dark": shade(skin, -0.15), "fur": fur, "fur_light": shade(fur, 0.1),
                       "iron": iron, "iron_light": shade(iron, 0.2), "leather": (0.3, 0.2, 0.1), "dark": (0.05, 0.03, 0.02),
                       "brow": (0.2, 0.12, 0.08), "wood": (0.35, 0.25, 0.15), "iron_dark": (0.2, 0.2, 0.22),
                       "scar": (0.55, 0.32, 0.26), "leather_light": (0.42, 0.28, 0.15), "woad": (0.18, 0.32, 0.72)})
    T = c.part("Torso")
    # a barrel chest, two slabs of pectoral, a gut, old scars
    T.lathe([(0.34, -0.38), (0.4, -0.15), (0.42, 0.1), (0.38, 0.28), (0.2, 0.36)], 8, "tint_skin", scale=(1, 0.6), phase=TAU / 16)
    for sx in (-1, 1):
        T.box((0.26, 0.2, 0.08), (sx * 0.15, 0.08, 0.2), "tint_skin", chamfer=0.5, taper=(0.8, 0.5))
    T.box((0.02, 0.2, 0.02), (0, 0.05, 0.24), "tint_skin_dark")
    T.box((0.16, 0.012, 0.01), (0.12, 0.14, 0.245), "scar", rot=(0, 0, 0.5))
    T.box((0.1, 0.012, 0.01), (-0.17, 0.0, 0.245), "scar", rot=(0, 0, -0.3))
    T.box((0.3, 0.12, 0.06), (0, -0.16, 0.22), "tint_skin_dark", chamfer=0.6, taper=(0.9, 0.9))  # the gut
    for sx in (-1, 1):  # woad: war paint in stripes over the chest and down the arms
        for k in range(3):
            T.box((0.11, 0.022, 0.01), (sx * 0.2, 0.17 - k * 0.05, 0.24 - k * 0.005), "woad", rot=(0, 0, sx * 0.35))
    T.box((0.022, 0.24, 0.01), (0, -0.05, 0.25), "woad")
    # a fur mantle in clumps over the shoulders and round the neck, not one slab
    rnd = random.Random(11)
    for k in range(14):
        ang = -math.pi * 0.95 + k * (math.pi * 1.9 / 13)
        r = 0.36 + rnd.uniform(-0.03, 0.03)
        T.sphere(0.11 + rnd.uniform(-0.02, 0.02), (math.sin(ang) * r, 0.33 + rnd.uniform(-0.02, 0.04), math.cos(ang) * r * 0.55 - 0.05),
                 "fur" if k % 3 else "fur_light", segs=6, rings=3, scale=(1.2, 0.8, 1.0))
    # a harness: two leather straps crossing the chest to an iron ring, a chain hanging off it
    for sx in (-1, 1):
        T.box((0.08, 0.66, 0.025), (sx * 0.1, 0.02, 0.255), "leather", rot=(0, 0, sx * 0.62))
        T.box((0.025, 0.66, 0.03), (sx * 0.1, 0.02, 0.26), "leather_light", rot=(0, 0, sx * 0.62))
    T.lathe([(0.06, -0.012), (0.075, 0.0), (0.06, 0.012)], 10, "iron_light", pos=(0, 0.05, 0.27), rot=(math.pi / 2, 0, 0))
    for k in range(4):
        T.box((0.025, 0.04, 0.02), (0.02 + k * 0.012, -0.02 - k * 0.04, 0.28), "iron" if k % 2 else "iron_light", rot=(0, 0, 0.25))
    T.lathe([(0.17, 0.36), (0.19, 0.45)], 8, "iron")  # collar
    T.box((0.72, 0.14, 0.38), (0, -0.34, 0), "leather", chamfer=0.2)  # a wide belt...
    for k in range(7):
        T.sphere(0.018, (-0.27 + k * 0.09, -0.34, 0.2), "iron_light", segs=5, rings=2)  # ...studded
    T.box((0.14, 0.13, 0.03), (0, -0.34, 0.21), "iron", chamfer=0.3)  # its buckle
    T.box((0.08, 0.06, 0.02), (0, -0.34, 0.23), "dark")
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.44, 0.3, 0))
        P.lathe([(0.17, -0.05), (0.19, 0.0), (0.16, 0.06), (0, 0.09)], 8, "iron", scale=(0.9, 1.2), rot=(0, 0, -sx * 0.25))
        for k in range(3):
            P.loft([[(-0.03, 0.05, -0.12 + k * 0.12 - 0.03), (0.03, 0.05, -0.12 + k * 0.12 - 0.03),
                     (0.03, 0.05, -0.12 + k * 0.12 + 0.03), (-0.03, 0.05, -0.12 + k * 0.12 + 0.03)],
                    (sx * 0.04, 0.2, -0.12 + k * 0.12)], "iron_light")
    H = c.part("Head")
    face(H, "tint_skin", "dark", w=0.3, h=0.3, nose=True, eyes=True, brow=False)
    H.box((0.3, 0.14, 0.26), (0, -0.12, 0.03), "tint_skin_dark", chamfer=0.4, taper=(1.1, 1.0))  # a heavy jaw
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        fist(hand, "tint_skin", 0.14, sx, knuckles="tint_skin_dark")
        hand.lathe([(0.085, -0.14), (0.08, -0.08)], 8, "leather")  # a wrist wrap, below the hand
    W = c.part("Weapon")
    W.lathe([(0.035, -0.15), (0.035, 0.85)], 6, "wood")
    W.box((0.32, 0.26, 0.26), (0, 0.92, 0), "iron", chamfer=0.25)  # the maul's head
    W.box((0.36, 0.05, 0.3), (0, 0.82, 0), "iron_dark")
    W.box((0.36, 0.05, 0.3), (0, 1.02, 0), "iron_dark")
    return c


def duelist():
    coat = (0.45, 0.15, 0.3)
    cream = (0.85, 0.8, 0.7)
    c = Char("duelist", {"tint_coat": coat, "tint_coat_light": shade(coat, 0.15), "coat_dark": shade(coat, -0.3), "cream": cream,
                         "gold": (0.9, 0.8, 0.3), "sash": (0.2, 0.12, 0.08), "skin": (0.82, 0.66, 0.54), "dark": (0.05, 0.05, 0.05),
                         "hair": (0.3, 0.15, 0.1), "feather": (0.9, 0.85, 0.7), "blade": (0.85, 0.87, 0.92), "guard": (0.75, 0.6, 0.25)})
    T = c.part("Torso")
    # a slim coat nipped at the waist and flaring into a skirt
    T.lathe([(0.26, -0.38), (0.19, -0.2), (0.17, -0.05), (0.2, 0.15), (0.19, 0.3), (0.12, 0.38)], 8, "tint_coat", scale=(1, 0.85), phase=TAU / 16)
    T.box((0.04, 0.5, 0.02), (0, 0.02, 0.18), "cream")
    for k in range(4):
        T.sphere(0.016, (0, -0.16 + k * 0.12, 0.19), "gold", segs=5, rings=2)
    T.box((0.38, 0.06, 0.3), (0, -0.24, 0), "sash", rot=(0, 0, 0.1), chamfer=0.3)
    T.lathe([(0.1, 0.34), (0.12, 0.42)], 8, "cream")  # a ruff at the collar
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.25, 0.2, 0))
        P.sphere(0.11, (0, 0, 0), "tint_coat_light", segs=8, rings=4, scale=(1, 0.95, 1))  # a puffed sleeve
        P.box((0.02, 0.2, 0.02), (0, 0, 0.1), "coat_dark")
    H = c.part("Head")
    face(H, "skin", "dark", w=0.2, h=0.28, mouth=None)
    H.lathe([(0.3, 0.125), (0.31, 0.145)], 10, "coat_dark")  # hat brim
    H.lathe([(0.13, 0.14), (0.12, 0.26), (0.13, 0.3), (0, 0.31)], 8, "coat_dark")
    H.poly([(0, 0), (0.24, 0.18), (0.3, 0.34), (0.12, 0.3), (0.02, 0.1)], 0.02, "feather", pos=(0.1, 0.24, -0.04), rot=(0, -0.3, 0))
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        fist(hand, "cream", 0.09, sx)
        hand.lathe([(0.06, -0.1), (0.045, -0.045)], 6, "tint_coat")  # cuff, at the wrist
    W = c.part("Weapon")
    W.loft([[(-0.014, 0.12, 0), (0, 0.12, 0.007), (0.014, 0.12, 0), (0, 0.12, -0.007)],
            [(-0.01, 0.9, 0), (0, 0.9, 0.005), (0.01, 0.9, 0), (0, 0.9, -0.005)], (0, 1.08, 0)], "blade")
    W.lathe([(0.02, 0.06), (0.07, 0.1), (0.075, 0.12), (0.0, 0.12)], 8, "guard")  # cup guard
    W.box((0.14, 0.012, 0.012), (0, 0.11, 0), "guard")
    W.lathe([(0.017, -0.1), (0.017, 0.06)], 6, "sash")
    W.sphere(0.022, (0, -0.12, 0), "guard", segs=6, rings=3)
    return c


def rusted():
    rust = (0.42, 0.26, 0.14)
    rot = (0.3, 0.33, 0.18)
    c = Char("the_rusted", {"rust": rust, "rust_light": shade(rust, 0.1), "rust_dark": shade(rust, -0.15), "rot": rot,
                            "hole": (0.03, 0.02, 0.02), "glow_eye": (0.5, 1.0, 0.3), "strap": (0.2, 0.14, 0.08),
                            "glow_rot": (0.22, 0.5, 0.12)})
    rng = random.Random(7)
    T = c.part("Torso")
    # plate that has gone soft: dented all over, holed through, stained
    T.lathe([(0.24, -0.36), (0.29, -0.15), (0.3, 0.1), (0.25, 0.3), (0.14, 0.36)], 7, "rust", scale=(1, 0.85), jitter=rng, phase=TAU / 14)
    for k in range(3):
        T.box((0.08 + k * 0.02, 0.06, 0.06), (-0.1 + k * 0.1, -0.12 + k * 0.09, 0.26), "hole", rot=(0, 0, rng.uniform(-0.5, 0.5)))
    T.box((0.26, 0.12, 0.02), (0.05, 0.1, 0.28), "rot", rot=(0, 0, 0.2))
    for k in range(7):  # green corrosion weeping in thin runs down the plate: it reads against warm stone
        x = -0.18 + k * 0.06
        T.box((0.012, 0.03 + 0.025 * (k % 3), 0.008), (x, 0.06 - 0.07 * (k % 4), 0.285 - 0.02 * abs(x)), "glow_rot", rot=(0, 0, rng.uniform(-0.15, 0.15)))
    T.lathe([(0.12, 0.3), (0.14, 0.4)], 7, "rust_dark", jitter=rng)
    T.box((0.5, 0.07, 0.4), (0, -0.28, 0), "strap", rot=(0, 0, 0.08), chamfer=0.2)
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.32, 0.2 - (0.05 if sx > 0 else 0), 0))
        P.lathe([(0.13, -0.04), (0.15, 0.0), (0.11, 0.06), (0, 0.08)], 7, "rust_dark", scale=(1, 1.2), rot=(0.3 * sx, 0, -0.4 * sx), jitter=rng)
        P.box((0.03, 0.14, 0.02), (sx * -0.05, -0.02, 0.1), "strap", rot=(0, 0, 0.4 * sx))
    H = c.part("Head")
    # a helm sitting crooked, with a dent in it and something alight in the slit
    H.lathe([(0.15, -0.2), (0.16, 0.0), (0.16, 0.12), (0.12, 0.19), (0, 0.22)], 7, "rust_light", pos=(0.02, 0, 0), rot=(0, 0, 0.2), jitter=rng, phase=TAU / 14)
    H.box((0.2, 0.03, 0.02), (0.02, 0.03, 0.155), "hole", rot=(0, 0, 0.2))
    H.box((0.04, 0.02, 0.012), (-0.04, 0.035, 0.162), "glow_eye", rot=(0, 0, 0.2))
    H.box((0.12, 0.06, 0.05), (-0.09, -0.12, 0.1), "rot", rot=(0, 0, 0.5))
    H.box((0.05, 0.05, 0.05), (0.08, 0.09, 0.11), "hole")  # a hole through the helm
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        fist(hand, "rust_dark", 0.12, sx, knuckles="rust")
        hand.box((0.05, 0.05, 0.05), (sx * 0.03, -0.02, 0.06), "hole")
    W = c.part("Weapon")
    # the blade is eaten through: a notched edge, a bent tip
    y0 = 0.1
    rings = []
    for k in range(6):
        y = y0 + k * 0.14
        w = 0.055 * (1 - k * 0.1) * (0.7 if k % 2 else 1.0)
        rings.append([(-w, y, 0), (0, y, 0.012), (w, y, 0), (0, y, -0.012)])
    rings.append((0.03, y0 + 0.84, 0))
    W.loft(rings, "rust")
    W.box((0.06, 0.2, 0.025), (0.02, 0.55, 0), "rust_dark", rot=(0, 0, 0.2))
    W.box((0.22, 0.035, 0.05), (0, 0.09, 0), "rust_dark", rot=(0, 0, -0.15))
    W.lathe([(0.02, -0.12), (0.02, 0.08)], 5, "strap")
    return c


def zealot():
    robe = (0.72, 0.68, 0.6)  # ash-white robes: the fire is in the trim and the brazier, and it reads against warm rooms
    wrap = (0.75, 0.3, 0.1)
    c = Char("pyre_zealot", {"tint_robe": robe, "tint_robe_dark": shade(robe, -0.3), "robe_shadow": shade(robe, -0.2), "wrap": wrap,
                             "wrap_dark": shade(wrap, -0.25), "bead": (0.25, 0.15, 0.1), "brass": (0.8, 0.6, 0.25), "skin": (0.6, 0.45, 0.35),
                             "dark": (0.05, 0.03, 0.02), "mouth": (0.4, 0.15, 0.1), "wood": (0.3, 0.22, 0.12), "iron": (0.25, 0.25, 0.27),
                             "iron_dark": (0.2, 0.2, 0.2), "glow_coals": (1.0, 0.45, 0.1)})
    T = c.part("Torso")
    # robes: heavy folds hang from the shoulders and flare at the hem
    T.lathe([(0.36, -0.4, 0.9), (0.3, -0.2, 0.92), (0.26, 0.0, 0.94), (0.25, 0.2, 0.96), (0.17, 0.34), (0.1, 0.38)], 10, "tint_robe", phase=TAU / 20)
    T.box((0.06, 0.6, 0.02), (0, -0.06, 0.28), "tint_robe_dark")
    T.box((0.5, 0.05, 0.4), (0, -0.2, 0), "wrap_dark", chamfer=0.3)  # a rope belt
    for k in range(7):
        x = -0.12 + k * 0.04
        T.sphere(0.02, (x, 0.24 - abs(k - 3) * 0.035, 0.26), "bead", segs=5, rings=2)
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.26, 0.26, 0))
        P.lathe([(0.11, -0.05), (0.13, 0.0), (0.1, 0.05), (0, 0.07)], 7, "robe_shadow", scale=(1, 1.3), rot=(0, 0, -sx * 0.5))  # a padded shoulder
        P.box((0.05, 0.03, 0.05), (sx * 0.03, 0.055, 0.08), "brass", chamfer=0.4, rot=(0, 0, -sx * 0.5))
    H = c.part("Head")
    # a deep hood with the face sunk inside, mouth open mid-hymn
    H.lathe([(0.19, -0.18), (0.22, -0.02), (0.2, 0.12), (0.14, 0.22), (0.05, 0.3), (0, 0.34)], 8, "tint_robe_dark", pos=(0, 0, -0.1), scale=(1, 0.8), phase=TAU / 16)
    H.lathe([(0.16, -0.14), (0.18, 0.0), (0.16, 0.14), (0.0, 0.14)], 8, "dark", pos=(0, 0, 0.04), scale=(0.9, 0.3), phase=TAU / 16)
    H.box((0.16, 0.2, 0.06), (0, -0.02, 0.1), "skin", chamfer=0.3)
    for sx in (-1, 1):
        H.box((0.04, 0.02, 0.012), (sx * 0.045, 0.03, 0.135), "dark")
    H.box((0.05, 0.035, 0.012), (0, -0.06, 0.135), "mouth")
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        fist(hand, "wrap", 0.11, sx, knuckles="wrap_dark")
        hand.lathe([(0.05, -0.075), (0.052, -0.06)], 6, "wrap_dark")  # rags wound round the wrist
        hand.lathe([(0.048, -0.045), (0.05, -0.03)], 6, "wrap_dark")
    W = c.part("Weapon")
    W.lathe([(0.025, -0.12), (0.025, 0.55)], 6, "wood")
    for k in range(5):
        W.box((0.025, 0.06, 0.012 if k % 2 else 0.025), (0, 0.58 + k * 0.065, 0), "iron", rot=(0, k * 0.8, 0))
    W.lathe([(0.04, 0.86), (0.12, 0.9), (0.13, 1.0), (0.1, 1.04)], 8, "iron_dark")  # the brazier
    W.lathe([(0.0, 1.0), (0.09, 1.02), (0.06, 1.1), (0, 1.12)], 8, "glow_coals")  # heaped coals
    for k in range(4):
        a = k * TAU / 4
        W.box((0.02, 0.1, 0.02), (math.sin(a) * 0.1, 1.08, math.cos(a) * 0.1), "iron", rot=(math.cos(a) * 0.5, 0, -math.sin(a) * 0.5))
    return c


def wraith(slug="wraith", king=False):
    dark = (0.06, 0.05, 0.07)
    bone = (0.7, 0.68, 0.62)
    c = Char(slug, {"dark": dark, "dark_light": shade(dark, 0.12), "tint_rag": (0.25, 0.22, 0.3), "bone": bone, "bone_dark": shade(bone, -0.2),
                    "void": (0.02, 0.02, 0.02), "glow_eye": (1.0, 0.25, 0.1), "gold": (0.95, 0.75, 0.2),
                    "glow_blade": (0.5, 0.7, 1.0), "hilt": (0.15, 0.15, 0.18), "violet": (0.32, 0.16, 0.45), "chain": (0.45, 0.42, 0.38)})
    T = c.part("Torso")
    # a cloak and nothing in it: it narrows to a ragged hem that trails to a point
    T.lathe([(0.0, -0.75), (0.12, -0.5, 0.6), (0.3, -0.25, 0.85), (0.38, 0.05, 0.92), (0.36, 0.25), (0.2, 0.38)], 10, "dark",
            pos=(0, 0, -0.05), phase=TAU / 20)
    C = c.part("Torso_Cowl")  # the cowl's shoulders, its own piece: it is all the wraith has for a body
    C.lathe([(0.3, 0.24), (0.28, 0.3), (0.1, 0.36)], 8, "dark_light", pos=(0, 0, -0.05))
    for k in range(5):
        a = -0.6 + k * 0.3
        C.box((0.02, 0.1, 0.02), (math.sin(a) * 0.14, 0.26 - abs(k - 2) * 0.03, math.cos(a) * 0.14 - 0.05), "bone_dark", rot=(0, 0, -a * 0.3))  # a collar of finger bones
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.34, 0.26, 0.02))
        P.lathe([(0.11, -0.08, 0.6), (0.13, -0.02), (0.1, 0.04), (0, 0.06)], 8, "tint_rag", scale=(0.8, 1.2), rot=(0, 0, -sx * 0.3))
    H = c.part("Head")
    # a hood with no face in it: a black void and two points of fire
    H.lathe([(0.17, -0.22), (0.21, -0.05), (0.2, 0.1), (0.15, 0.2), (0.06, 0.3), (0, 0.36)], 8, "dark", pos=(0, 0, -0.09), scale=(1, 0.8), phase=TAU / 16)
    H.lathe([(0.15, -0.15), (0.17, 0.0), (0.14, 0.15), (0, 0.17)], 8, "void", scale=(0.9, 0.35), pos=(0, 0, 0.06), phase=TAU / 16)
    for sx in (-1, 1):
        H.box((0.045, 0.022, 0.02), (sx * 0.05, 0.02, 0.13), "glow_eye")
    if king:
        crown(H, "gold", 0.17, 0.24)
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        open_hand(hand, "bone", 0.11, sx, finger_mat="bone_dark", length=0.12)
        # the sleeve: a long tattered cone hanging back from the wrist, ragged at the cuff
        hand.lathe([(0.055, -0.04, 0.6), (0.075, 0.04), (0.08, 0.2), (0.06, 0.32)], 8, "dark", rot=(-0.25, 0, 0))
    # tatters hanging from the cloak's hem and the rag on its shoulders
    rnd = random.Random(23 if king else 5)
    for k in range(9):
        a = -1.2 + k * 0.3
        T.box((0.05, 0.16 + rnd.uniform(0, 0.12), 0.012), (math.sin(a) * 0.3, -0.38 - rnd.uniform(0, 0.06), math.cos(a) * 0.3 - 0.05), "tint_rag", rot=(0, a, rnd.uniform(-0.2, 0.2)))
    if king:
        # a king's mantle: violet over the shoulders, a gold-linked chain of office across the chest
        T.lathe([(0.37, 0.12, 0.9), (0.39, 0.24), (0.24, 0.36)], 10, "violet", pos=(0, 0, -0.04), phase=TAU / 20)
        for k in range(9):
            a = -0.9 + k * 0.225
            T.sphere(0.026, (math.sin(a) * 0.3, 0.2 - 0.16 * math.cos(a * 1.4), math.cos(a) * 0.3 + 0.05), "gold" if k % 2 else "chain", segs=5, rings=3)
        T.lathe([(0.045, -0.01), (0.05, 0.0), (0.045, 0.01)], 8, "gold", pos=(0, 0.03, 0.31), rot=(math.pi / 2, 0, 0))  # its pendant
    if king:
        W = c.part("Weapon")
        sword(W, "glow_blade", "hilt", "hilt", 0.85, 0.06)
    return c


def castellan():
    steel = (0.55, 0.58, 0.65)
    cloth = (0.15, 0.25, 0.55)
    c = Char("castellan", {"tint_steel": steel, "tint_steel_light": shade(steel, 0.12), "steel_dark": shade(steel, -0.25),
                           "cloth": cloth, "dark": (0.01, 0.01, 0.01), "gold": (0.95, 0.75, 0.2), "blade": (0.82, 0.84, 0.9),
                           "leather": (0.3, 0.2, 0.12), "shield": shade(steel, 0.05), "shield_rim": shade(steel, -0.3),
                           "field": (0.16, 0.24, 0.5)})
    T = c.part("Torso")
    # the heaviest plate there is: a deep breastplate, a tall gorget, a tabard with the keep on it
    T.lathe([(0.28, -0.36), (0.33, -0.15), (0.35, 0.05), (0.32, 0.22), (0.24, 0.34), (0.17, 0.4)], 8, "tint_steel", scale=(1, 0.8), phase=TAU / 16)
    T.lathe([(0.33, -0.36), (0.35, -0.3)], 8, "steel_dark", scale=(1, 0.8), phase=TAU / 16)
    T.lathe([(0.16, 0.34), (0.19, 0.48)], 8, "steel_dark")
    T.poly([(-0.15, -0.3), (0.15, -0.3), (0.15, 0.2), (-0.15, 0.2)], 0.025, "cloth", pos=(0, 0, 0.29))
    T.poly([(-0.06, -0.06), (0.06, -0.06), (0.06, 0.03), (0.03, 0.03), (0.03, 0.06), (0.0, 0.06), (0.0, 0.03),
            (-0.03, 0.03), (-0.03, 0.06), (-0.06, 0.06)], 0.015, "gold", pos=(0, 0.0, 0.31))  # a tower
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.36, 0.22, 0))
        P.lathe([(0.18, -0.06), (0.19, 0.0), (0.14, 0.08), (0, 0.11)], 8, "tint_steel_light", scale=(1, 1.15), rot=(0, 0, -sx * 0.3))
        P.lathe([(0.2, 0.04), (0.21, 0.07), (0.16, 0.13), (0, 0.15)], 8, "tint_steel_light", scale=(1, 1.15), rot=(0, 0, -sx * 0.3))  # a second plate over it
        P.lathe([(0.2, -0.1), (0.2, -0.06)], 8, "steel_dark", scale=(1, 1.15), rot=(0, 0, -sx * 0.3))
    H = c.part("Head")
    H.lathe([(0.17, -0.2), (0.175, 0.1), (0.16, 0.2), (0.09, 0.26), (0, 0.27)], 8, "tint_steel_light", phase=TAU / 16)
    H.box((0.26, 0.03, 0.02), (0, 0.03, 0.175), "dark")
    for k in range(3):
        H.box((0.015, 0.1, 0.02), (-0.05 + k * 0.05, -0.08, 0.175), "dark")
    H.box((0.36, 0.03, 0.03), (0, 0.045, 0.17), "steel_dark")  # the visor's brow
    crown(H, "gold", 0.16, 0.26)
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        gauntlet(hand, "tint_steel", "steel_dark", 0.13, sx)
    W = c.part("Weapon")
    sword(W, "blade", "steel_dark", "leather", 0.85, 0.06)
    S = c.part("Shield")
    # a tower shield, held on the left arm, with a rim, a boss, and the keep in gold
    outline = [(-0.22, -0.36), (0.22, -0.36), (0.24, 0.18), (0.18, 0.32), (0, 0.36), (-0.18, 0.32), (-0.24, 0.18)]
    S.poly(outline, 0.04, "shield", pos=(0.05, 0.2, 0.08))
    S.poly([(x * 1.08, y * 1.06) for x, y in outline], 0.02, "shield_rim", pos=(0.05, 0.2, 0.07))
    S.lathe([(0.0, 0.0), (0.07, 0.0), (0.03, 0.05), (0, 0.06)], 8, "steel_dark", pos=(0.05, 0.15, 0.1), rot=(math.pi / 2, 0, 0))
    # the keep in gold on a blue field: a tower with three merlons and a dark gate
    S.poly([(x * 0.86, y * 0.88) for x, y in outline], 0.01, "field", pos=(0.05, 0.2, 0.105))
    S.box((0.16, 0.2, 0.012), (0.05, 0.36, 0.115), "gold")
    for k in range(3):
        S.box((0.04, 0.05, 0.012), (0.05 - 0.06 + k * 0.06, 0.485, 0.115), "gold")
    S.box((0.05, 0.08, 0.014), (0.05, 0.3, 0.118), "steel_dark")  # the gate
    return c


def headsman():
    skin = (0.7, 0.55, 0.45)
    leather = (0.25, 0.15, 0.08)
    c = Char("headsman", {"skin": skin, "skin_dark": shade(skin, -0.15), "leather": leather, "leather_light": shade(leather, 0.15),
                          "blood": (0.45, 0.1, 0.08), "hood": (0.06, 0.05, 0.05), "eyes": (0.6, 0.5, 0.4), "wood": (0.3, 0.2, 0.12),
                          "iron": (0.5, 0.5, 0.52), "edge": (0.8, 0.8, 0.82), "iron_dark": (0.3, 0.3, 0.32),
                          "hole": (0.02, 0.01, 0.01), "glow_eyes": (0.55, 0.4, 0.3)})
    T = c.part("Torso")
    # bare shoulders and a leather apron over a chest like a door
    T.lathe([(0.34, -0.36), (0.37, -0.1), (0.38, 0.15), (0.33, 0.3), (0.18, 0.36)], 8, "skin", scale=(1, 0.55), phase=TAU / 16)
    T.poly([(-0.22, -0.4), (0.22, -0.4), (0.24, 0.08), (0.12, 0.26), (-0.12, 0.26), (-0.24, 0.08)], 0.03, "leather", pos=(0, 0, 0.2))
    for k, (x, y, w, h, r) in enumerate([(0.06, 0.1, 0.07, 0.05, 0.3), (0.02, 0.04, 0.03, 0.12, 0.1), (0.11, 0.0, 0.025, 0.09, -0.1),
                                          (-0.05, 0.12, 0.04, 0.03, 0.6), (0.08, -0.08, 0.02, 0.07, 0.05), (-0.02, -0.04, 0.02, 0.05, -0.2)]):
        T.box((w, h, 0.012), (x, y, 0.225), "blood", rot=(0, 0, r))  # old blood, splashed and run down the apron
    T.box((0.5, 0.06, 0.36), (0, -0.3, 0.0), "leather_light", chamfer=0.3)  # belt
    T.box((0.08, 0.08, 0.02), (0, -0.3, 0.2), "iron")
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.24, 0.3, 0))
        P.box((0.1, 0.05, 0.4), (0, 0, 0), "leather_light", chamfer=0.3, rot=(0, 0, -sx * 0.2))  # the apron's straps
        P.box((0.05, 0.05, 0.05), (0, 0.02, 0.17), "iron", chamfer=0.4)  # buckled
    H = c.part("Head")
    # a black hood pulled over the whole head, with two holes and the eyes behind them
    H.lathe([(0.17, -0.2), (0.2, -0.05), (0.19, 0.12), (0.15, 0.22), (0, 0.28)], 8, "hood", phase=TAU / 16)
    H.box((0.3, 0.05, 0.3), (0, -0.19, 0.0), "hood")  # the hem, tucked into the collar
    for sx in (-1, 1):
        H.box((0.07, 0.05, 0.02), (sx * 0.06, 0.04, 0.17), "hole")  # the holes cut in the hood
        H.box((0.03, 0.022, 0.02), (sx * 0.06, 0.04, 0.178), "glow_eyes")  # and the eyes, catching the light
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        fist(hand, "skin", 0.15, sx, knuckles="skin_dark")
        hand.lathe([(0.085, -0.17), (0.075, -0.08)], 8, "leather")  # a bracer, on the wrist
    W = c.part("Weapon")
    W.lathe([(0.03, -0.15), (0.03, 1.0)], 6, "wood")
    W.poly([(0, -0.16), (0.12, -0.22), (0.26, -0.18), (0.34, -0.06), (0.36, 0.1), (0.3, 0.22), (0.16, 0.26), (0, 0.2)], 0.035, "iron",
           pos=(0.0, 0.95, 0))  # the crescent head
    W.poly([(0.26, -0.18), (0.34, -0.06), (0.36, 0.1), (0.3, 0.22), (0.28, 0.2), (0.33, 0.1), (0.31, -0.05), (0.25, -0.15)], 0.045, "edge",
           pos=(0.0, 0.95, 0))  # its edge, bright and thin
    W.box((0.1, 0.12, 0.1), (0, 0.95, 0), "iron_dark", chamfer=0.3)
    return c


def halberdier():
    """A pikeman of the guard: mail under a quartered tabard, a sallet with a visor slit,
    and a halberd taller than he is held in both hands."""
    tabard = (0.22, 0.32, 0.62)  # blue quartered with cream: it reads against the catacombs' brown
    c = Char("halberdier", {"tint_tabard": tabard, "tint_tabard_dark": (0.85, 0.8, 0.68), "mail": (0.42, 0.43, 0.45),
                            "mail_dark": (0.3, 0.31, 0.33), "steel": (0.62, 0.63, 0.66), "steel_dark": (0.4, 0.41, 0.44),
                            "dark": (0.03, 0.03, 0.03), "leather": (0.3, 0.2, 0.1), "wood": (0.35, 0.24, 0.13),
                            "edge": (0.85, 0.86, 0.9), "red": (0.55, 0.1, 0.08)})
    T = c.part("Torso")
    T.lathe([(0.27, -0.38), (0.28, -0.1), (0.27, 0.15), (0.22, 0.32), (0.14, 0.38)], 8, "mail", phase=TAU / 16)
    # the tabard: front and back panels, quartered, over the mail
    for z in (0.21, -0.21):
        T.box((0.42, 0.66, 0.025), (0, -0.05, z), "tint_tabard", taper=(0.85, 1))
        T.box((0.21, 0.33, 0.03), (-0.105, 0.11, z), "tint_tabard_dark")
        T.box((0.21, 0.33, 0.03), (0.105, -0.22, z), "tint_tabard_dark")
    T.box((0.52, 0.06, 0.46), (0, -0.28, 0), "leather", chamfer=0.3)
    T.lathe([(0.13, 0.32), (0.15, 0.42)], 8, "mail_dark")  # a mail collar
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.29, 0.24, 0))
        P.lathe([(0.12, -0.05), (0.14, 0.0), (0.11, 0.06), (0, 0.08)], 8, "steel", scale=(1, 1.1), rot=(0, 0, -sx * 0.35))
        P.box((0.02, 0.08, 0.2), (sx * 0.06, -0.03, 0), "steel_dark", rot=(0, 0, -sx * 0.35))  # a lame
    H = c.part("Head")
    # a sallet: a rounded bowl drawn out into a tail at the back, a visor with one slit
    H.lathe([(0.19, -0.1), (0.2, 0.04), (0.17, 0.16), (0.1, 0.24), (0, 0.26)], 10, "steel")
    H.box((0.24, 0.05, 0.16), (0, -0.12, -0.12), "steel", rot=(0.4, 0, 0))  # the tail
    H.box((0.36, 0.13, 0.08), (0, -0.02, 0.15), "steel_dark", chamfer=0.3)  # the visor
    H.box((0.28, 0.025, 0.02), (0, 0.01, 0.195), "dark")  # its slit
    H.box((0.02, 0.12, 0.02), (0, 0.22, 0.05), "red")  # a plume stub
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        gauntlet(hand, "steel", "steel_dark", 0.11, sx)
    W = c.part("Weapon")
    W.lathe([(0.025, -0.75), (0.025, 1.45)], 6, "wood")  # the haft: long, both hands on it
    W.lathe([(0.032, -0.78), (0.03, -0.7)], 6, "steel_dark")  # the butt cap
    W.poly([(0, -0.14), (0.2, -0.18), (0.3, -0.08), (0.32, 0.08), (0.24, 0.16), (0, 0.12)], 0.03, "steel", pos=(0.02, 1.3, 0))  # the axe blade
    W.poly([(0.3, -0.08), (0.32, 0.08), (0.3, 0.1), (0.29, -0.06)], 0.04, "edge", pos=(0.02, 1.3, 0))
    W.poly([(0, -0.04), (-0.16, 0.04), (-0.2, 0.12), (-0.12, 0.06), (0, 0.04)], 0.03, "steel_dark", pos=(-0.02, 1.32, 0))  # the hook
    W.loft([[(-0.03, 1.42, 0), (0, 1.42, 0.015), (0.03, 1.42, 0), (0, 1.42, -0.015)], (0, 1.78, 0)], "edge")  # the spike
    W.lathe([(0.04, 1.2), (0.035, 1.42)], 6, "steel_dark")  # the socket
    return c


def twinblade():
    """A sell-sword with two sabres: lean, quick, a scarf over the face and a leather jerkin,
    a curved blade in each hand."""
    jerkin = (0.45, 0.12, 0.18)  # maroon, with an ochre scarf: both read against the cistern's teal
    c = Char("twinblade", {"tint_jerkin": jerkin, "tint_jerkin_dark": shade(jerkin, -0.35), "leather": (0.32, 0.2, 0.1),
                           "leather_light": (0.45, 0.3, 0.16), "scarf": (0.85, 0.6, 0.15), "skin": (0.72, 0.55, 0.42),
                           "dark": (0.04, 0.03, 0.03), "hair": (0.12, 0.08, 0.06), "blade": (0.82, 0.84, 0.88),
                           "brass": (0.75, 0.6, 0.3), "grip": (0.15, 0.1, 0.08)})
    T = c.part("Torso")
    T.lathe([(0.24, -0.38), (0.21, -0.18), (0.22, 0.1), (0.21, 0.28), (0.13, 0.36)], 8, "tint_jerkin", scale=(1, 0.8), phase=TAU / 16)
    for k in range(5):
        T.box((0.3, 0.02, 0.02), (0, -0.25 + k * 0.12, 0.17), "tint_jerkin_dark")  # the jerkin's lacing
    T.box((0.06, 0.62, 0.32), (0.06, -0.02, 0), "leather", rot=(0, 0, 0.7))  # a baldric, both scabbards on it
    T.box((0.44, 0.05, 0.34), (0, -0.3, 0), "leather_light", chamfer=0.3)
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.24, 0.22, 0))
        P.lathe([(0.09, -0.04), (0.11, 0.0), (0.08, 0.05), (0, 0.06)], 7, "leather_light", rot=(0, 0, -sx * 0.4))
    H = c.part("Head")
    face(H, "skin", "dark", w=0.21, h=0.28, mouth=None, nose=False)
    H.lathe([(0.15, -0.14), (0.16, -0.02)], 8, "scarf", scale=(1, 1.05))  # the scarf over the mouth and nose
    H.box((0.07, 0.24, 0.03), (0.08, -0.2, -0.12), "scarf", rot=(0.5, 0, 0.2))  # its loose end
    H.lathe([(0.16, 0.06), (0.15, 0.16), (0.08, 0.24), (0, 0.25)], 8, "hair", jitter=__import__("random").Random(7))
    H.box((0.34, 0.03, 0.03), (0, 0.08, 0.0), "scarf")  # a headband
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        fist(hand, "leather", 0.09, sx, knuckles="leather_light")
        hand.lathe([(0.055, -0.1), (0.045, -0.045)], 6, "tint_jerkin_dark")  # a cuff, at the wrist
        # a sabre in each hand: the right one is the Weapon, the left hangs on the left hand
        B = c.part("Weapon") if sx > 0 else c.part("LeftHand_Sabre")
        blade = [(0.0, 0.1), (0.035, 0.1), (0.05, 0.4), (0.06, 0.62), (0.04, 0.8), (0.0, 0.88), (-0.01, 0.62), (-0.01, 0.3)]
        B.poly([(x * -sx if sx < 0 else x, y) for x, y in blade], 0.012, "blade")
        B.box((0.16, 0.025, 0.04), (0, 0.09, 0), "brass", chamfer=0.3)  # the guard
        B.lathe([(0.018, -0.08), (0.018, 0.08)], 6, "grip")
        B.sphere(0.02, (0, -0.09, 0), "brass", segs=6, rings=3)
    return c


def bonebreaker():
    """A man-at-arms gone to seed: a brigandine of riveted plates over a padded jack, a
    barbute with a T-slot, and a flanged mace."""
    jack = (0.45, 0.42, 0.38)
    c = Char("bonebreaker", {"tint_jack": jack, "tint_jack_dark": shade(jack, -0.3), "brig": (0.32, 0.12, 0.12),
                             "rivet": (0.75, 0.65, 0.4), "steel": (0.5, 0.5, 0.53), "steel_dark": (0.32, 0.32, 0.35),
                             "dark": (0.03, 0.03, 0.03), "leather": (0.3, 0.2, 0.1), "wood": (0.3, 0.22, 0.14),
                             "flange": (0.6, 0.6, 0.63)})
    T = c.part("Torso")
    T.lathe([(0.31, -0.38), (0.33, -0.12), (0.33, 0.14), (0.27, 0.3), (0.16, 0.38)], 8, "tint_jack", phase=TAU / 16)  # a big padded body
    T.lathe([(0.32, -0.3), (0.335, -0.1), (0.335, 0.14), (0.28, 0.26)], 8, "brig", phase=TAU / 16, scale=(1.02, 1.02))  # the brigandine over it
    for row in range(3):
        for k in range(5):
            ang = -0.7 + k * 0.35
            T.sphere(0.014, (math.sin(ang) * 0.335, -0.2 + row * 0.15, math.cos(ang) * 0.335), "rivet", segs=5, rings=2)
    T.box((0.6, 0.07, 0.5), (0, -0.33, 0), "leather", chamfer=0.3)
    T.lathe([(0.14, 0.32), (0.17, 0.42)], 8, "tint_jack_dark")  # a padded collar
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.33, 0.24, 0))
        for k in range(3):  # stacked lames
            P.lathe([(0.15 - k * 0.025, -0.04 + k * 0.045), (0.13 - k * 0.025, 0.0 + k * 0.045)], 8, "steel" if k % 2 == 0 else "steel_dark",
                    rot=(0, 0, -sx * 0.4))
    H = c.part("Head")
    # a barbute: a closed bell of steel with a T-shaped opening
    H.lathe([(0.2, -0.2), (0.21, 0.0), (0.19, 0.14), (0.12, 0.24), (0, 0.27)], 10, "steel")
    H.box((0.22, 0.04, 0.02), (0, 0.04, 0.205), "dark")  # the T's bar (the eyes)
    H.box((0.06, 0.18, 0.02), (0, -0.06, 0.205), "dark")  # and its stem
    H.lathe([(0.02, 0.24), (0.035, 0.3)], 6, "steel_dark")  # a little crest knob
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        gauntlet(hand, "steel", "steel_dark", 0.13, sx)
    W = c.part("Weapon")
    W.lathe([(0.025, -0.12), (0.025, 0.6)], 6, "wood")
    W.lathe([(0.03, -0.14), (0.04, -0.1), (0.03, -0.06)], 6, "steel_dark")  # the pommel
    W.sphere(0.07, (0, 0.68, 0), "steel_dark", segs=8, rings=4)
    for k in range(7):  # the flanges, standing out round the head
        ang = k * TAU / 7
        W.poly([(0, -0.1), (0.1, -0.06), (0.12, 0.04), (0.06, 0.12), (0, 0.12)], 0.022, "flange",
               pos=(0, 0.66, 0), rot=(0, ang, 0))
    W.loft([[(-0.02, 0.76, -0.02), (0.02, 0.76, -0.02), (0.02, 0.76, 0.02), (-0.02, 0.76, 0.02)], (0, 0.86, 0)], "flange")  # the top spike
    return c


def sexton():
    """The bell-ringer and gravedigger: tall and gaunt in a grey-blue smock under a muddy
    leather apron, hood thrown back off a bald head, an iron circlet of office, and over his
    face a mask of bone carved as a skull. A great verdigris bell hung from a pole (right
    hand; it swings free: RightHand_Bell) and a grave spade (left)."""
    smock = (0.42, 0.48, 0.58)
    c = Char("sexton", {"tint_smock": smock, "tint_smock_dark": shade(smock, -0.3), "apron": (0.3, 0.2, 0.12),
                        "mud": (0.22, 0.17, 0.1), "rope": (0.62, 0.52, 0.32), "skin": (0.78, 0.72, 0.64), "skin_dark": (0.6, 0.52, 0.45),
                        "dark": (0.03, 0.02, 0.02), "hood": (0.12, 0.12, 0.16), "iron": (0.35, 0.35, 0.38),
                        "bronze": (0.3, 0.55, 0.45), "bronze_dark": (0.2, 0.38, 0.32), "wood": (0.32, 0.22, 0.12),
                        "spade": (0.5, 0.5, 0.52), "glow_eye": (0.75, 0.85, 1.0),
                        "bone": (0.86, 0.82, 0.7), "bone_dark": (0.55, 0.5, 0.4)})
    T = c.part("Torso")
    # a long smock, narrow at the shoulders: gaunt
    T.lathe([(0.27, -0.4), (0.25, -0.15), (0.24, 0.1), (0.22, 0.28), (0.13, 0.38)], 8, "tint_smock", scale=(1, 0.75), phase=TAU / 16)
    for k in range(4):
        T.box((0.012, 0.6, 0.012), (-0.15 + k * 0.1, -0.06, 0.19), "tint_smock_dark")  # pleats
    # the apron, mud-caked at the hem, and a rope belt
    T.poly([(-0.2, -0.42), (0.2, -0.42), (0.18, 0.12), (-0.18, 0.12)], 0.025, "apron", pos=(0, 0, 0.2))
    rnd = random.Random(31)
    for k in range(8):
        T.box((0.05 + rnd.uniform(0, 0.04), 0.04 + rnd.uniform(0, 0.05), 0.01), (-0.16 + k * 0.045, -0.36 + rnd.uniform(0, 0.08), 0.215), "mud")
    T.lathe([(0.25, -0.03), (0.26, 0.0), (0.25, 0.03)], 10, "rope", pos=(0, -0.08, 0), scale=(1, 0.8))
    T.box((0.03, 0.2, 0.02), (0.08, -0.2, 0.22), "rope", rot=(0, 0, 0.1))  # its loose end
    # the hood, thrown back behind the head
    T.lathe([(0.17, 0.3), (0.2, 0.36), (0.16, 0.44)], 8, "hood", pos=(0, 0.02, -0.08))
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.27, 0.24, 0))
        P.lathe([(0.1, -0.04), (0.12, 0.0), (0.09, 0.05), (0, 0.06)], 7, "hood", rot=(0, 0, -sx * 0.35))  # sackcloth shoulder wraps
        P.box((0.04, 0.02, 0.14), (0, 0.05, 0), "rope", rot=(0, 0, -sx * 0.35))
    H = c.part("Head")
    # a long bald head and an iron circlet of office
    H.lathe([(0.12, -0.2), (0.15, -0.08), (0.16, 0.06), (0.14, 0.18), (0.08, 0.25), (0, 0.27)], 8, "skin", scale=(1, 0.95), phase=TAU / 16)
    H.lathe([(0.155, 0.1), (0.16, 0.13)], 10, "iron")  # the circlet
    H.box((0.04, 0.05, 0.02), (0, 0.13, 0.16), "bronze")  # a little bell on it
    # the skull mask: a plate of bone over the face, deep black sockets with a cold pinpoint
    # in each, a nose hole, cheekbones, and a grin of teeth over a black slot
    H.poly([(-0.12, 0.09), (0.12, 0.09), (0.135, 0.02), (0.11, -0.06), (0.07, -0.1), (0.06, -0.17),
            (-0.06, -0.17), (-0.07, -0.1), (-0.11, -0.06), (-0.135, 0.02)], 0.035, "bone", pos=(0, 0, 0.14))
    H.box((0.25, 0.03, 0.03), (0, 0.065, 0.158), "bone", chamfer=0.4)  # the brow ridge
    for sx in (-1, 1):
        H.poly([(-0.04, 0.03), (0.04, 0.034), (0.046, -0.012), (0.018, -0.042), (-0.028, -0.036), (-0.048, 0.0)], 0.014,
               "dark", pos=(sx * 0.054, 0.016, 0.16), rot=(0, 0, -sx * 0.32))  # a socket, slanted into a glare
        H.box((0.016, 0.016, 0.01), (sx * 0.05, 0.012, 0.166), "glow_eye")  # the pinpoint in it
        H.box((0.05, 0.022, 0.02), (sx * 0.085, -0.045, 0.152), "bone_dark", chamfer=0.3, rot=(0, 0, sx * 0.35))  # a cheekbone
    H.poly([(0.0, 0.0), (0.022, -0.04), (-0.022, -0.04)], 0.014, "dark", pos=(0, -0.025, 0.162))  # the nose hole
    for a, b in (((0.03, 0.09), (0.045, 0.06)), ((0.045, 0.06), (0.03, 0.045)), ((0.03, 0.045), (0.04, 0.035))):
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        ln = math.hypot(b[0] - a[0], b[1] - a[1])
        H.box((0.006, ln + 0.004, 0.008), (mx, my, 0.161), "dark", rot=(0, 0, math.atan2(a[0] - b[0], b[1] - a[1])))  # a crack down the brow
    H.box((0.11, 0.03, 0.012), (0, -0.11, 0.159), "dark")  # the slot behind the teeth
    for k in range(6):
        H.box((0.014, 0.034, 0.014), (-0.045 + k * 0.018, -0.11, 0.163), "bone", chamfer=0.3)  # teeth
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        fist(hand, "skin", 0.1, sx, knuckles="skin_dark")
        hand.lathe([(0.055, -0.12), (0.045, -0.05)], 6, "tint_smock_dark")  # a cuff, at the wrist
    # the bell on its pole: hung from a crossbar at the top, mouth down, a clapper under it.
    # The bell is its own part, its origin on the crossbar: the game swings it from there
    # under gravity (Enemy._swing_parts), so it hangs and sways whatever the pole does.
    W = c.part("Weapon")
    W.lathe([(0.025, -0.15), (0.025, 0.85)], 6, "wood")
    W.box((0.26, 0.04, 0.04), (0, 0.86, 0), "iron")
    B = c.part("RightHand_Bell", (0, 0.86, 0))
    B.box((0.03, 0.08, 0.05), (0, -0.04, 0), "iron")  # the hanger, round the crossbar
    B.lathe([(0.21, -0.38, 0.94), (0.2, -0.34), (0.15, -0.24), (0.11, -0.14), (0.09, -0.08), (0, -0.06)], 12, "bronze")
    B.lathe([(0.215, -0.4), (0.21, -0.36)], 12, "bronze_dark")  # the lip
    B.lathe([(0.008, -0.38), (0.008, -0.08)], 4, "iron")  # the clapper's rod
    B.sphere(0.05, (0, -0.4, 0), "iron", segs=6, rings=3)  # the clapper
    # the grave spade, in the left hand
    S = c.part("LeftHand_Spade")
    S.lathe([(0.022, -0.12), (0.022, 0.7)], 6, "wood")
    S.box((0.14, 0.03, 0.03), (0, -0.14, 0), "wood")  # a T-grip
    S.poly([(-0.1, 0.0), (0.1, 0.0), (0.09, 0.2), (0.0, 0.26), (-0.09, 0.2)], 0.012, "spade", pos=(0, 0.7, 0))
    S.box((0.16, 0.05, 0.016), (0, 0.76, 0.0), "mud")  # earth still on it
    return c


def smelter():
    """The Molten Core's guardian: a hulk of cooled black slag, cracked all over with the
    fire showing through, a head like a furnace mouth, fists of rock still glowing."""
    rock = (0.09, 0.08, 0.08)
    c = Char("the_smelter", {"rock": rock, "rock_light": shade(rock, 0.08), "rock_dark": shade(rock, -0.05),
                             "glow_crack": (0.9, 0.3, 0.04), "glow_core": (0.95, 0.42, 0.06), "glow_eye": (1.0, 0.7, 0.3)})
    rnd = random.Random(99)
    T = c.part("Torso")
    T.lathe([(0.36, -0.38), (0.42, -0.12), (0.44, 0.1), (0.4, 0.27), (0.22, 0.36)], 9, "rock", scale=(1, 0.7), jitter=rnd, phase=TAU / 18)
    for k in range(9):  # crusts of slag stuck on, and the cracks between them glowing
        a = -1.1 + k * 0.28
        y = rnd.uniform(-0.3, 0.25)
        T.box((0.14, 0.1, 0.05), (math.sin(a) * 0.36, y, math.cos(a) * 0.27 + 0.02), "rock_light", rot=(0, a, rnd.uniform(-0.4, 0.4)), chamfer=0.3)
    for k in range(7):
        x0 = rnd.uniform(-0.25, 0.2)
        y0 = rnd.uniform(-0.3, 0.2)
        for j in range(3):  # a crack: a short zigzag of glowing seams
            T.box((0.012, 0.09, 0.01), (x0 + j * 0.03, y0 + j * 0.07, 0.3 - abs(x0) * 0.25), "glow_crack", rot=(0, 0, 0.6 * (-1) ** j))
    T.lathe([(0.0, 0.0), (0.09, 0.0), (0.0, 0.0)], 10, "glow_core", pos=(0, 0.05, 0.31), rot=(math.pi / 2, 0, 0))  # the heart showing through
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.42, 0.28, 0))
        P.sphere(0.17, (0, 0, 0), "rock_light", segs=7, rings=4, scale=(1.1, 0.8, 1.0))  # boulders on the shoulders
        P.box((0.012, 0.12, 0.01), (sx * 0.02, 0.02, 0.15), "glow_crack", rot=(0, 0, 0.4))
    H = c.part("Head")
    H.lathe([(0.16, -0.18), (0.2, -0.05), (0.19, 0.1), (0.13, 0.2), (0, 0.24)], 8, "rock", jitter=rnd, phase=TAU / 16)
    H.box((0.18, 0.05, 0.02), (0, -0.08, 0.17), "glow_core")  # a furnace mouth
    for sx in (-1, 1):
        H.box((0.05, 0.03, 0.02), (sx * 0.06, 0.04, 0.17), "glow_eye")
        H.box((0.08, 0.03, 0.03), (sx * 0.07, 0.08, 0.16), "rock_light", rot=(0, 0, -sx * 0.3))  # a heavy brow
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        fist(hand, "rock", 0.17, sx, knuckles="glow_crack")  # fists of rock, the knuckles still glowing
        hand.lathe([(0.1, -0.2), (0.08, -0.08)], 7, "rock_light")
    # a crown of cooled spikes on the head, and slag dripping from the jaw: separate pieces
    K = c.part("Head_Crest")
    for k in range(5):
        a = -0.6 + k * 0.3
        K.loft([[(math.sin(a) * 0.12 - 0.03, 0.18, math.cos(a) * 0.1 - 0.03), (math.sin(a) * 0.12 + 0.03, 0.18, math.cos(a) * 0.1 - 0.03),
                 (math.sin(a) * 0.12 + 0.03, 0.18, math.cos(a) * 0.1 + 0.03), (math.sin(a) * 0.12 - 0.03, 0.18, math.cos(a) * 0.1 + 0.03)],
                (math.sin(a) * 0.16, 0.32 - abs(k - 2) * 0.03, math.cos(a) * 0.12)], "rock_light")
    D = c.part("Head_Drip")
    for k in range(3):
        D.box((0.02, 0.06 + k * 0.02, 0.02), (-0.05 + k * 0.05, -0.15 - k * 0.01, 0.17), "glow_crack")
    for sx in (-1, 1):
        G = c.part("RightHand_Glow" if sx > 0 else "LeftHand_Glow")
        G.sphere(0.025, (0, 0.02, 0.1), "glow_core", segs=6, rings=3)  # embers held in each fist
    return c


def lamplighter():
    coat = (0.12, 0.15, 0.25)
    c = Char("lamplighter", {"tint_coat": coat, "tint_coat_light": shade(coat, 0.2), "coat_dark": shade(coat, -0.3), "brass": (0.7, 0.6, 0.3),
                             "skin": (0.78, 0.78, 0.72), "glow_eye": (0.6, 0.85, 1.0), "glove": (0.2, 0.2, 0.22), "wood": (0.25, 0.2, 0.15),
                             "iron": (0.2, 0.2, 0.22), "glow_lamp": (0.5, 0.75, 1.0)})
    T = c.part("Torso")
    # a long coat buttoned to the throat, narrow in the shoulder
    T.lathe([(0.27, -0.42), (0.2, -0.2), (0.17, 0.0), (0.19, 0.2), (0.16, 0.32), (0.1, 0.38)], 8, "tint_coat", scale=(1, 0.85), phase=TAU / 16)
    T.box((0.03, 0.6, 0.015), (0.0, -0.06, 0.19), "coat_dark")
    for k in range(5):
        T.sphere(0.013, (0.035, -0.2 + k * 0.1, 0.2), "brass", segs=5, rings=2)
    T.lathe([(0.1, 0.34), (0.12, 0.44)], 8, "coat_dark")  # a high collar
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.22, 0.26, 0))
        P.box((0.16, 0.05, 0.26), (0, 0, 0), "tint_coat_light", chamfer=0.4, rot=(0, 0, -sx * 0.25))  # epaulette
        P.box((0.14, 0.03, 0.03), (0, 0.035, 0.11), "brass", rot=(0, 0, -sx * 0.25))
        for k in range(5):
            P.box((0.012, 0.06, 0.012), (-0.05 + k * 0.025, -0.04, 0.12), "brass")  # the fringe
    H = c.part("Head")
    # a long pale head and a stovepipe hat
    face(H, "skin", "glow_eye", w=0.18, h=0.32, brow=False, mouth="coat_dark")
    H.lathe([(0.2, 0.13), (0.21, 0.15)], 8, "coat_dark")
    H.lathe([(0.11, 0.15), (0.115, 0.36), (0.12, 0.42), (0, 0.43)], 8, "coat_dark")
    H.box((0.24, 0.03, 0.02), (0, 0.18, 0.1), "brass")  # the hatband's buckle side
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        fist(hand, "glove", 0.09, sx)
    W = c.part("Weapon")
    W.lathe([(0.02, -0.15), (0.02, 1.05)], 6, "wood")
    for y in (1.06, 1.28):
        W.box((0.16, 0.02, 0.16), (0, y, 0), "iron")
    for sx in (-1, 1):
        for sz in (-1, 1):
            W.box((0.015, 0.22, 0.015), (sx * 0.065, 1.17, sz * 0.065), "iron")  # the lantern's cage
    W.lathe([(0.04, 1.08), (0.055, 1.17), (0.04, 1.26)], 6, "glow_lamp")
    W.lathe([(0.07, 1.29), (0, 1.38)], 6, "iron")
    return c


# --- secret guardians: bodies found nowhere else ------------------------------------------

def astronomer():
    coat = (0.08, 0.07, 0.25)
    c = Char("the_astronomer", {"tint_coat": coat, "tint_coat_light": shade(coat, 0.15), "brass": (0.85, 0.7, 0.35), "brass_dark": (0.55, 0.42, 0.18),
                                "planet": (0.35, 0.55, 0.85), "planet_band": (0.85, 0.75, 0.55), "glow_star": (1.0, 0.95, 0.7),
                                "glow_eye": (1.0, 0.95, 0.75), "glove": (0.12, 0.1, 0.15), "ring": (0.8, 0.75, 0.6)})
    T = c.part("Torso")
    # a long robe of night, starred, with brass armillary bands round it at odd angles
    T.lathe([(0.32, -0.45), (0.26, -0.2), (0.22, 0.05), (0.24, 0.25), (0.16, 0.36)], 10, "tint_coat")
    for k, (ty, tilt) in enumerate([(-0.1, 0.35), (0.12, -0.3)]):
        T.lathe([(0.3 - k * 0.02, -0.012), (0.3 - k * 0.02, 0.012)], 16, "brass", pos=(0, ty, 0), rot=(tilt, 0, tilt * 0.5), cap=False)
    for k in range(9):
        a = k * 2.4
        T.box((0.025, 0.025, 0.02), (math.sin(a) * 0.2, -0.35 + k * 0.08, 0.23 + 0.04 * math.cos(a)), "glow_star")
    for sx in (-1, 1):
        # on each shoulder a little planet on a brass arm
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.27, 0.3, 0))
        P.box((0.03, 0.12, 0.03), (0, 0.04, 0), "brass_dark")
        P.sphere(0.07, (0, 0.13, 0), "planet_band" if sx < 0 else "planet", segs=8, rings=4)
    H = c.part("Head")
    # a planet for a head: banded, ringed, with two pale lights for eyes
    H.sphere(0.2, (0, 0, 0), "planet", segs=14, rings=7)
    for k, y in enumerate([-0.09, 0.0, 0.09]):
        r = math.sqrt(max(0.0, 0.2 ** 2 - y ** 2)) + 0.004
        H.lathe([(r, y - 0.018), (r, y + 0.018)], 14, "planet_band" if k != 1 else "planet", cap=False)
    H.lathe([(0.36, -0.006), (0.36, 0.006)], 24, "ring", rot=(0.35, 0, 0.25), cap=False)
    H.lathe([(0.3, -0.006), (0.3, 0.006)], 24, "ring", rot=(0.35, 0, 0.25), cap=False)
    for sx in (-1, 1):
        H.box((0.05, 0.025, 0.02), (sx * 0.07, 0.02, 0.2), "glow_eye")
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        fist(hand, "glove", 0.11, sx)
    W = c.part("Weapon")
    # a staff topped with an armillary sphere, a star burning inside it
    W.lathe([(0.025, -0.15), (0.025, 1.0)], 6, "brass_dark")
    for k, tilt in enumerate([0.0, 1.0, 2.1]):
        W.lathe([(0.12, -0.008), (0.12, 0.008)], 16, "brass", pos=(0, 1.12, 0), rot=(tilt, k * 0.6, 0), cap=False)
    W.sphere(0.05, (0, 1.12, 0), "glow_star", segs=8, rings=4)
    return c


CHARACTERS = {
    "the_astronomer": astronomer,
    "footman": footman,
    "woodcutter": woodcutter,
    "knight": lambda: knight(),
    "brute": brute,
    "duelist": duelist,
    "the_rusted": rusted,
    "pyre_zealot": zealot,
    "wraith": lambda: wraith(),
    "castellan": castellan,
    "sexton": sexton,
    "the_smelter": smelter,
    "headsman": headsman,
    "halberdier": halberdier,
    "twinblade": twinblade,
    "bonebreaker": bonebreaker,
    "lamplighter": lambda: lamplighter(),
    "vault_warden": lambda: knight("vault_warden", tint=(0.85, 0.7, 0.35), cloth=(0.5, 0.1, 0.1), gilded=True),
}


# --- export ---------------------------------------------------------------------------

def export(slug, build):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    c = build()
    tris = 0
    for p in c.parts:
        # Every weapon is built with its edge out to +x (-x for one in the left hand, built
        # mirrored), and turned a quarter round the grip so the edge faces the foe's thumb
        # side (+Z, the player at rest). The recorder's mirror turns a held weapon half round
        # its grip (the foe is your mirror image, a rotation can't be), so the studio's ghost
        # of it on your controller gets that half turn back: in your hand the edge faces the
        # trigger, and on the foe it faces where the mirror shows yours facing.
        if p.name == "Weapon":
            p.turn = -math.pi / 2
        elif p.name in ("LeftHand_Sabre", "LeftHand_Spade"):
            p.turn = math.pi / 2
        obj = p.finish(c.palette)
        tris += sum(len(poly.vertices) - 2 for poly in obj.data.polygons)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, slug + ".glb")
    opts = dict(filepath=path, export_format="GLB", export_apply=True, export_yup=True, export_animations=False,
                export_skins=False, export_morph=False, export_cameras=False, export_lights=False,
                export_materials="EXPORT", export_normals=True, export_texcoords=False, export_extras=False)
    try:
        bpy.ops.export_scene.gltf(**opts)
    except TypeError:
        for k in ("export_texcoords", "export_normals", "export_extras", "export_morph"):
            opts.pop(k, None)
        bpy.ops.export_scene.gltf(**opts)
    print("%-14s %4d tris  %6d bytes  %s" % (slug, tris, os.path.getsize(path), ", ".join(p.name for p in c.parts)))


if __name__ == "__main__":
    wanted = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for slug, build in CHARACTERS.items():
        if wanted and slug not in wanted:
            continue
        export(slug, build)
