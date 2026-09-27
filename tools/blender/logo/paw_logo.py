"""Paw Time 3D logo — scripted Blender (Cycles) build + render.

Usage:
  blender --background --factory-startup --python tools/blender/logo/paw_logo.py -- \
      --variant A --mode main --width 2400 --out assets/title/logo3d/logo_main.png

Modes:
  main       straight-on beauty render, transparent background
  shadow     soft contact/drop shadow only (shadow catcher, logo invisible to camera)
  turntable  --frame N of 12, subtle +-8 deg wobble around the vertical axis
  ja         wordmark + Japanese subtitle lockup
All modes share one camera framing so every layer lines up pixel-for-pixel
(turntable uses the same framing at its own width).
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
FONT = os.path.join(REPO, "assets", "fonts", "ZenMaruGothic-Black.ttf")

TILT_DEG = 11.0  # logo leans back so the camera sees the underside thickness
WOBBLE_DEG = 8.0


# ---------------------------------------------------------------- args ----
def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--variant", default="A")
    p.add_argument("--mode", default="main", choices=["main", "shadow", "turntable", "ja"])
    p.add_argument("--width", type=int, default=2400)
    p.add_argument("--samples", type=int, default=128)
    p.add_argument("--frame", type=int, default=0)
    p.add_argument("--out", required=True)
    return p.parse_args(argv)


# ------------------------------------------------------------- palette ----
def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return (lin[0], lin[1], lin[2], 1.0)


CREAM = dict(face_top="#FFF9EA", face_bot="#FFE3B4", face_side="#E9B77C", face_rim="#FFFFFF",
             face_rough=0.32, face_coat=1.0, face_sheen=0.0)
NAVY = dict(slab_top="#343B80", slab_bot="#1A1E4C", slab_side="#12153A", slab_rim="#6A73C4")
VARIANTS = {
    # A: cream candy-enamel letters on an ink-navy body
    "A": dict(layout="line", outer=None, **CREAM, **NAVY),
    # B: warm peach/coral face on a deep plum body
    "B": dict(layout="line", outer=None,
              face_top="#FFE1CC", face_bot="#FF9E80", face_side="#E0685A", face_rim="#FFF4EA",
              face_rough=0.3, face_coat=1.0, face_sheen=0.0,
              slab_top="#6A3474", slab_bot="#3A1742", slab_side="#260E2C", slab_rim="#B070B8"),
    # C: soft white vinyl, navy body, thin gold outer trim
    "C": dict(layout="line", outer="gold",
              face_top="#FFFFFF", face_bot="#EDEFF7", face_side="#C4C8DE", face_rim="#FFFFFF",
              face_rough=0.5, face_coat=0.25, face_sheen=0.6, **NAVY),
    # D: stacked lockup, cream + navy, bigger cat-ear P
    "D": dict(layout="stack", outer=None, **CREAM, **NAVY),
}

# per-letter (scale, rotation deg, baseline dy, extra kern before)
LETTERS = {
    "P": (1.16, 4.0, 0.015, 0.0),
    "a": (1.02, -4.0, -0.01, -0.035),
    "w": (1.02, 3.0, 0.008, -0.04),
    "T": (1.16, -4.0, 0.02, 0.0),
    "i": (1.02, 3.0, -0.012, -0.045),
    "m": (1.02, -2.5, 0.004, -0.035),
    "e": (1.02, 4.5, 0.012, -0.035),
}

# layer geometry (font units, cap height ~0.58 at size 1)
FACE_EXTRUDE, FACE_BEVEL = 0.018, 0.032
SLAB_GROW, SLAB_EXTRUDE, SLAB_BEVEL, SLAB_Z = 0.052, 0.05, 0.024, -0.068
OUTER_GROW, OUTER_EXTRUDE, OUTER_BEVEL, OUTER_Z = 0.074, 0.02, 0.012, -0.12


# ------------------------------------------------------------- helpers ----
def link(ob, parent):
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    return ob


def glyph_curve(text, font):
    cu = bpy.data.curves.new("txt_" + text, "FONT")
    cu.body = text
    cu.font = font
    ob = bpy.data.objects.new("txt_" + text, cu)
    bpy.context.scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.convert(target="CURVE")
    data = ob.data
    bpy.data.objects.remove(ob)
    return data


def spline_pts(s):
    if s.type == "BEZIER":
        return [bp.co.xy for bp in s.bezier_points]
    return [Vector(p.co[:2]) for p in s.points]


def bbox2(pts):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def curve_bbox(cu):
    pts = [p for s in cu.splines for p in spline_pts(s)]
    return bbox2(pts)


def xform_curve(cu, M):
    for s in cu.splines:
        if s.type == "BEZIER":
            for bp in s.bezier_points:
                hl, hr = M @ bp.handle_left, M @ bp.handle_right
                bp.co = M @ bp.co
                bp.handle_left, bp.handle_right = hl, hr
        else:
            for p in s.points:
                v = M @ Vector(p.co[:3])
                p.co = (v.x, v.y, v.z, p.co[3])


def scale_spline(s, k, center):
    for bp in s.bezier_points:
        for attr in ("handle_left", "handle_right", "co"):
            v = getattr(bp, attr)
            setattr(bp, attr, Vector((center.x + (v.x - center.x) * k,
                                      center.y + (v.y - center.y) * k, v.z)))


def add_poly(cu, pts):
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for p, (x, y) in zip(sp.points, pts):
        p.co = (x, y, 0.0, 1.0)
    sp.use_cyclic_u = True
    sp.use_smooth = True
    return sp


def ellipse(cx, cy, rx, ry, rot=0.0, n=64):
    c, s = math.cos(rot), math.sin(rot)
    out = []
    for k in range(n):
        a = 2 * math.pi * k / n
        x, y = rx * math.cos(a), ry * math.sin(a)
        out.append((cx + x * c - y * s, cy + x * s + y * c))
    return out


def rounded_poly(verts, r, n=14):
    """Polygon with every corner filleted by radius r (sampled)."""
    pts = []
    N = len(verts)
    for i in range(N):
        p0, p1, p2 = Vector(verts[i - 1]), Vector(verts[i]), Vector(verts[(i + 1) % N])
        a, b = (p0 - p1).normalized(), (p2 - p1).normalized()
        ang = a.angle(b)
        t = r / math.tan(ang / 2)
        c = p1 + (a + b).normalized() * (r / math.sin(ang / 2))
        s, e = p1 + a * t, p1 + b * t
        a0 = math.atan2(s.y - c.y, s.x - c.x)
        d = math.atan2(e.y - c.y, e.x - c.x) - a0
        while d > math.pi:
            d -= 2 * math.pi
        while d < -math.pi:
            d += 2 * math.pi
        for k in range(n + 1):
            aa = a0 + d * k / n
            pts.append((c.x + r * math.cos(aa), c.y + r * math.sin(aa)))
    return pts


def new_curve(name):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "2D"
    return cu


def make_layer(name, base, mat, extrude, bevel, grow, z, parent, res=8):
    cu = base.copy()
    cu.name = name
    cu.dimensions = "2D"
    cu.fill_mode = "BOTH"
    cu.extrude = extrude
    cu.bevel_mode = "ROUND"
    cu.bevel_depth = bevel
    cu.bevel_resolution = res
    cu.offset = grow - bevel
    cu.resolution_u = 24
    cu.materials.clear()
    cu.materials.append(mat)
    for s in cu.splines:
        s.use_smooth = True
        s.material_index = 0
        if s.type == "BEZIER":
            s.resolution_u = 24
    ob = bpy.data.objects.new(name, cu)
    ob.location.z = z
    return link(ob, parent)


# ------------------------------------------------------------ materials ----
def _sock(node, name, typ, out=False):
    socks = node.outputs if out else node.inputs
    return next(s for s in socks if s.name == name and s.type == typ)


def _maprange(nt, src, a, b, c, d):
    m = nt.nodes.new("ShaderNodeMapRange")
    m.interpolation_type = "SMOOTHSTEP"
    m.clamp = True
    nt.links.new(src, m.inputs["Value"])
    m.inputs["From Min"].default_value = a
    m.inputs["From Max"].default_value = b
    m.inputs["To Min"].default_value = c
    m.inputs["To Max"].default_value = d
    return m.outputs["Result"]


def _mix(nt, fac, a, b):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    for sock, v in ((_sock(m, "Factor", "VALUE"), fac), (_sock(m, "A", "RGBA"), a), (_sock(m, "B", "RGBA"), b)):
        if isinstance(v, bpy.types.NodeSocket):
            nt.links.new(v, sock)
        else:
            sock.default_value = v
    return _sock(m, "Result", "RGBA", out=True)


def enamel_mat(name, top, bot, side, rim, root, yr, rough=0.3, coat=1.0, sheen=0.0, rim_amt=0.55):
    """Face colour graded top->bottom in logo space, bevel gets a light rim, sides go dark."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    tc.object = root
    pos = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], pos.inputs[0])
    nrm = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Normal"], nrm.inputs[0])
    grad = _maprange(nt, pos.outputs["Y"], yr[0], yr[1], 0.0, 1.0)
    col = _mix(nt, grad, srgb(bot), srgb(top))
    r1 = _maprange(nt, nrm.outputs["Z"], 0.45, 0.8, 0.0, 1.0)
    r2 = _maprange(nt, nrm.outputs["Z"], 0.88, 0.985, rim_amt, 0.0)
    rimf = nt.nodes.new("ShaderNodeMath")
    rimf.operation = "MULTIPLY"
    nt.links.new(r1, rimf.inputs[0])
    nt.links.new(r2, rimf.inputs[1])
    col = _mix(nt, rimf.outputs[0], col, srgb(rim))
    sidef = _maprange(nt, nrm.outputs["Z"], 0.05, 0.55, 1.0, 0.0)
    col = _mix(nt, sidef, col, srgb(side))
    nt.links.new(col, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Coat Weight"].default_value = coat
    bsdf.inputs["Coat Roughness"].default_value = 0.06
    bsdf.inputs["Sheen Weight"].default_value = sheen
    bsdf.inputs["Specular IOR Level"].default_value = 0.45
    return m


def simple_mat(name, color, rough=0.3, coat=1.0, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = srgb(color)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = 0.08
    b.inputs["Metallic"].default_value = metallic
    return m


def orb_mat():
    """Warm gold glass orb: bright core, amber rim, clear-coat gloss, self-lit."""
    m = bpy.data.materials.new("orb")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.45
    f = _maprange(nt, lw.outputs["Facing"], 0.0, 1.0, 0.0, 1.0)
    col = _mix(nt, f, srgb("#FFF0B0"), srgb("#F08A1C"))
    nt.links.new(col, b.inputs["Base Color"])
    nt.links.new(col, b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 1.6
    b.inputs["Roughness"].default_value = 0.15
    b.inputs["Coat Weight"].default_value = 1.0
    b.inputs["Coat Roughness"].default_value = 0.02
    return m


# ---------------------------------------------------------------- build ----
def build_wordmark(words_rows, font, V, root, mats, row_gap=0.8, row_shift=0.0):
    """words_rows: list of strings (one per row). Returns (face_curves, extras)."""
    rows = []
    for text in words_rows:
        x = 0.0
        items = []
        for ch in text:
            if ch == " ":
                x += 0.13
                continue
            s, rot, dy, kern = LETTERS[ch]
            cu = glyph_curve(ch, font)
            x0, y0, x1, y1 = curve_bbox(cu)
            x += kern
            c = Vector(((x0 + x1) / 2, (y0 + y1) / 2, 0))
            M = (Matrix.Translation(Vector((x - x0 * s, dy, 0)))
                 @ Matrix.Translation(c * s) @ Matrix.Rotation(math.radians(rot), 4, "Z")
                 @ Matrix.Scale(s, 4) @ Matrix.Translation(-c))
            items.append((ch, cu, M, (x0, y0, x1, y1)))
            x += (x1 - x0) * s
        rows.append((items, x))
    width = max(w for _, w in rows)
    placed = []
    for r, (items, w) in enumerate(rows):
        off = Vector(((width - w) / 2 + (row_shift * (1 if r else -1) if len(rows) > 1 else 0),
                      -r * row_gap, 0))
        for ch, cu, M, bb in items:
            placed.append((ch, cu, Matrix.Translation(off) @ M, bb))
    return placed


def customize(ch, cu, M, bb, V, root, mats, big_ears=False):
    """Letter-specific crafted details. Operates in glyph space, then M bakes into logo space."""
    extras = []  # (curve, kind)
    x0, y0, x1, y1 = bb
    if ch == "i":
        # drop the tittle; the glass orb sits in its navy seat instead
        dot = max(cu.splines, key=lambda s: bbox2(spline_pts(s))[1])
        dx0, dy0, dx1, dy1 = bbox2(spline_pts(dot))
        extras.append(("orb", Vector(((dx0 + dx1) / 2, (dy0 + dy1) / 2 + 0.01, 0)), (dx1 - dx0) * 0.62))
        seat = cu.copy()
        cu.splines.remove(dot)
        extras.append(("seat", seat))
    if ch == "a":
        # enlarge the bowl counter so a toe-bean paw pad can live in it
        hole = min(cu.splines, key=lambda s: (lambda b: (b[2] - b[0]) * (b[3] - b[1]))(bbox2(spline_pts(s))))
        hx0, hy0, hx1, hy1 = bbox2(spline_pts(hole))
        hc = Vector(((hx0 + hx1) / 2 + 0.004, (hy0 + hy1) / 2 + 0.004, 0))
        scale_spline(hole, 1.28, hc)
        k = 0.052
        paw = new_curve("paw")
        add_poly(paw, rounded_poly([(-0.95, -0.55), (0.95, -0.55), (0.0, 0.45)], 0.42))
        for tx, ty, rr in ((-1.05, 0.55, 0.3), (-0.36, 1.02, 0.1), (0.36, 1.02, -0.1), (1.05, 0.55, -0.3)):
            add_poly(paw, ellipse(tx, ty, 0.27, 0.34, rr))
        xform_curve(paw, Matrix.Translation(hc + Vector((0, -0.004, 0))) @ Matrix.Scale(k, 4))
        extras.append(("paw", paw))
    if ch == "P":
        # two cat ears (same silhouette as the cat-ghosts) peeking over the P
        h = 0.2 if big_ears else 0.165
        w = 0.19 if big_ears else 0.16
        for ex, tilt in ((x0 + 0.1, 16.0), (x0 + 0.33, -14.0)):
            ear = new_curve("ear")
            add_poly(ear, rounded_poly([(-w / 2, 0), (w / 2, 0), (0.0, h)], 0.035))
            inner = new_curve("ear_in")
            add_poly(inner, rounded_poly([(-w * 0.24, 0.035), (w * 0.24, 0.035), (0.0, h * 0.72)], 0.02))
            E = Matrix.Translation(Vector((ex, y1 - 0.075, 0))) @ Matrix.Rotation(math.radians(tilt), 4, "Z")
            xform_curve(ear, E)
            xform_curve(inner, E)
            extras.append(("ear", ear))
            extras.append(("ear_in", inner))
    return extras


def build_scene(V, with_ja=False):
    scene = bpy.context.scene
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    font = bpy.data.fonts.load(FONT, check_existing=True)

    wob = bpy.data.objects.new("Wobble", None)
    scene.collection.objects.link(wob)
    root = bpy.data.objects.new("LogoRoot", None)
    link(root, wob)
    root.rotation_euler.x = math.radians(TILT_DEG)

    rows = ["Paw", "Time"] if V["layout"] == "stack" else ["Paw Time"]
    placed = build_wordmark(rows, font, V, root, None, row_gap=0.66, row_shift=0.12)

    # vertical extent of the wordmark for the top->bottom gradient
    ys = []
    for _, cu, M, bb in placed:
        ys += [bb[1] * 1, bb[3]]
    ymin = min((M @ Vector((0, bb[1], 0))).y for _, _, M, bb in placed) - 0.03
    ymax = max((M @ Vector((0, bb[3], 0))).y for _, _, M, bb in placed) + 0.12

    face_m = enamel_mat("face", V["face_top"], V["face_bot"], V["face_side"], V["face_rim"], root,
                        (ymin, ymax), V["face_rough"], V["face_coat"], V["face_sheen"])
    slab_m = enamel_mat("slab", V["slab_top"], V["slab_bot"], V["slab_side"], V["slab_rim"], root,
                        (ymin, ymax), 0.3, 1.0, 0.0, rim_amt=0.35)
    pink_m = simple_mat("pink", "#F7A4B8", rough=0.35, coat=0.8)
    outer_m = simple_mat("gold", "#E8B04C", rough=0.22, coat=0.4, metallic=0.85)

    logo_objs = []
    for idx, (ch, cu, M, bb) in enumerate(placed):
        extras = customize(ch, cu, M, bb, V, root, None, big_ears=V["layout"] == "stack")
        xform_curve(cu, M)
        slab_src = cu
        for e in extras:
            if e[0] != "orb":
                xform_curve(e[1], M)
            if e[0] == "seat":
                slab_src = e[1]
        jz = idx * 0.0007
        logo_objs.append(make_layer(f"face_{idx}_{ch}", cu, face_m, FACE_EXTRUDE, FACE_BEVEL, 0.0, 0.0, root))
        logo_objs.append(make_layer(f"slab_{idx}_{ch}", slab_src, slab_m, SLAB_EXTRUDE, SLAB_BEVEL,
                                    SLAB_GROW, SLAB_Z - jz, root))
        if V["outer"]:
            logo_objs.append(make_layer(f"outer_{idx}_{ch}", slab_src, outer_m, OUTER_EXTRUDE, OUTER_BEVEL,
                                        OUTER_GROW, OUTER_Z - jz, root))
        for e in extras:
            kind = e[0]
            if kind == "ear":
                logo_objs.append(make_layer(f"ear_{idx}", e[1], face_m, FACE_EXTRUDE, FACE_BEVEL, 0.0, -0.012, root))
                logo_objs.append(make_layer(f"earslab_{idx}", e[1], slab_m, SLAB_EXTRUDE, SLAB_BEVEL,
                                            SLAB_GROW, SLAB_Z - jz - 0.0004, root))
                if V["outer"]:
                    logo_objs.append(make_layer(f"earouter_{idx}", e[1], outer_m, OUTER_EXTRUDE, OUTER_BEVEL,
                                                OUTER_GROW, OUTER_Z - jz, root))
            elif kind == "ear_in":
                logo_objs.append(make_layer(f"earin_{idx}", e[1], pink_m, 0.004, 0.012, 0.0, 0.036, root, res=4))
            elif kind == "paw":
                logo_objs.append(make_layer(f"paw_{idx}", e[1], pink_m, 0.006, 0.01, 0.0, -0.004, root, res=4))
            elif kind == "orb":
                c, r = M @ e[1], e[2] * LETTERS["i"][0]
                bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=r)
                orb = bpy.context.active_object
                bpy.ops.object.shade_smooth()
                orb.parent = root
                orb.location = (c.x, c.y, 0.02)
                orb.data.materials.append(orb_mat())
                logo_objs.append(orb)

    if with_ja:
        cu = glyph_curve("パウタイム", font)
        x0, y0, x1, y1 = curve_bbox(cu)
        allx = [v for _, c2, M, bb in placed for v in ((M @ Vector((bb[0], 0, 0))).x, (M @ Vector((bb[2], 0, 0))).x)]
        cx = (min(allx) + max(allx)) / 2
        s = 0.3
        M = (Matrix.Translation(Vector((cx - (x0 + x1) / 2 * s, ymin - 0.1 - y1 * s, 0)))
             @ Matrix.Scale(s, 4))
        xform_curve(cu, M)
        logo_objs.append(make_layer("ja_face", cu, face_m, 0.008, 0.012, 0.0, 0.0, root, res=5))
        logo_objs.append(make_layer("ja_slab", cu, slab_m, 0.02, 0.012, 0.03, -0.03, root, res=5))
    return scene, wob, root, logo_objs


# ----------------------------------------------------------- lighting ----
def area(name, loc, target, size, energy, color="#FFFFFF", size_y=None):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = energy
    ld.color = srgb(color)[:3]
    if size_y:
        ld.shape = "RECTANGLE"
        ld.size, ld.size_y = size, size_y
    else:
        ld.shape = "DISK"
        ld.size = size
    ob = bpy.data.objects.new(name, ld)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    d = Vector(target) - Vector(loc)
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return ob


def setup_lights(cx, cy):
    t = (cx, cy, 0)
    lights = {
        "key": area("Key", (cx - 4.5, cy + 5.0, 7.0), t, 5.0, 2600, "#FFF4E2"),
        "fill": area("Fill", (cx + 6.0, cy - 1.5, 5.0), t, 8.0, 900, "#E4ECFF"),
        "strip": area("Strip", (cx, cy + 4.0, 5.5), t, 10.0, 700, "#FFFFFF", size_y=0.8),
        "rim": area("Rim", (cx + 1.0, cy + 4.5, -3.5), t, 6.0, 2200, "#FFE7C4"),
    }
    world = bpy.data.worlds.new("W")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = srgb("#C9CDE0")
    bg.inputs["Strength"].default_value = 0.35
    return lights


# ---------------------------------------------------------- rendering ----
def setup_render(scene, samples):
    scene.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        scene.cycles.device = "GPU"
    except Exception as ex:  # CPU fallback keeps the script usable elsewhere
        print("GPU setup failed, using CPU:", ex)
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 8
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    for vt in ("AgX", "Standard"):
        try:
            scene.view_settings.view_transform = vt
            break
        except TypeError:
            continue
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass


def world_bbox(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    xs, ys = [], []
    for ob in objs:
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        mw = ev.matrix_world
        for v in me.vertices:
            w = mw @ v.co
            xs.append(w.x)
            ys.append(w.y)
        ev.to_mesh_clear()
    return min(xs), min(ys), max(xs), max(ys)


def setup_camera(scene, bb, width, margin=0.1):
    x0, y0, x1, y1 = bb
    w, h = x1 - x0, y1 - y0
    pad = w * margin
    W, H = w + 2 * pad, h + 2 * pad
    cam_d = bpy.data.cameras.new("Cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = W
    cam_d.sensor_fit = "HORIZONTAL"
    cam = bpy.data.objects.new("Cam", cam_d)
    scene.collection.objects.link(cam)
    cam.location = ((x0 + x1) / 2, (y0 + y1) / 2 - pad * 0.15, 20)
    scene.camera = cam
    scene.render.resolution_x = width
    scene.render.resolution_y = int(round(width * H / W / 2) * 2)
    scene.render.resolution_percentage = 100
    return cam


def main():
    a = parse_args()
    V = VARIANTS[a.variant]
    scene, wob, root, objs = build_scene(V, with_ja=(a.mode == "ja"))
    bpy.context.view_layer.update()
    # framing is always computed from the bare wordmark so all layers align
    bb = world_bbox([o for o in objs if not o.name.startswith("ja_")])
    if a.mode == "ja":
        bb = world_bbox(objs)
    setup_render(scene, a.samples)
    setup_camera(scene, bb, a.width)
    lights = setup_lights((bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2)

    if a.mode == "turntable":
        wob.rotation_euler.y = math.radians(WOBBLE_DEG * math.sin(2 * math.pi * a.frame / 12))
    if a.mode == "shadow":
        bpy.ops.mesh.primitive_plane_add(size=60)
        plane = bpy.context.active_object
        plane.parent = root
        plane.location.z = -0.2
        plane.is_shadow_catcher = True
        for o in objs:
            o.visible_camera = False
        lights["rim"].hide_render = True
        lights["strip"].hide_render = True
        lights["key"].data.size = 3.0
        lights["key"].data.energy = 1800
        lights["fill"].data.energy = 300
    scene.render.filepath = os.path.abspath(a.out)
    bpy.ops.render.render(write_still=True)
    print("WROTE", scene.render.filepath, scene.render.resolution_x, scene.render.resolution_y)


main()
