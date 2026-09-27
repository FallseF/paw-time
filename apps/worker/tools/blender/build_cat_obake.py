"""Paw Time の猫おばけの体を、切れ目のないなめらかな 1 枚のメッシュとして作り、glTF (.glb) に書き出す。

Blender 5.2 で、画面なしで動かす:
  /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/build_cat_obake.py
  （一部だけ: ... --python tools/blender/build_cat_obake.py -- cat plain）

作り方
  1. 頭（球）・胴・波打つ裾（6 つの丸いふくらみ）・耳を、距離場（SDF）のなめらかな和でひとつの形にする。
  2. 細かく割った立方体を球にふくらませ、耳の向きへ頂点を寄せてから、中心からの光線でその形の表面に写し取る。
  3. サブディビジョンサーフェスを 1 段かけて確定し、もう一度光線で表面に戻す。法線は距離場の勾配から付ける。
  4. 尻尾は曲線に沿った管で、別のメッシュ（Tail）にする。
  5. Cycles で AO（耳の付け根・尻尾の付け根・裾のすき間）を頂点色に焼く。床は置かない。
     頂点色: R = AO（1 で明るい）、G = 1 - 耳の内側の印（粗い目安）、B = 1 - 耳のまわりの印。
     耳の内側のピンクの境目は、シェーダーが同じ距離場を画素ごとに計算してなめらかに描く（B の範囲だけ）。
     色を持たない部品は白 = AO なし・耳なしになる。
  6. UV は SphereMesh と同じ向き（u は正面 +Z から +X へ回る、v は上 0・下 1）。

座標は Godot の向きで組む（y が上、正面が +Z、足元が y=0、頭は中心 y=0.5・半径 0.5）。
Blender へは (x, -z, y) で渡し、glTF の書き出しで元の向きに戻る。
"""

import math
import os
import sys

import bmesh
import bpy
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

VARIANTS = {
    # 基本の猫おばけ（頭 r0.5 / 中心 y0.5 は Obake3D.face() の置き場所と合わせてある）
    "cat": dict(ears=True, tail=True),
    # 耳も尻尾もない体（雪だるまの下の段・とろけた昼寝など、顔を別に付ける体）
    "plain": dict(ears=False, tail=False),
    # ずんぐり（胴が短く、裾が広い）
    "squat": dict(ears=True, tail=True, body_top=0.45, hem_r=0.6, lobe_lift=0.05),
    # 丸まって眠る子（光る玉の中身）：胴を低く・裾を広げたおもち形に、尻尾を前へぐるりと巻きつける
    # 書き出し先は assets/orb/。curl_lo は遠くの玉用の粗い形（細分なし）
    "curl": dict(ears=True, tail=True, tail_path="wrap", body_top=0.42, body_r=0.54, hem_r=0.68, flare_top=0.34, lobe_amp=0.012, lobe_lift=0.035, out="orb"),
    "curl_lo": dict(ears=True, tail=True, tail_path="wrap", body_top=0.42, body_r=0.54, hem_r=0.68, flare_top=0.34, lobe_amp=0.012, lobe_lift=0.035, out="orb", res=9, subsurf=0),
}

BASE = dict(
    head_y=0.5,
    head_r=0.5,
    body_top=0.55,  # 胴の上端（頭の中に隠れる）
    body_r=0.5,  # 胴の上の太さ（顔の下半分は、この円柱の面に乗る）
    hem_r=0.55,  # 裾の太さ
    lobes=6,  # 裾のふくらみの数
    lobe_amp=0.03,  # ふくらみの張り出し
    lobe_lift=0.07,  # ふくらみの間が持ち上がる高さ
    hem_round=0.13,  # 裾の角の丸み
    neck_blend=0.08,
    flare_top=0.46,  # 裾へ広がり始める高さ
    ears=True,
    tail=True,
    out="models",  # assets/ の下の書き出し先
    res=18,  # 立方体の 1 面の割り数
    subsurf=1,  # 細分の段数
    tail_path="up",  # up = ふわっと上がる / wrap = 裾に沿って前へ巻く
    ear_blend=0.055,
)


# ---------------------------------------------------------------- 距離場


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1.0 - h) + a * h - k * h * (1.0 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


def euler_yxz(rx, ry, rz):
    """Godot の Node3D.rotation と同じ回し方（Y・X・Z の順）の行列"""
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Ry @ Rx @ Rz


def round_cone(p, r1, r2, h):
    """y 軸に沿った、下が半径 r1・上（高さ h）が半径 r2 の丸い円すい（iq の式）"""
    q = np.stack([np.hypot(p[:, 0], p[:, 2]), p[:, 1]], axis=1)
    b = (r1 - r2) / h
    a = math.sqrt(1.0 - b * b)
    k = q[:, 0] * (-b) + q[:, 1] * a
    d_lo = np.linalg.norm(q, axis=1) - r1
    d_hi = np.linalg.norm(q - np.array([0.0, h]), axis=1) - r2
    d_mid = q[:, 0] * a + q[:, 1] * b - r1
    return np.where(k < 0.0, d_lo, np.where(k > a * h, d_hi, d_mid))


class Shape:
    def __init__(self, prm):
        self.p = prm
        self.ears = []
        if prm["ears"]:
            for sx in (-1.0, 1.0):
                R = euler_yxz(-0.12, 0.0, -sx * 0.36)
                center = np.array([sx * 0.265, 0.9, -0.03])
                self.ears.append((R, center))

    def _ear_local(self, pts, R, center):
        return (pts - center) @ R  # 行ベクトルで R^T を掛ける = 耳の向きに戻す

    def ear_sdf(self, pts, R, center):
        loc = self._ear_local(pts, R, center)
        flat = 1.45  # 前後に平たく
        l2 = loc * np.array([1.0, 1.0, flat])
        outer = round_cone(l2 - np.array([0.0, -0.08, 0.0]), 0.155, 0.038, 0.27) / flat
        # 前側を浅くくぼませる（耳の内側）
        inner_p = l2 - np.array([0.0, -0.03, 0.16])
        inner_p[:, 2] += (l2[:, 1] + 0.03) * 0.42  # 先へ行くほど表に寄せる（耳の面に沿わせる）
        inner = round_cone(inner_p, 0.088, 0.016, 0.2) / flat
        return smax(outer, -inner, 0.025), inner, loc

    def body_sdf(self, pts):
        p = self.p
        x, y, z = pts[:, 0], pts[:, 1], pts[:, 2]
        th = np.arctan2(x, z)
        rho = np.hypot(x, z)
        wave = np.cos(p["lobes"] * th)
        yb = p["lobe_lift"] * (0.5 - 0.5 * wave)
        # 裾の底は中ほどが少しへこむ
        yb = yb + 0.035 * np.clip(1.0 - rho / 0.45, 0.0, 1.0) ** 2
        t = np.clip(y / p["flare_top"], 0.0, 1.0)
        t = t * t * (3.0 - 2.0 * t)
        R = p["hem_r"] + (p["body_r"] - p["hem_r"]) * t
        R = R + p["lobe_amp"] * wave * (1.0 - np.clip(y / 0.32, 0.0, 1.0))
        c = p["hem_round"]
        cy = (yb + p["body_top"]) * 0.5
        hy = (p["body_top"] - yb) * 0.5
        qx = rho - R + c
        qy = np.abs(y - cy) - hy + c
        outside = np.hypot(np.maximum(qx, 0.0), np.maximum(qy, 0.0))
        return outside + np.minimum(np.maximum(qx, qy), 0.0) - c

    def sdf(self, pts):
        p = self.p
        head = np.linalg.norm(pts - np.array([0.0, p["head_y"], 0.0]), axis=1) - p["head_r"]
        d = smin(head, self.body_sdf(pts), p["neck_blend"])
        for R, c in self.ears:
            e, _, _ = self.ear_sdf(pts, R, c)
            d = smin(d, e, p["ear_blend"])
        return d

    def grad(self, pts, eps=1e-4):
        g = np.zeros_like(pts)
        for i in range(3):
            o = np.zeros(3)
            o[i] = eps
            g[:, i] = self.sdf(pts + o) - self.sdf(pts - o)
        return g / (2 * eps)

    def normal(self, pts):
        g = self.grad(pts)
        return g / np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-9)

    def project(self, pts, steps=6):
        for _ in range(steps):
            g = self.grad(pts)
            gg = np.maximum((g * g).sum(1, keepdims=True), 1e-9)
            pts = pts - self.sdf(pts)[:, None] * g / gg
        return pts

    def warp_dirs(self, D, center, a=0.7, sig=0.35):
        """耳の先の向きへ、まわりの向きを寄せる（耳に頂点を多く割り当てる）"""
        out = D.copy()
        for R, c in self.ears:
            tip = c + R @ np.array([0.0, 0.2, 0.0])
            de = (tip - center) / np.linalg.norm(tip - center)
            w = a * np.exp(-((D - de) ** 2).sum(1) / sig**2)
            out = out + w[:, None] * (de - D)
        return out / np.linalg.norm(out, axis=1, keepdims=True)

    def ear_region(self, pts):
        """耳のまわり 0..1（シェーダーが耳の内側を計算する範囲の印。頭のほかの所で誤って色が付かないように）"""
        m = np.zeros(len(pts))
        for R, c in self.ears:
            e, _, _ = self.ear_sdf(pts, R, c)
            m = np.maximum(m, np.clip((0.09 - e) / 0.04, 0.0, 1.0))
        return m

    def ear_mask(self, pts):
        """耳の内側（くぼみ）の印 0..1"""
        m = np.zeros(len(pts))
        for R, c in self.ears:
            _, inner, loc = self.ear_sdf(pts, R, c)
            front = np.clip((loc[:, 2] + 0.0) / 0.03, 0.0, 1.0)
            m = np.maximum(m, np.clip((0.018 - inner) / 0.03, 0.0, 1.0) * front)
        return m


# ---------------------------------------------------------------- メッシュ


def cube_sphere(n):
    """立方体の 6 面を n x n の四角に割り、球にふくらませた頂点と面"""
    verts = {}
    vlist = []
    faces = []

    def vid(p):
        key = tuple(np.round(p, 6))
        if key not in verts:
            verts[key] = len(vlist)
            vlist.append(p)
        return verts[key]

    axes = [
        (np.array([1, 0, 0]), np.array([0, 0, -1]), np.array([0, 1, 0])),
        (np.array([-1, 0, 0]), np.array([0, 0, 1]), np.array([0, 1, 0])),
        (np.array([0, 1, 0]), np.array([1, 0, 0]), np.array([0, 0, -1])),
        (np.array([0, -1, 0]), np.array([1, 0, 0]), np.array([0, 0, 1])),
        (np.array([0, 0, 1]), np.array([1, 0, 0]), np.array([0, 1, 0])),
        (np.array([0, 0, -1]), np.array([-1, 0, 0]), np.array([0, 1, 0])),
    ]
    for nrm, u, v in axes:
        ids = [[0] * (n + 1) for _ in range(n + 1)]
        for i in range(n + 1):
            for j in range(n + 1):
                a = -1 + 2 * i / n
                b = -1 + 2 * j / n
                # 角の近くが詰まらないよう、角度でそろえる
                a = math.tan(a * math.pi / 4)
                b = math.tan(b * math.pi / 4)
                p = nrm + u * a + v * b
                ids[i][j] = vid(p / np.linalg.norm(p))
        for i in range(n):
            for j in range(n):
                faces.append([ids[i][j], ids[i + 1][j], ids[i + 1][j + 1], ids[i][j + 1]])
    return np.array(vlist, dtype=float), faces


def shoot_rays(shape, dirs, center):
    """中心から各方向へ進み、表面との交点を二分法で探す"""
    lo = np.zeros(len(dirs))
    hi = np.full(len(dirs), 1.6)
    for _ in range(36):
        mid = (lo + hi) * 0.5
        inside = shape.sdf(center + dirs * mid[:, None]) < 0
        lo = np.where(inside, mid, lo)
        hi = np.where(inside, hi, mid)
    return center + dirs * lo[:, None]


def to_blender(V):
    return np.stack([V[:, 0], -V[:, 2], V[:, 1]], axis=1)


def from_blender(B):
    return np.stack([B[:, 0], B[:, 2], -B[:, 1]], axis=1)


def make_object(name, V, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata(to_blender(V).tolist(), [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def apply_subsurf(ob, levels=1):
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.selected_objects:
        o.select_set(False)
    ob.select_set(True)
    mod = ob.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    mod.quality = 3
    bpy.ops.object.modifier_apply(modifier=mod.name)


def read_verts(ob):
    me = ob.data
    B = np.zeros(len(me.vertices) * 3)
    me.vertices.foreach_get("co", B)
    return from_blender(B.reshape(-1, 3))


def write_verts(ob, V):
    ob.data.vertices.foreach_set("co", to_blender(V).ravel())
    ob.data.update()


def set_normals(ob, N):
    me = ob.data
    for p in me.polygons:
        p.use_smooth = True
    me.normals_split_custom_set_from_vertices(to_blender(N).tolist())


def set_sphere_uv(ob):
    """SphereMesh と同じ向きの UV（u は正面から +X へ回る、v は上 0・下 1）"""
    me = ob.data
    V = read_verts(ob)
    uv = me.uv_layers.new(name="UVMap")
    u_v = (np.arctan2(V[:, 0], V[:, 2]) / (2 * math.pi)) % 1.0
    v_v = np.clip((1.02 - V[:, 1]) / 1.12, 0.0, 1.0)
    for poly in me.polygons:
        ids = [me.loops[li].vertex_index for li in poly.loop_indices]
        us = u_v[ids].copy()
        if us.max() - us.min() > 0.5:
            us[us < 0.5] += 1.0
        for k, li in enumerate(poly.loop_indices):
            # glTF の書き出しで v が 1-v に反転するので先に戻しておく
            uv.data[li].uv = (us[k], 1.0 - v_v[ids[k]])


# ---------------------------------------------------------------- 尻尾


def tail_path_up():
    base = np.array([0.1, 0.22, -0.45])
    pts = [base + np.array([0.0, -0.02, 0.2])]
    for i in range(24):
        t = i / 23.0
        pts.append(base + np.array([math.sin(t * 1.6) * 0.3, t * 0.55, -0.12 * min(1.0, t * 3.0) - math.sin(t * math.pi) * 0.18]))
    return np.array(pts)


def tail_path_wrap():
    """裾のまわりを後ろから右回りに前へ。先は顔の下で少し持ち上がる"""
    pts = [np.array([-0.05, 0.16, -0.38])]
    for i in range(32):
        t = i / 31.0
        a = math.pi + 0.35 - t * (math.pi * 0.95)  # 後ろ（-Z）から右（+X）を回って前（+Z）へ
        r = 0.62 + 0.07 * math.sin(t * math.pi)
        y = 0.1 + 0.03 * math.sin(t * math.pi) + 0.1 * max(0.0, t - 0.8) ** 1.5 * 5.0
        pts.append(np.array([math.sin(a) * r * -1.0, y, math.cos(a) * r]))
    return np.array(pts)


def build_tail(path="up", smooth=True):
    """ふわっと上がる尻尾（up）か、前へ巻きつく尻尾（wrap）。付け根は胴の中に埋め、先はまるく少しふくらませる"""
    P = tail_path_wrap() if path == "wrap" else tail_path_up()
    # 点をなめらかに間引き直す（弧長でそろえる）
    seg = np.linalg.norm(np.diff(P, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    L = s[-1]
    M = 40 if smooth else 18
    ss = np.linspace(0, L, M)
    C = np.stack([np.interp(ss, s, P[:, k]) for k in range(3)], axis=1)
    T = np.gradient(C, axis=0)
    T /= np.linalg.norm(T, axis=1, keepdims=True)
    # 平行移動で枠を運ぶ
    up = np.array([1.0, 0.0, 0.0])
    Nn = [np.cross(T[0], up)]
    Nn[0] /= np.linalg.norm(Nn[0])
    for i in range(1, M):
        n = Nn[-1] - np.dot(Nn[-1], T[i]) * T[i]
        Nn.append(n / np.linalg.norm(n))
    Nn = np.array(Nn)
    Bn = np.cross(T, Nn)
    tt = ss / L

    def radius(t):
        r = 0.088 + (0.066 - 0.088) * min(1.0, t / 0.7)
        r += 0.012 * math.exp(-((t - 0.9) / 0.08) ** 2)  # 先がふわっと太る
        return r

    seg_n = 16 if smooth else 8
    verts = []
    faces = []
    for i in range(M):
        r = radius(tt[i])
        for j in range(seg_n):
            a = 2 * math.pi * j / seg_n
            verts.append(C[i] + (Nn[i] * math.cos(a) + Bn[i] * math.sin(a)) * r)
    for i in range(M - 1):
        for j in range(seg_n):
            a = i * seg_n + j
            b = i * seg_n + (j + 1) % seg_n
            faces.append([a, b, b + seg_n, a + seg_n])
    # 先を半球でふさぐ
    r_end = radius(1.0)
    prev = (M - 1) * seg_n
    rings = 5
    for k in range(1, rings):
        ang = (math.pi / 2) * k / rings
        start = len(verts)
        for j in range(seg_n):
            a = 2 * math.pi * j / seg_n
            off = (Nn[-1] * math.cos(a) + Bn[-1] * math.sin(a)) * r_end * math.cos(ang)
            verts.append(C[-1] + off + T[-1] * r_end * math.sin(ang))
        for j in range(seg_n):
            faces.append([prev + j, prev + (j + 1) % seg_n, start + (j + 1) % seg_n, start + j])
        prev = start
    tip = len(verts)
    verts.append(C[-1] + T[-1] * r_end)
    for j in range(seg_n):
        faces.append([prev + j, prev + (j + 1) % seg_n, tip])
    V = np.array(verts)
    ob = make_object("Tail", V, faces)
    if smooth:
        apply_subsurf(ob, 1)
    me = ob.data
    for p in me.polygons:
        p.use_smooth = True
    # 尻尾の UV：u は周、v は長さ
    uv = me.uv_layers.new(name="UVMap")
    for li in range(len(me.loops)):
        uv.data[li].uv = (0.0, 0.0)
    return ob


# ---------------------------------------------------------------- AO


def bake_ao(objs):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 256
    sc.render.bake.target = "VERTEX_COLORS"
    if sc.world is None:
        sc.world = bpy.data.worlds.new("World")
    sc.world.light_settings.distance = 0.45
    # 床は置かない（浮いているおばけの裾まで汚れないように）。足元の影は Obake3D の接地影が受け持つ
    mat = bpy.data.materials.new("bake")
    for o in objs:
        o.data.materials.append(mat)
        o.data.color_attributes.new("AO", "FLOAT_COLOR", "POINT")
        o.data.color_attributes.active_color_name = "AO"
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.bake(type="AO")
    for o in objs:
        o.data.materials.clear()


def finalize_colors(ob, shape=None):
    """焼いた AO と耳の印を 1 つの頂点色にまとめる"""
    me = ob.data
    ao_attr = me.color_attributes["AO"]
    n = len(me.vertices)
    buf = np.zeros(n * 4)
    ao_attr.data.foreach_get("color", buf)
    ao = buf.reshape(-1, 4)[:, 0]
    # 暗すぎる所をやわらげる（すき間の黒つぶれを防ぐ）
    ao = np.clip(ao, 0.0, 1.0) ** 0.8
    P = read_verts(ob)
    ear = shape.ear_mask(P) if shape is not None else np.zeros(n)
    region = shape.ear_region(P) if shape is not None else np.zeros(n)
    col = np.stack([ao, 1.0 - ear, 1.0 - region, np.ones(n)], axis=1)
    me.color_attributes.remove(ao_attr)
    c = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    c.data.foreach_set("color", col.ravel())
    me.color_attributes.active_color_name = "Col"
    me.color_attributes.render_color_index = me.color_attributes.active_color_index


# ---------------------------------------------------------------- 組み立て


def build(name, over):
    prm = dict(BASE)
    prm.update(over)
    shape = Shape(prm)
    bpy.ops.wm.read_factory_settings(use_empty=True)

    V0, faces = cube_sphere(prm["res"])
    center = np.array([0.0, 0.5, 0.0])
    # 耳のある向きへ頂点を寄せてから、中心から光線を飛ばして表面に写す（耳の先まで形が残る）
    V = shoot_rays(shape, shape.warp_dirs(V0, center), center)
    body = make_object("Body", V, faces)
    if prm["subsurf"] > 0:
        apply_subsurf(body, prm["subsurf"])
    V = read_verts(body)
    dirs = V - center
    V = shoot_rays(shape, dirs / np.linalg.norm(dirs, axis=1, keepdims=True), center)
    write_verts(body, V)
    set_sphere_uv(body)

    objs = [body]
    if prm["tail"]:
        objs.append(build_tail(prm["tail_path"], prm["subsurf"] > 0))
    bake_ao(objs)
    finalize_colors(body, shape)
    set_normals(body, shape.normal(V))
    if prm["tail"]:
        finalize_colors(objs[1])

    out_dir = os.path.join(ROOT, "assets", prm["out"])
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "cat_obake%s.glb" % ("" if name == "cat" else "_" + name))
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_normals=True,
        export_texcoords=True,
        export_vertex_color="ACTIVE",
        export_materials="NONE",
        export_yup=True,
    )
    print("wrote %s  body verts=%d faces=%d" % (path, len(body.data.vertices), len(body.data.polygons)))


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    names = argv or list(VARIANTS)
    for n in names:
        build(n, VARIANTS[n])


main()
