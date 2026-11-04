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
    if key in bpy.data.materials:
        return bpy.data.materials[key]
    col = palette[key]
    mat = bpy.data.materials.new(key)
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

def fist(P, mat, s=0.12, side=1, knuckles=None, thumb=True):
    """A clenched hand around a vertical grip. side: +1 right hand (thumb inward, -x)."""
    P.box((s, s * 1.05, s * 0.9), (0, 0, 0), mat, chamfer=0.3)
    kn = knuckles or mat
    for k in range(4):
        P.box((s * 0.2, s * 0.22, s * 0.22), (-s * 0.33 + k * s * 0.22, s * 0.42, s * 0.42), kn, chamfer=0.4)
    if thumb:
        P.box((s * 0.3, s * 0.45, s * 0.32), (-side * s * 0.5, s * 0.1, s * 0.3), mat, rot=(0, 0, side * 0.3), chamfer=0.4)


def open_hand(P, mat, s=0.11, side=1, finger_mat=None, length=0.1):
    """A palm with four long fingers and a thumb: wraiths, bare hands."""
    P.box((s, s * 0.9, s * 0.4), (0, 0, 0), mat, chamfer=0.3)
    fm = finger_mat or mat
    for k in range(4):
        x = -s * 0.36 + k * s * 0.24
        P.box((s * 0.17, length, s * 0.17), (x, -s * 0.45 - length / 2, s * 0.05), fm, taper=(0.7, 0.7), rot=(0.2, 0, 0))
    P.box((s * 0.18, length * 0.6, s * 0.18), (-side * s * 0.6, -s * 0.1, s * 0.05), fm, rot=(0, 0, side * 0.9), taper=(0.7, 0.7))


def gauntlet(P, steel, dark, s=0.12, side=1):
    fist(P, steel, s, side, knuckles=dark)
    P.lathe([(s * 0.5, s * 0.5), (s * 0.68, s * 0.95)], 8, dark, pos=(0, 0, 0))  # flared cuff


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
    """A head: an eight-sided lathe with a jaw, a wedge of a nose, sockets for eyes, a brow."""
    P.lathe([(w * 0.3, -h * 0.5), (w * 0.44, -h * 0.35), (w * 0.5, -h * 0.05), (w * 0.52, h * 0.25),
             (w * 0.42, h * 0.45), (0, h * 0.52)], 8, skin, scale=(1, 0.92), phase=TAU / 16)
    if nose:
        P.poly([(0, -0.02), (0, 0.05), (0.035, -0.015)], 0.03, skin, pos=(0, 0.0, w * 0.46), rot=(0, -math.pi / 2, 0))
    if eyes:
        for sx in (-1, 1):
            P.box((0.05, 0.028, 0.02), (sx * 0.065, 0.045, w * 0.46), dark)
    if brow:
        P.box((0.17, 0.025, 0.025), (0, 0.078, w * 0.44), dark)
    if mouth:
        P.box((0.07, 0.018, 0.015), (0, -0.075, w * 0.44), mouth)


def eye_slit(P, dark, w=0.24, y=0.03, z=0.16):
    P.box((w, 0.028, 0.02), (0, y, z), dark)


# --- the characters -------------------------------------------------------------------

def footman():
    cloth = (0.6, 0.5, 0.35)
    leather = (0.35, 0.22, 0.12)
    skin = (0.8, 0.62, 0.5)
    c = Char("footman", {"tint_cloth": cloth, "tint_cloth_dark": shade(cloth, -0.3), "leather": leather,
                         "leather_light": shade(leather, 0.1), "skin": skin, "dark": (0.05, 0.03, 0.02), "beard": (0.3, 0.2, 0.12),
                         "iron": (0.4, 0.4, 0.42), "iron_dark": (0.35, 0.35, 0.37), "brass": (0.6, 0.55, 0.4),
                         "steel": (0.6, 0.6, 0.62), "wood": (0.3, 0.25, 0.18)})
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
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.3, 0.22, 0))
        P.lathe([(0.1, -0.03), (0.13, 0.0), (0.1, 0.05), (0, 0.07)], 7, "leather_light", scale=(0.9, 1.3), rot=(0, 0, -sx * 0.3))
        P.box((0.14, 0.02, 0.06), (0, 0.04, 0), "leather", rot=(0, 0, -sx * 0.3))  # the strap over it
    H = c.part("Head")
    face(H, "skin", "dark", mouth="dark")
    H.poly([(-0.07, 0), (0.07, 0), (0.04, -0.07), (-0.04, -0.07)], 0.06, "beard", pos=(0, -0.1, 0.105))
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
                            "wood": (0.42, 0.3, 0.18), "iron": (0.45, 0.45, 0.47), "edge": (0.78, 0.78, 0.8)})
    T = c.part("Torso")
    # a thick wool tunic, barrel-chested, with a fur collar and a rope belt
    T.lathe([(0.29, -0.36), (0.32, -0.15), (0.33, 0.1), (0.29, 0.28), (0.18, 0.36)], 8, "tint_wool", phase=TAU / 16)
    T.lathe([(0.17, 0.27), (0.22, 0.32), (0.16, 0.4)], 8, "fur")
    T.box((0.6, 0.06, 0.52), (0, -0.24, 0), "leather", chamfer=0.3)
    T.box((0.07, 0.07, 0.03), (0.1, -0.24, 0.27), "leather_light")
    for k in range(3):
        T.box((0.4, 0.025, 0.02), (0, 0.12 - k * 0.12, 0.29), "tint_wool_dark")  # patches and stitching
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.3, 0.22, 0))
        P.lathe([(0.11, -0.04), (0.14, 0.0), (0.11, 0.05), (0, 0.07)], 7, "fur", scale=(0.9, 1.2), rot=(0, 0, -sx * 0.3))
    H = c.part("Head")
    face(H, "skin", "dark", mouth="dark")
    # a big bushy beard and a knitted cap with a slumped point
    H.poly([(-0.12, 0.02), (0.12, 0.02), (0.1, -0.12), (0.04, -0.2), (-0.04, -0.2), (-0.1, -0.12)], 0.1, "beard", pos=(0, -0.06, 0.17))
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
                    "blade": (0.82, 0.84, 0.9), "wood": (0.35, 0.3, 0.2), "leather": (0.3, 0.2, 0.12)})
    T = c.part("Torso")
    # a breastplate with a chest and a waist, over a plackart of lames
    T.lathe([(0.25, -0.36), (0.3, -0.2), (0.33, 0.02), (0.31, 0.2), (0.22, 0.33), (0.15, 0.38)], 8, "tint_steel", scale=(1, 0.8), phase=TAU / 16)
    for k in range(3):
        T.lathe([(0.3 - k * 0.01, -0.36 + k * 0.06), (0.32 - k * 0.01, -0.33 + k * 0.06)], 8, "steel_dark", scale=(1, 0.8), phase=TAU / 16)
    T.lathe([(0.14, 0.34), (0.17, 0.44)], 8, "steel_dark")  # gorget
    T.poly([(-0.16, -0.32), (0.16, -0.32), (0.16, 0.18), (0, 0.22), (-0.16, 0.18)], 0.025, "cloth", pos=(0, 0, 0.27))  # tabard
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
    fur = (0.25, 0.18, 0.12)
    iron = (0.3, 0.3, 0.33)
    c = Char("brute", {"tint_skin": skin, "tint_skin_dark": shade(skin, -0.15), "fur": fur, "fur_light": shade(fur, 0.1),
                       "iron": iron, "iron_light": shade(iron, 0.2), "leather": (0.3, 0.2, 0.1), "dark": (0.05, 0.03, 0.02),
                       "brow": (0.2, 0.12, 0.08), "wood": (0.35, 0.25, 0.15), "iron_dark": (0.2, 0.2, 0.22)})
    T = c.part("Torso")
    # a barrel chest, two slabs of pectoral, a gut
    T.lathe([(0.34, -0.38), (0.4, -0.15), (0.42, 0.1), (0.38, 0.28), (0.2, 0.36)], 8, "tint_skin", scale=(1, 0.6), phase=TAU / 16)
    for sx in (-1, 1):
        T.box((0.26, 0.2, 0.08), (sx * 0.15, 0.08, 0.2), "tint_skin", chamfer=0.5, taper=(0.8, 0.5))
    T.box((0.02, 0.2, 0.02), (0, 0.05, 0.24), "tint_skin_dark")
    T.lathe([(0.5, 0.2, 0.8), (0.52, 0.32, 0.75), (0.3, 0.42)], 12, "fur", scale=(1, 0.7), phase=TAU / 24)  # the mantle, ragged
    T.lathe([(0.17, 0.36), (0.19, 0.45)], 8, "iron")  # collar
    T.box((0.72, 0.14, 0.38), (0, -0.34, 0), "leather", chamfer=0.2)
    T.box((0.1, 0.1, 0.02), (0, -0.34, 0.2), "iron")
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
    H.box((0.24, 0.035, 0.03), (0, 0.09, 0.14), "brow", rot=(0.3, 0, 0))
    for sx in (-1, 1):
        H.box((0.03, 0.07, 0.05), (sx * 0.16, 0.0, 0.0), "tint_skin")  # ears
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        fist(hand, "tint_skin", 0.17, sx, knuckles="tint_skin_dark")
        hand.box((0.19, 0.06, 0.19), (0, 0.11, 0), "leather")  # wrist wrap
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
    H.box((0.22, 0.07, 0.03), (0, 0.04, 0.085), "dark")  # the mask
    H.box((0.09, 0.02, 0.02), (0, -0.07, 0.095), "hair")
    H.lathe([(0.3, 0.125), (0.31, 0.145)], 10, "coat_dark")  # hat brim
    H.lathe([(0.13, 0.14), (0.12, 0.26), (0.13, 0.3), (0, 0.31)], 8, "coat_dark")
    H.poly([(0, 0), (0.24, 0.18), (0.3, 0.34), (0.12, 0.3), (0.02, 0.1)], 0.02, "feather", pos=(0.1, 0.24, -0.04), rot=(0, -0.3, 0))
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        fist(hand, "cream", 0.09, sx)
        hand.lathe([(0.05, 0.04), (0.07, 0.1)], 6, "tint_coat")  # cuff
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
                            "hole": (0.03, 0.02, 0.02), "glow_eye": (0.5, 1.0, 0.3), "strap": (0.2, 0.14, 0.08)})
    rng = random.Random(7)
    T = c.part("Torso")
    # plate that has gone soft: dented all over, holed through, stained
    T.lathe([(0.24, -0.36), (0.29, -0.15), (0.3, 0.1), (0.25, 0.3), (0.14, 0.36)], 7, "rust", scale=(1, 0.85), jitter=rng, phase=TAU / 14)
    for k in range(3):
        T.box((0.08 + k * 0.02, 0.06, 0.06), (-0.1 + k * 0.1, -0.12 + k * 0.09, 0.26), "hole", rot=(0, 0, rng.uniform(-0.5, 0.5)))
    T.box((0.26, 0.12, 0.02), (0.05, 0.1, 0.28), "rot", rot=(0, 0, 0.2))
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
    robe = (0.55, 0.2, 0.08)
    wrap = (0.75, 0.65, 0.5)
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
        hand.box((0.12, 0.02, 0.12), (0, 0.02, 0), "wrap_dark")
        hand.box((0.12, 0.02, 0.12), (0, -0.03, 0), "wrap_dark")
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
                    "glow_blade": (0.5, 0.7, 1.0), "hilt": (0.15, 0.15, 0.18)})
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
        hand.lathe([(0.055, 0.04), (0.08, 0.14, 0.7)], 8, "dark")  # the sleeve, tattered
    if king:
        W = c.part("Weapon")
        sword(W, "glow_blade", "hilt", "hilt", 0.85, 0.06)
    return c


def castellan():
    steel = (0.55, 0.58, 0.65)
    cloth = (0.15, 0.25, 0.55)
    c = Char("castellan", {"tint_steel": steel, "tint_steel_light": shade(steel, 0.12), "steel_dark": shade(steel, -0.25),
                           "cloth": cloth, "dark": (0.01, 0.01, 0.01), "gold": (0.95, 0.75, 0.2), "blade": (0.82, 0.84, 0.9),
                           "leather": (0.3, 0.2, 0.12), "shield": shade(steel, 0.05), "shield_rim": shade(steel, -0.3)})
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
    S.box((0.1, 0.12, 0.02), (0.05, 0.32, 0.11), "gold")
    return c


def headsman():
    skin = (0.7, 0.55, 0.45)
    leather = (0.25, 0.15, 0.08)
    c = Char("headsman", {"skin": skin, "skin_dark": shade(skin, -0.15), "leather": leather, "leather_light": shade(leather, 0.15),
                          "blood": (0.45, 0.1, 0.08), "hood": (0.06, 0.05, 0.05), "eyes": (0.6, 0.5, 0.4), "wood": (0.3, 0.2, 0.12),
                          "iron": (0.5, 0.5, 0.52), "edge": (0.8, 0.8, 0.82), "iron_dark": (0.3, 0.3, 0.32)})
    T = c.part("Torso")
    # bare shoulders and a leather apron over a chest like a door
    T.lathe([(0.34, -0.36), (0.37, -0.1), (0.38, 0.15), (0.33, 0.3), (0.18, 0.36)], 8, "skin", scale=(1, 0.55), phase=TAU / 16)
    T.poly([(-0.22, -0.4), (0.22, -0.4), (0.24, 0.08), (0.12, 0.26), (-0.12, 0.26), (-0.24, 0.08)], 0.03, "leather", pos=(0, 0, 0.2))
    T.box((0.3, 0.07, 0.02), (0.03, 0.08, 0.22), "blood", rot=(0, 0, 0.15))
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
        H.box((0.05, 0.04, 0.025), (sx * 0.06, 0.04, 0.165), "eyes")
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        fist(hand, "skin", 0.15, sx, knuckles="skin_dark")
        hand.lathe([(0.085, 0.07), (0.09, 0.16)], 8, "leather")  # a bracer
    W = c.part("Weapon")
    W.lathe([(0.03, -0.15), (0.03, 1.0)], 6, "wood")
    W.poly([(0, -0.16), (0.12, -0.22), (0.26, -0.18), (0.34, -0.06), (0.36, 0.1), (0.3, 0.22), (0.16, 0.26), (0, 0.2)], 0.035, "iron",
           pos=(0.0, 0.95, 0))  # the crescent head
    W.poly([(0.26, -0.18), (0.34, -0.06), (0.36, 0.1), (0.3, 0.22), (0.28, 0.2), (0.33, 0.1), (0.31, -0.05), (0.25, -0.15)], 0.045, "edge",
           pos=(0.0, 0.95, 0))  # its edge, bright and thin
    W.box((0.1, 0.12, 0.1), (0, 0.95, 0), "iron_dark", chamfer=0.3)
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
    # a long pale face and a stovepipe hat
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

def coin_golem():
    gold = (0.95, 0.72, 0.22)
    c = Char("coin_golem", {"gold": gold, "gold_dark": shade(gold, -0.25), "gold_light": shade(gold, 0.2),
                            "slot": (0.05, 0.03, 0.01), "glow_eye": (1.0, 0.95, 0.6), "bar": (1.0, 0.8, 0.3)})
    T = c.part("Torso")
    # a body of stacked coins, each a little off true, so it reads as a pile that stood up
    for k in range(10):
        y = -0.38 + k * 0.078
        r = 0.27 + 0.06 * math.sin(k / 9 * math.pi)
        dx = 0.025 * math.sin(k * 2.3)
        T.lathe([(r, y), (r, y + 0.07)], 14, "gold" if k % 2 else "gold_dark", pos=(dx, 0, 0.01 * math.cos(k * 1.7)))
    for k in range(5):  # loose coins stuck to its belly
        T.lathe([(0.06, 0), (0.06, 0.015)], 10, "gold_light", pos=(-0.15 + k * 0.08, -0.15 + (k % 2) * 0.1, 0.33), rot=(math.pi / 2, 0, 0.3 * k))
    for sx in (-1, 1):
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.32, 0.3, 0))
        for k in range(3):  # a short stack on each shoulder
            P.lathe([(0.13 - k * 0.02, k * 0.045), (0.13 - k * 0.02, k * 0.045 + 0.04)], 12, "gold_light" if k % 2 else "gold", rot=(0, 0, -sx * 0.25))
    H = c.part("Head")
    # one great coin for a face, edge-on to the floor and face-on to you, with a slot for a mouth
    H.lathe([(0.22, -0.035), (0.22, 0.035)], 18, "gold", rot=(math.pi / 2, 0, 0))
    H.lathe([(0.17, -0.04), (0.17, 0.042)], 18, "gold_dark", rot=(math.pi / 2, 0, 0))
    H.box((0.2, 0.035, 0.03), (0, -0.08, 0.04), "slot")
    for sx in (-1, 1):
        H.box((0.05, 0.035, 0.02), (sx * 0.07, 0.05, 0.05), "glow_eye")
    for k in range(5):  # a crown of little coins standing on edge
        a = -0.6 + k * 0.3
        H.lathe([(0.045, -0.008), (0.045, 0.008)], 10, "gold_light", pos=(math.sin(a) * 0.17, 0.23 + 0.02 * math.cos(a * 3), 0.0), rot=(math.pi / 2, 0, 0))
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        for k in range(4):  # fists of stacked coins
            hand.lathe([(0.1, -0.1 + k * 0.05), (0.1, -0.1 + k * 0.05 + 0.045)], 12, "gold_dark" if k % 2 else "gold")
    W = c.part("Weapon")
    W.box((0.12, 0.08, 0.26), (0, 0.15, 0), "bar", chamfer=0.25)  # a gold bar, to throw
    return c


def housecat():
    fur = (0.85, 0.5, 0.2)
    c = Char("housecat", {"tint_fur": fur, "tint_fur_dark": shade(fur, -0.3), "cream": (0.95, 0.88, 0.75), "pink": (0.9, 0.55, 0.55),
                          "dark": (0.03, 0.02, 0.02), "glow_eye": (0.75, 1.0, 0.35), "collar": (0.7, 0.1, 0.1), "bell": (0.95, 0.78, 0.25),
                          "whisker": (0.95, 0.95, 0.92)})
    T = c.part("Torso")
    # a big sitting cat: a round loaf of a body, a cream chest, stripes, and a tail round the front
    T.lathe([(0.0, -0.42), (0.33, -0.38), (0.38, -0.15), (0.34, 0.1), (0.25, 0.3), (0.16, 0.38)], 12, "tint_fur", scale=(1, 0.85))
    T.sphere(0.2, (0, -0.02, 0.2), "cream", segs=10, rings=6, scale=(1.0, 1.5, 0.6))
    for k in range(3):
        for sx in (-1, 1):
            T.box((0.12, 0.035, 0.04), (sx * 0.3, -0.1 + k * 0.12, 0.12), "tint_fur_dark", rot=(0, sx * 0.6, sx * 0.3))
    for k in range(6):
        a = -1.3 + k * 0.45
        T.box((0.09, 0.09, 0.09), (math.sin(a) * 0.36, -0.38 + 0.02 * k, math.cos(a) * 0.3 * 0.85), "tint_fur" if k % 2 else "tint_fur_dark", chamfer=0.4)
    for sx in (-1, 1):
        # the collar, in two halves (they come off like pauldrons), with a bell on the right
        P = c.part("PauldronL" if sx < 0 else "PauldronR", (sx * 0.12, 0.33, 0.06))
        P.box((0.2, 0.05, 0.22), (0, 0, 0), "collar", rot=(0, 0, -sx * 0.2), chamfer=0.3)
        if sx > 0:
            P.sphere(0.045, (-0.08, -0.06, 0.12), "bell", segs=8, rings=4)
    H = c.part("Head")
    H.sphere(0.24, (0, 0, 0), "tint_fur", segs=12, rings=6, scale=(1.15, 0.95, 1.0))
    H.sphere(0.1, (0, -0.07, 0.18), "cream", segs=8, rings=4, scale=(1.3, 0.8, 0.7))
    for sx in (-1, 1):
        H.poly([(-0.08, 0), (0.08, 0), (0.0, 0.17)], 0.05, "tint_fur", pos=(sx * 0.15, 0.17, 0.0), rot=(0, 0, -sx * 0.25))
        H.poly([(-0.045, 0.01), (0.045, 0.01), (0.0, 0.11)], 0.055, "pink", pos=(sx * 0.15, 0.18, 0.01), rot=(0, 0, -sx * 0.25))
        H.box((0.07, 0.06, 0.02), (sx * 0.09, 0.04, 0.22), "glow_eye")
        H.box((0.015, 0.055, 0.025), (sx * 0.09, 0.04, 0.225), "dark")  # slit pupils
        for k in range(3):
            H.box((0.2, 0.008, 0.008), (sx * 0.2, -0.06 + k * 0.025, 0.2), "whisker", rot=(0, 0, sx * (k - 1) * 0.15))
    H.box((0.05, 0.035, 0.03), (0, -0.04, 0.26), "pink", chamfer=0.4)
    for sx in (-1, 1):
        hand = c.part("RightHand" if sx > 0 else "LeftHand")
        # paws: a soft round mitt with three toes and pink pads
        hand.sphere(0.12, (0, 0, 0), "tint_fur", segs=10, rings=5, scale=(1.0, 0.8, 1.0))
        for k in range(3):
            hand.sphere(0.04, (-0.06 + k * 0.06, 0.07, 0.07), "cream", segs=6, rings=3)
        hand.sphere(0.05, (0, -0.02, 0.1), "pink", segs=6, rings=3, scale=(1.2, 0.8, 0.5))
    W = c.part("Weapon")
    # a ball of yarn, batted about, trailing a strand
    W.sphere(0.11, (0, 0.18, 0.05), "collar", segs=10, rings=6)
    for k in range(4):
        W.box((0.23, 0.012, 0.012), (0, 0.13 + k * 0.035, 0.12), "cream", rot=(0, 0, 0.5 - k * 0.3))
    W.box((0.012, 0.25, 0.012), (0.09, 0.02, 0.06), "collar", rot=(0, 0, 0.3))
    return c


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
    "coin_golem": coin_golem,
    "housecat": housecat,
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
    "hollow_king": lambda: wraith("hollow_king", king=True),
    "headsman": headsman,
    "lamplighter": lambda: lamplighter(),
    "vault_warden": lambda: knight("vault_warden", tint=(0.85, 0.7, 0.35), cloth=(0.5, 0.1, 0.1), gilded=True),
}


# --- export ---------------------------------------------------------------------------

def export(slug, build):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    c = build()
    tris = 0
    for p in c.parts:
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
