extends RefCounted

const STARTING_COINS := 100
const CLEAR_REWARD := 20
const PERFECT_BONUS := 10
const HINT_PRICE := 50
const DAILY_REWARD := 40
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
