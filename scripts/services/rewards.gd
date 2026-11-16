extends RefCounted

const STARTING_COINS := 100
const CLEAR_REWARD := 20
const PERFECT_BONUS := 10
const HINT_PRICE := 50
const DAILY_REWARD := 50
const EXTRA_GLASS_PRICE := 500
const VIDEO_REWARD := 20
const MEDALS := [
	["Beginner", 1, 49, "#cd8648"],
	["Amateur", 50, 99, "#939abf"],
	["Professional", 100, 199, "#e5ab38"],
	["Top Player", 200, 299, "#46b3cd"],
	["Superstar", 300, 499, "#ab72f2"],
	["Mega Star", 500, 799, "#f06cad"],
	["Legend", 800, 1000, "#ffa82d"],
]
const ITEMS := [
	{"id": "lavender", "name": "Lavender", "kind": "Theme", "price": 0, "color": Color("#f1edff")},
	{"id": "seafoam", "name": "Seafoam", "kind": "Theme", "price": 80, "color": Color("#daf3ee")},
	{"id": "aqua", "name": "Aqua Glass", "kind": "Rim", "price": 0, "color": Color("#85c6cf")},
	{"id": "rose", "name": "Rose Glass", "kind": "Rim", "price": 60, "color": Color("#db9eb4")},
]


static func stars(moves: int, par: int) -> int:
	if moves <= 0:
		return 0
	if par > 0 and moves <= par:
		return 3
	if par > 0 and moves <= par + 3:
		return 2
	return 1


static func item(id: String) -> Dictionary:
	for entry in ITEMS:
		if entry.id == id:
			return entry
	return {}
