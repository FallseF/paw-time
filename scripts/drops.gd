class_name Drops
## すくった玉の中身：おばけ／島の材料／服。玉の中にヒント（小さな影）を見せ、朝の孵化で明かす。
## 割合は下の W_MATERIAL / W_CLOTH / W_CAT。いまは仮の中身。wardrobe / island-kit のブランチを取り込んだら、下の 2 か所を差しかえるだけでよい：
##   _roll_cloth()    → Wardrobe.random_drop()      grant の cloth → Wardrobe.grant(id)
##   _roll_material() → IslandKit.random_drop()     grant の material → IslandKit.grant_material(id)

## 玉の中身の割合（持ち主の決定：玉はほぼ材料、おばネコはレア）。合計は何でもよい（比で引く）
const W_MATERIAL := 70
const W_CLOTH := 20
const W_CAT := 10
## この夜数のあいだ新しいおばネコがかえらなければ、次の夜のいちばんいい玉をおばネコにする（画面には出さない）
const CAT_PITY_NIGHTS := 7

const MATERIALS := {
	"driftwood": {"name": "流木", "color": Color("b07a4a")},
	"pebble": {"name": "まるい小石", "color": Color("a8a39a")},
	"shell": {"name": "貝がら", "color": Color("ffd9c8")},
	"seaglass": {"name": "シーグラス", "color": Color("8fd8c8")},
	"moss": {"name": "ふかふかの苔", "color": Color("7fb35f")},
}
const CLOTHES := {
	"scarf": {"name": "ちいさなマフラー", "color": Color("e8505b")},
	"ribbon": {"name": "リボン", "color": Color("ff8fb1")},
	"beanie": {"name": "ニット帽", "color": Color("5b6fc2")},
	"bowtie": {"name": "蝶ネクタイ", "color": Color("ffd23f")},
	"apron": {"name": "エプロン", "color": Color("8fd18a")},
}


## 玉ひとつの中身を決める（すくう前、川に浮かんだ時点で決まっている）
## 虹の玉（rare）も同じ割合で引き、材料・服なら「レアの品」にする（tier: rare）。夢の泡・夜の玉はおばネコ。
## 暮らしから来るレア（rares.gd）は玉とは別に決まるので、この割合には入らない。
static func roll(orb_type: String, rare: bool) -> Dictionary:
	if orb_type in ["sleep", "night"]:
		return {"kind": "obake"}
	var r := randi() % (W_MATERIAL + W_CLOTH + W_CAT)
	var c: Dictionary
	if r < W_MATERIAL:
		c = _roll_material()
	elif r < W_MATERIAL + W_CLOTH:
		c = _roll_cloth()
	else:
		return {"kind": "obake"}
	c["tier"] = "rare" if rare else "common"
	return c


static func is_cat(c: Dictionary) -> bool:
	return c.get("kind", "obake") == "obake"


static func _roll_material() -> Dictionary:
	var id: String = MATERIALS.keys().pick_random()
	return {"kind": "material", "id": id}


static func _roll_cloth() -> Dictionary:
	var id: String = CLOTHES.keys().pick_random()
	return {"kind": "cloth", "id": id}


static func info(c: Dictionary) -> Dictionary:
	if c.get("kind", "") == "material":
		return MATERIALS.get(c.id, {"name": c.id, "color": Color.WHITE})
	if c.get("kind", "") == "cloth":
		return CLOTHES.get(c.id, {"name": c.id, "color": Color.WHITE})
	return {}


## 手に入れる。いまは GameState.stash に数を数えるだけ（取り込み後はそれぞれのモジュールへ）
static func grant(c: Dictionary) -> bool:
	var key: String = "%s:%s" % [c.kind, c.id]
	var is_new: bool = not GameState.stash.has(key)
	GameState.stash[key] = int(GameState.stash.get(key, 0)) + 1
	return is_new


## 玉の中に見せる小さな影（材料は木片、服はリボンの輪）。hatch では大きくして出す
static func make_icon(c: Dictionary, glow := false) -> Node3D:
	var n := Node3D.new()
	var col: Color = info(c).get("color", Color.WHITE)
	var m := MeshInstance3D.new()
	if c.kind == "material":
		match c.id:
			"driftwood":
				var cy := CylinderMesh.new()
				cy.top_radius = 0.18
				cy.bottom_radius = 0.22
				cy.height = 1.0
				m.mesh = cy
				m.rotation = Vector3(0.2, 0.5, 1.3)
			"pebble", "moss":
				var sp := SphereMesh.new()
				sp.radius = 0.45
				sp.height = 0.6
				m.mesh = sp
			"shell":
				var sh := SphereMesh.new()
				sh.radius = 0.5
				sh.height = 0.5
				sh.is_hemisphere = true
				m.mesh = sh
				m.rotation = Vector3(-0.4, 0, 0)
			_:
				var b := BoxMesh.new()
				b.size = Vector3(0.6, 0.35, 0.45)
				m.mesh = b
				m.rotation = Vector3(0.3, 0.6, 0.2)
	else:
		var t := TorusMesh.new()
		t.inner_radius = 0.28
		t.outer_radius = 0.48
		m.mesh = t
		m.rotation = Vector3(1.2, 0, 0.3)
		var k := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.16
		s.height = 0.32
		k.mesh = s
		k.material_override = Obake3D.toon(col.darkened(0.15), 0.2)
		n.add_child(k)
	m.material_override = Obake3D.toon(col, 0.25)
	n.add_child(m)
	if glow:
		# 玉の中では、光る影にして、ガラス越しに形が読めるように
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = Kit.glow(col.lightened(0.2), 2.2)
	return n
