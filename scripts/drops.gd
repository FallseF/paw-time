class_name Drops
## すくった玉の中身：おばけ／島の材料／服。玉の中にヒント（小さな影）を見せ、朝の孵化で明かす。
## 割合は下の W_MATERIAL / W_CLOTH / W_CAT。玉の中身を決めるのはここだけ（Wardrobe などは別に引かない）。
##   服   → Wardrobe.random_drop("common"|"rare") で選び、Wardrobe.grant で持ち物に（新しい服は朝の庭で OutfitReveal）
##   材料 → IslandKit.roll_material() で選び、朝に IslandKit.grant_material(id, n)
##   乗り物 → 虹の玉の材料のうち VEHICLE_FROM_RARE の割合で、まだ持っていない乗り物（見た目だけ。速さもごほうびも同じ）

## 玉の中身の割合（持ち主の決定：玉はほぼ材料、おばネコはレア）。合計は何でもよい（比で引く）
const W_MATERIAL := 70
const W_CLOTH := 20
const W_CAT := 10
## この夜数のあいだ新しいおばネコがかえらなければ、次の夜のいちばんいい玉をおばネコにする（画面には出さない）
const CAT_PITY_NIGHTS := 7
## 虹の玉から材料が出るとき、代わりに乗り物になる割合（持っていない乗り物があるときだけ）
const VEHICLE_FROM_RARE := 0.25

## 昔の仮の材料（古いセーブの玉の中身を読むためだけに残す）
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
## 虹の玉（rare）も同じ割合で引き、材料・服なら「レアの品」にする（tier: rare）。満月の夜のちょうちんの玉はおばネコ。
## 暮らしから来るレア（rares.gd）は玉とは別に決まるので、この割合には入らない。
static func roll(orb_type: String, rare: bool) -> Dictionary:
	if orb_type == "night":
		return {"kind": "obake"}
	var r := randi() % (W_MATERIAL + W_CLOTH + W_CAT)
	var c: Dictionary
	if r < W_MATERIAL:
		c = _roll_vehicle() if rare and randf() < VEHICLE_FROM_RARE else {}
		if c.is_empty():
			c = _roll_material()
	elif r < W_MATERIAL + W_CLOTH:
		c = _roll_cloth("rare" if rare else "common")
	else:
		return {"kind": "obake"}
	c["tier"] = "rare" if rare else "common"
	return c


static func is_cat(c: Dictionary) -> bool:
	return c.get("kind", "obake") == "obake"


static func _roll_material() -> Dictionary:
	var m := IslandKit.roll_material()
	return {"kind": "material", "id": m.kind, "n": m.n}


## まだ持っていない乗り物（いかだと見本の有料は除く）。無ければ {}
static func _roll_vehicle() -> Dictionary:
	var pool: Array = []
	for v in Vehicles.LIST:
		if v.id != "raft" and not v.get("premium", false) and not Vehicles.owned().has(v.id):
			pool.append(v.id)
	return {"kind": "vehicle", "id": pool.pick_random()} if not pool.is_empty() else {}


## 服はキセカエの「玉から」の服（持っていない物）。全部そろっていたら材料にする
static func _roll_cloth(rarity := "common") -> Dictionary:
	var id := Wardrobe.random_drop(rarity)
	if id == "":
		return _roll_material()
	return {"kind": "cloth", "id": id}


static func info(c: Dictionary) -> Dictionary:
	if c.get("kind", "") == "material":
		if IslandKit.MATERIALS.has(c.id):
			return {"name": "MAT_" + c.id, "color": Color(IslandKit.MATERIALS[c.id].color)}
		return MATERIALS.get(c.id, {"name": c.id, "color": Color.WHITE})
	if c.get("kind", "") == "vehicle":
		return {"name": "VEH_" + c.id, "color": Color("fff2a8")}
	if c.get("kind", "") == "cloth":
		var it := WardrobeData.item(c.id)
		if not it.is_empty():
			return {"name": it.name, "color": Color(it.c)}
		return CLOTHES.get(c.id, {"name": c.id, "color": Color.WHITE})
	return {}


## 手に入れる。服はキセカエの持ち物へ（新しければ朝の庭で見せる）。材料はいまは GameState.stash に数える
static func grant(c: Dictionary) -> bool:
	# GameState は名前で引く（tests の -s 実行では、自動読み込みより先にこのスクリプトが読まれるため）
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState")
	if c.kind == "cloth" and not WardrobeData.item(c.id).is_empty():
		var got := Wardrobe.grant(c.id)
		if got and gs:
			gs.new_outfits.append(c.id)
		return got
	if c.kind == "material" and IslandKit.MATERIALS.has(c.id):
		var first := IslandKit.count(c.id) == 0
		IslandKit.grant_material(c.id, int(c.get("n", 1)))
		return first
	if c.kind == "vehicle":
		return Vehicles.grant(c.id)
	if gs == null:
		return false
	var key: String = "%s:%s" % [c.kind, c.id]
	var is_new: bool = not gs.stash.has(key)
	gs.stash[key] = int(gs.stash.get(key, 0)) + 1
	return is_new


## 中身の形（OrbContents：材料は本物の小さな形、服は台にのせた服、乗り物）。孵化で大きくして出す。
## glow=true なら、玉の中と同じく自分でほんのり光らせる
static func make_icon(c: Dictionary, glow := false) -> Node3D:
	var n := OrbContents.build(c)
	if glow:
		OrbContents.restyle(n, info(c).get("color", Color.WHITE))
	return n
