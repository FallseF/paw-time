"""島の置き物キットのうち、なめらかさが要るもの（地形 3 段・木の葉・岩）を Blender で作り、glTF (.glb) に書き出す。

  /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/build_island_kit.py
  （一部だけ: ... -- terrain canopy）

地形（assets/models/island/terrain_s0..s2.glb）
  高さの場（島の形・砂浜・崖・うしろの丘・ふたつめの小島）から格子を持ち上げ、
  頂点色に 芝・砂・ぬれた砂・岩 を塗り分けて AO を掛ける。芝の上は y=0 の平ら（置き物がそのまま立つ）。
  段 0: ちいさな丸い島 / 段 1: 岸がひろがり、左右のうしろに岩の崖 / 段 2: 右手前に小島（橋でつなぐ）
葉・岩（assets/models/island/*.glb）
  距離場のなめらかな和を、細かく割った球に写し取る（猫おばけの体と同じ作り方）。頂点色 R に AO。

座標は Godot の向き（y が上、正面 +Z）。Blender へは (x, -z, y) で渡す。
"""

import math
import os
import sys

import bpy
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "models", "island")

GRASS = (0.58, 0.80, 0.45)
GRASS2 = (0.47, 0.72, 0.40)
SAND = (0.93, 0.84, 0.64)
WET = (0.78, 0.68, 0.52)
ROCK = (0.62, 0.58, 0.56)
ROCK_DARK = (0.46, 0.42, 0.44)
SEABED = (0x1F / 255, 0x6F / 255, 0x8A / 255)


def srgb_to_lin(c):
    c = np.asarray(c, dtype=float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1.0 - h) + a * h - k * h * (1.0 - h)


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
    for p in me.polygons:
        p.use_smooth = True
    return ob


def read_verts(ob):
    me = ob.data
    B = np.zeros(len(me.vertices) * 3)
    me.vertices.foreach_get("co", B)
    return from_blender(B.reshape(-1, 3))


def bake_ao(objs, distance):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 128
    sc.render.bake.target = "VERTEX_COLORS"
    if sc.world is None:
        sc.world = bpy.data.worlds.new("World")
    sc.world.light_settings.distance = distance
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
    out = []
    for o in objs:
        buf = np.zeros(len(o.data.vertices) * 4)
        o.data.color_attributes["AO"].data.foreach_get("color", buf)
        out.append(buf.reshape(-1, 4)[:, 0])
        o.data.color_attributes.remove(o.data.color_attributes["AO"])
        o.data.materials.clear()
    return out


def set_colors(ob, col):
    me = ob.data
    c = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    rgba = np.concatenate([col, np.ones((len(col), 1))], axis=1)
    c.data.foreach_set("color", rgba.ravel())
    me.color_attributes.active_color_name = "Col"
    me.color_attributes.render_color_index = me.color_attributes.active_color_index


def export(objs, name):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".glb")
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_normals=True,
        export_texcoords=False, export_vertex_color="ACTIVE", export_materials="NONE", export_yup=True,
    )
    print("wrote", path, sum(len(o.data.vertices) for o in objs), "verts")


# ---------------------------------------------------------------- 地形

STAGES = [
    dict(r=3.9, cliffs=False, islet=False),
    dict(r=4.5, cliffs=True, islet=False),
    dict(r=5.0, cliffs=True, islet=True),
]
ISLET = (6.9, 1.4, 1.35)  # 小島の中心 x, z と半径（screen_garden.gd の IslandKit.ISLET と同じ）


def island_dist(x, z, st):
    """島のふちからの距離（内側が負）。まるい島に、ゆるい岬と入り江"""
    th = np.arctan2(z, x)
    r = st["r"] * (1.0 + 0.045 * np.sin(3 * th + 1.1) + 0.03 * np.sin(5 * th + 0.3))
    d = np.hypot(x, z) - r
    # うしろの丘（休憩室が建つ）：z < -2.4 の横長の台
    qx = np.abs(x) - 6.6
    qz = np.abs(z + 5.2) - 2.8
    hill = np.hypot(np.maximum(qx + 1.0, 0), np.maximum(qz + 1.0, 0)) + np.minimum(np.maximum(qx, qz), 0) - 1.3
    d = smin(d, hill, 0.8)
    if st["islet"]:
        ix, iz, ir = ISLET
        th2 = np.arctan2(z - iz, x - ix)
        d2 = np.hypot(x - ix, z - iz) - ir * (1.0 + 0.06 * np.sin(4 * th2))
        d = np.minimum(d, d2)
    return d


def cliff_mask(x, z, st):
    """崖にする岸（左うしろ・右うしろ）"""
    if not st["cliffs"]:
        return np.zeros_like(x)
    th = np.degrees(np.arctan2(z, x))
    m = np.zeros_like(x)
    for c, w in ((-150.0, 28.0), (-35.0, 24.0), (160.0, 16.0)):
        dd = np.abs(((th - c + 180) % 360) - 180)
        m = np.maximum(m, 1.0 - smoothstep(w * 0.6, w, dd))
    # 手前（カメラ側）と丘の上には崖を作らない
    m *= smoothstep(-5.5, -4.0, z) * (1.0 - smoothstep(1.0, 2.5, z))
    return m


def build_terrain(si):
    st = STAGES[si]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    step = 0.1
    xs = np.arange(-8.0, 9.4 + 1e-6, step)
    zs = np.arange(-8.0, 6.8 + 1e-6, step)
    X, Z = np.meshgrid(xs, zs)
    x = X.ravel()
    z = Z.ravel()
    d = island_dist(x, z, st)
    cm = cliff_mask(x, z, st)
    # 砂浜：ふちから外へ 1.0 でなだらかに海の底へ。芝はふちの 0.35 内側まで
    beach = -0.55 * smoothstep(-0.35, 1.2, d)
    # 崖：ふちの内側が少し盛り上がり（岩の台）、外は急に落ちる
    ridge = 0.42 * smoothstep(-1.1, -0.2, d) * (1.0 - smoothstep(-0.05, 0.12, d))
    drop = -0.75 * smoothstep(-0.02, 0.35, d)
    cliff = ridge + drop
    # 岩肌に段をつける
    cliff += 0.05 * np.sin(x * 5.1 + z * 3.3) * smoothstep(-0.3, 0.1, d) * (1.0 - smoothstep(0.2, 0.5, d))
    h = beach * (1.0 - cm) + cliff * cm
    # 芝の上はほぼ平ら（置き物が立つ面は y=0）。ふち近くだけゆるく下げる
    h = np.where(d < -0.35, np.where(cm > 0.01, h, 0.0), h)
    h = np.maximum(h, -0.62)
    V = np.stack([x, h, z], axis=1)
    nx, nz = len(xs), len(zs)
    faces = []
    for j in range(nz - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append([a, a + nx, a + nx + 1, a + 1])  # 上から見て表になる向き（z を反転して渡すので逆回り）
    ob = make_object("Terrain", V, faces)
    # 使わない海の底（深いところ）の面を減らす：全頂点が -0.6 の面を消す
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(ob.data)
    deep = [f for f in bm.faces if all(v.co.z < -0.6 for v in f.verts)]
    bmesh.ops.delete(bm, geom=deep, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()
    V = read_verts(ob)
    x, h, z = V[:, 0], V[:, 1], V[:, 2]
    d = island_dist(x, z, st)
    cm = cliff_mask(x, z, st)
    # 色：芝（2 色のまだら）・砂・ぬれた砂・岩
    noise = 0.5 + 0.5 * np.sin(x * 1.7 + np.sin(z * 1.3) * 2.0) * np.sin(z * 1.9 + np.sin(x * 0.9))
    grass = np.array(GRASS)[None, :] * (1 - noise[:, None] * 0.6) + np.array(GRASS2)[None, :] * (noise[:, None] * 0.6)
    sand = np.array(SAND)[None, :].repeat(len(x), 0)
    wet = np.array(WET)[None, :]
    sand = sand + (wet - sand) * smoothstep(-0.12, -0.3, h)[:, None]
    g_amt = 1.0 - smoothstep(-0.45, -0.25, d)
    col = sand + (grass - sand) * g_amt[:, None]
    rock_t = cm * smoothstep(-0.6, -0.15, d)
    strata = 0.5 + 0.5 * np.sin(h * 38.0)
    rock = np.array(ROCK)[None, :] + (np.array(ROCK_DARK) - np.array(ROCK))[None, :] * strata[:, None] * 0.6
    col = col + (rock - col) * rock_t[:, None]
    # 崖の上の芝は残す
    top = (h > 0.3) & (d < -0.3)
    col[top] = grass[top]
    ao = bake_ao([ob], 0.6)[0]
    ao = np.clip(ao, 0, 1) ** 0.7
    lin = srgb_to_lin(col) * (0.45 + 0.55 * ao)[:, None]
    # 深いところは、海の底の色（screen_garden.gd の深い海の底と同じ）へなじませる
    deep = smoothstep(-0.3, -0.58, h)[:, None]
    lin = lin + (srgb_to_lin(np.array(SEABED))[None, :] - lin) * deep
    set_colors(ob, lin)
    export([ob], "terrain_s%d" % si)


# ---------------------------------------------------------------- 葉・岩（距離場）


def cube_sphere(n):
    verts, vlist, faces = {}, [], []

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
                a = math.tan((-1 + 2 * i / n) * math.pi / 4)
                b = math.tan((-1 + 2 * j / n) * math.pi / 4)
                p = nrm + u * a + v * b
                ids[i][j] = vid(p / np.linalg.norm(p))
        for i in range(n):
            for j in range(n):
                faces.append([ids[i][j], ids[i + 1][j], ids[i + 1][j + 1], ids[i][j + 1]])
    return np.array(vlist, dtype=float), faces


def shoot(sdf, dirs, center, far=3.0):
    lo = np.zeros(len(dirs))
    hi = np.full(len(dirs), far)
    for _ in range(34):
        mid = (lo + hi) * 0.5
        inside = sdf(center + dirs * mid[:, None]) < 0
        lo = np.where(inside, mid, lo)
        hi = np.where(inside, hi, mid)
    return center + dirs * lo[:, None]


def sdf_normals(sdf, P, eps=1e-3):
    g = np.zeros_like(P)
    for i in range(3):
        o = np.zeros(3)
        o[i] = eps
        g[:, i] = sdf(P + o) - sdf(P - o)
    return g / np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-9)


def blob_asset(name, sdf, center, res=14, ao_dist=0.35, far=3.0):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    V0, faces = cube_sphere(res)
    V = shoot(sdf, V0, center, far)
    ob = make_object(name, V, faces)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    mod = ob.modifiers.new("S", "SUBSURF")
    mod.levels = 1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    V = read_verts(ob)
    dirs = V - center
    V = shoot(sdf, dirs / np.linalg.norm(dirs, axis=1, keepdims=True), center, far)
    ob.data.vertices.foreach_set("co", to_blender(V).ravel())
    ob.data.update()
    ob.data.normals_split_custom_set_from_vertices(to_blender(sdf_normals(sdf, V)).tolist())
    ao = bake_ao([ob], ao_dist)[0]
    ao = np.clip(ao, 0, 1) ** 0.8
    # R = AO、G = 1（耳の印なし）、B = 1
    set_colors(ob, np.stack([ao, np.ones_like(ao), np.ones_like(ao)], axis=1))
    export([ob], name)


def spheres_sdf(balls, k):
    def f(p):
        d = None
        for c, r in balls:
            di = np.linalg.norm(p - np.array(c), axis=1) - r
            d = di if d is None else smin(d, di, k)
        return d

    return f


def build_canopies():
    rng = np.random.default_rng(3)
    # まるい木：ふっくらした雲のような葉
    balls = [((0, 0.0, 0), 0.55)]
    for i in range(9):
        a = i / 9 * 2 * math.pi
        y = rng.uniform(-0.12, 0.28)
        balls.append(((math.cos(a) * 0.42, y, math.sin(a) * 0.42), rng.uniform(0.28, 0.36)))
    balls.append(((0, 0.42, 0), 0.34))
    blob_asset("canopy_round", spheres_sdf(balls, 0.14), np.array([0, 0.05, 0]))
    # 桜：横に広く、小さなふくらみが多い
    balls = [((0, 0, 0), 0.5)]
    for i in range(14):
        a = i / 14 * 2 * math.pi + rng.uniform(-0.2, 0.2)
        rr = rng.uniform(0.45, 0.62)
        balls.append(((math.cos(a) * rr, rng.uniform(-0.1, 0.25), math.sin(a) * rr * 0.9), rng.uniform(0.2, 0.28)))
    for i in range(5):
        a = i / 5 * 2 * math.pi
        balls.append(((math.cos(a) * 0.25, 0.35, math.sin(a) * 0.25), 0.24))
    blob_asset("canopy_sakura", spheres_sdf(balls, 0.1), np.array([0, 0.05, 0]))

    # 松：三段の、ふちの丸い円すい
    def pine(p):
        d = None
        for y0, r, h in ((0.0, 0.62, 0.55), (0.38, 0.5, 0.5), (0.72, 0.36, 0.45)):
            q = p - np.array([0, y0, 0])
            rho = np.hypot(q[:, 0], q[:, 2])
            # 円すい（下の半径 r、高さ h）
            k = rho * h / r + q[:, 1] - h
            dd = np.maximum(k * r / math.hypot(r, h), -q[:, 1]) - 0.05
            d = dd if d is None else smin(d, dd, 0.08)
        return d

    blob_asset("canopy_pine", pine, np.array([0, 0.4, 0]), far=2.0)
    # 岩：少しゆがんだ丸石
    balls = [((0, 0, 0), 0.4), ((0.25, -0.05, 0.1), 0.28), ((-0.2, 0.05, -0.1), 0.3)]
    base = spheres_sdf(balls, 0.12)

    def rock(p):
        return base(p) + 0.03 * np.sin(p[:, 0] * 9) * np.sin(p[:, 1] * 7 + 1) * np.sin(p[:, 2] * 8)

    blob_asset("rock", rock, np.array([0, 0, 0]), res=10)


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    what = argv or ["terrain", "canopy"]
    if "terrain" in what:
        for i in range(len(STAGES)):
            build_terrain(i)
    if "canopy" in what:
        build_canopies()


main()
