extends RefCounted
## Local Tickets catalogue. Prices are earned currency; no paid entitlement is implied.

const BUFF_IDS = ["fresh_oil", "freshly_serviced", "good_vibes", "emergency_batter", "rush_contract"]
const SLOTS = ["stand", "operator_gloves", "operator_sleeves", "operator_watch", "counter_tipjar", "counter_bell", "counter_shaker", "counter_packaging", "celebration"]
const DEFAULT_LOADOUT = {
	"stand": "classic", "operator_gloves": "classic_gloves", "operator_sleeves": "classic_sleeves",
	"operator_watch": "classic_watch", "counter_tipjar": "classic_tipjar", "counter_bell": "classic_bell",
	"counter_shaker": "classic_shaker", "counter_packaging": "classic_packaging", "celebration": "celebration_confetti"
}
const SETS = [
	{"id": "neon_midway", "name": "Neon Midway", "description": "Electric pink and teal for an after-dark midway.", "accent": Color("ef6bce"), "tickets": 180},
	{"id": "grandmas_recipe", "name": "Grandma's Recipe", "description": "Warm gingham, soft cream and familiar bakery charm.", "accent": Color("dfa46c"), "tickets": 180},
	{"id": "chrome_carnival", "name": "Chrome Carnival", "description": "Polished silver, bright red and fairground sparkle.", "accent": Color("adc6d3"), "tickets": 220}
]
const PIECES = [
	{"suffix": "gloves", "name": "Gloves", "slot": "operator_gloves", "tickets": 80},
	{"suffix": "sleeves", "name": "Sleeves", "slot": "operator_sleeves", "tickets": 100},
	{"suffix": "watch", "name": "Watch", "slot": "operator_watch", "tickets": 100},
	{"suffix": "tipjar", "name": "Tip Jar", "slot": "counter_tipjar", "tickets": 80},
	{"suffix": "bell", "name": "Bell", "slot": "counter_bell", "tickets": 80},
	{"suffix": "shaker", "name": "Shaker", "slot": "counter_shaker", "tickets": 80},
	{"suffix": "packaging", "name": "Packaging", "slot": "counter_packaging", "tickets": 120}
]
const BUFFS = [
	{"id": "fresh_oil", "name": "Fresh Oil", "description": "Heat 3 regulates at 190°C for one shift.", "tickets": 25},
	{"id": "freshly_serviced", "name": "Freshly Serviced", "description": "+18 donuts between jams for one shift.", "tickets": 30},
	{"id": "good_vibes", "name": "Good Vibes", "description": "+10s patience and +2 appeal per correct order for one shift.", "tickets": 25},
	{"id": "emergency_batter", "name": "Emergency Batter", "description": "One automatic full refill when the hopper empties.", "tickets": 20},
	{"id": "rush_contract", "name": "Rush Contract", "description": "Next shift: +25% correct-sale pay, +15% quota, more customers.", "tickets": 40}
]

static func get_catalog() -> Array:
	var result: Array = []
	for set_item in SETS:
		var stand: Dictionary = set_item.duplicate(true)
		stand.merge({"kind": "cosmetic", "slot": "stand", "set_id": str(set_item.id), "currency": "tickets", "repeatable": false})
		result.append(stand)
		for piece in PIECES:
			result.append({"id": str(set_item.id) + "_" + str(piece.suffix), "name": str(set_item.name) + " " + str(piece.name),
				"description": "A matching %s piece for your %s look." % [str(piece.name).to_lower(), set_item.name],
				"kind": "cosmetic", "slot": piece.slot, "set_id": set_item.id, "accent": set_item.accent,
				"tickets": piece.tickets, "currency": "tickets", "repeatable": false})
	for celebration in [
		{"id": "celebration_confetti", "name": "Confetti", "description": "A colorful paper celebration.", "tickets": 0},
		{"id": "celebration_tickets", "name": "Ticket Shower", "description": "Celebrate service with fluttering fairground tickets.", "tickets": 120},
		{"id": "celebration_fireworks", "name": "Fireworks", "description": "A bright carnival burst for a job well done.", "tickets": 200}
	]:
		var item: Dictionary = celebration.duplicate(true)
		item.merge({"kind": "cosmetic", "slot": "celebration", "currency": "tickets", "repeatable": false})
		result.append(item)
	for buff in BUFFS:
		var item: Dictionary = buff.duplicate(true)
		item.merge({"kind": "buff", "slot": "buff", "currency": "tickets", "repeatable": true, "duration": "next_shift"})
		result.append(item)
	for item in result:
		item["ticket_cost"] = item.tickets
		var slot: String = str(item.slot)
		item["category"] = "buffs" if item.kind == "buff" else ("sets" if slot == "stand" else ("operator" if slot.begins_with("operator_") else ("counter" if slot.begins_with("counter_") else "celebration")))
	return result

static func get_item(id: String) -> Dictionary:
	for item in get_catalog():
		if item.id == id: return item
	return {}

static func is_buff(id: String) -> bool:
	return id in BUFF_IDS

static func default_loadout() -> Dictionary:
	return DEFAULT_LOADOUT.duplicate(true)
