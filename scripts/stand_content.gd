extends RefCounted
## Campaign and earned equipment content. No payments or entitlements.

const SHIFTS: Array[Dictionary] = [
	{"name": "Opening Day", "description": "Learn your rhythm with a patient morning crowd. The first orders are a cinnamon bag, a powdered bag, then a cinnamon bucket.", "target": 110, "duration": 105.0, "arrival": 15.0, "patience": 56.0, "bucket_chance": 0.35, "jam_interval": 27, "modifiers": ["Patient morning customers", "First three orders introduce the counter"]},
	{"name": "Powdered Parade", "description": "Powdered sugar is the fair's favourite today. Powdered orders pay $2 extra.", "target": 175, "duration": 110.0, "arrival": 12.0, "patience": 51.0, "bucket_chance": 0.40, "powder_chance": 0.75, "powder_premium": 2.0, "jam_interval": 27, "modifiers": ["Mostly powdered orders", "+$2 on powdered orders"]},
	{"name": "Family Afternoon", "description": "Families are sharing buckets. More large orders, and bucket customers wait 12 seconds longer than bag customers.", "target": 250, "duration": 115.0, "arrival": 10.5, "patience": 48.0, "bucket_chance": 0.65, "bucket_patience": 12.0, "jam_interval": 28, "modifiers": ["More bucket orders", "Buckets get 12 extra seconds of patience"]},
	{"name": "Sunset Sprint", "description": "The midway is getting busy. Finish an order within 14 seconds of arrival to earn a $2 rush tip.", "target": 330, "duration": 120.0, "arrival": 9.2, "patience": 45.0, "bucket_chance": 0.45, "rush_tip": 2.0, "jam_interval": 28, "modifiers": ["Faster arrivals", "+$2 for service within 14 seconds"]},
	{"name": "Main Stage Break", "description": "Customers arrive in short waves between performances. Serving while all three queue places are occupied earns a $2 crowd tip.", "target": 420, "duration": 125.0, "arrival": 8.4, "patience": 43.0, "bucket_chance": 0.50, "waves": true, "crowd_tip": 2.0, "jam_interval": 29, "modifiers": ["Predictable waves of arrivals", "+$2 while the queue is full"]},
	{"name": "Fireworks Finale", "description": "One last rush before the fireworks. Every order pays $2 extra, and service in the final 30 seconds earns another $3 tip.", "target": 520, "duration": 130.0, "arrival": 7.8, "patience": 42.0, "bucket_chance": 0.60, "menu_premium": 2.0, "closing_tip": 3.0, "jam_interval": 29, "modifiers": ["+$2 on every order", "+$3 tips in the final 30 seconds"]},
]

const UPGRADES: Dictionary = {
	"wide_scoop": {"name": "Bigger Scoop", "description": "Carry 4 donuts per scoop. Buckets need three scoops instead of four. Unlocks the Deep Scoop.", "cost": 18, "max_level": 1, "category": "HANDLING"},
	"deep_scoop": {"name": "Deep Scoop", "description": "Carry 6 donuts per scoop: one scoop for a bag, two for a bucket. Requires Bigger Scoop.", "cost": 24, "max_level": 1, "category": "HANDLING", "requires": "wide_scoop"},
	"fast_motor": {"name": "Fresh Off the Fryer", "description": "The machine produces donuts 15% faster per level. Pair with a bigger scoop and batter hopper.", "cost": 16, "max_level": 2, "category": "MACHINE"},
	"large_hopper": {"name": "Deep Batter Hopper", "description": "Hold and start with 30 more batter per level. Refills restore the larger capacity.", "cost": 14, "max_level": 2, "category": "SUPPLY"},
	"extra_tray": {"name": "Bigger Catch Tray", "description": "Store 12 more cooked donuts and start with 6 more per level. A buffer while you serve or repair.", "cost": 12, "max_level": 2, "category": "SUPPLY"},
	"opening_stock": {"name": "Morning Prep", "description": "Start each shift with 12 extra cooked donuts. Gives you time to handle the first crowd.", "cost": 13, "max_level": 1, "category": "SUPPLY"},
	"easy_repair": {"name": "Quick-Release Guard", "description": "Repair and preventive service take 35% less time. Partial hold progress is always kept.", "cost": 14, "max_level": 1, "category": "MAINTENANCE"},
	"steady_feed": {"name": "Smooth Feeder", "description": "Make 10 more donuts between jams. The feed-risk gauge still warns before trouble.", "cost": 18, "max_level": 1, "category": "MAINTENANCE"},
	"quick_refill": {"name": "Easy-Pour Batter", "description": "Refill in 1.2 seconds instead of 2. Works with the Deep Batter Hopper.", "cost": 14, "max_level": 1, "category": "MAINTENANCE"},
	"thermostat": {"name": "Smart Thermostat", "description": "Heat setting 3 regulates around 190°C, keeping production brisk without normal overheating. Setting 4 still needs attention.", "cost": 22, "max_level": 1, "category": "MACHINE"},
	"calm_queue": {"name": "Friendly Service", "description": "Customers wait 7 seconds longer per level. More patience also preserves their patience tip.", "cost": 15, "max_level": 2, "category": "CUSTOMERS"},
	"warm_welcome": {"name": "Warm Welcome", "description": "The first three customers each shift wait 12 seconds longer and leave a $2 welcome tip.", "cost": 13, "max_level": 1, "category": "CUSTOMERS"},
	"second_chance": {"name": "A Friendly Apology", "description": "A wrong order costs only 1 second of patience instead of 4. Food remains recoverable as usual.", "cost": 10, "max_level": 1, "category": "CUSTOMERS"},
	"generous_tips": {"name": "Tip Jar", "description": "Each correct customer leaves one extra dollar per level, on top of all other tips.", "cost": 12, "max_level": 3, "category": "EARNINGS"},
	"rush_tips": {"name": "Express Service", "description": "Serve within 14 seconds of arrival for a $3 tip per level. Bigger scoops make this easier.", "cost": 16, "max_level": 2, "category": "EARNINGS"},
	"loyal_customers": {"name": "Regulars Club", "description": "Every third correctly served customer in an unbroken streak leaves a $5 regulars tip per level.", "cost": 16, "max_level": 2, "category": "STREAK"},
	"bucket_sign": {"name": "Bucket Special", "description": "Each bucket order earns a $4 extra tip per level. Especially useful during Family Afternoon.", "cost": 15, "max_level": 2, "category": "EARNINGS"},
	"bag_deals": {"name": "Bag Appeal", "description": "Each bag order earns a $2 extra tip per level. Pair with quick, single-scoop bags.", "cost": 12, "max_level": 2, "category": "EARNINGS"},
	"crowd_pleaser": {"name": "Crowd Pleaser", "description": "Serving while all three queue places are occupied earns a $3 crowd tip per level.", "cost": 14, "max_level": 2, "category": "EARNINGS"},
}


static func shift_info(index: int, difficulty: String, mode: String) -> Dictionary:
	var result: Dictionary
	if mode == "endless":
		result = SHIFTS[index % SHIFTS.size()].duplicate(true)
		result["name"] = "After Hours %d: %s" % [index + 1, str(result["name"])]
		result["description"] = "Keep the stand open as the fair gets busier. " + str(result["description"])
		result["target"] = 140 + 45 * index + 7 * index * index
		result["duration"] = 110.0 + minf(float(index) * 4.0, 40.0)
		result["arrival"] = maxf(5.8, 11.0 - float(index) * 0.5)
		result["patience"] = maxf(27.0, 48.0 - float(index) * 1.4)
		result["bucket_chance"] = 0.45 + minf(float(index) * 0.02, 0.2)
		result["jam_interval"] = 28
		result["waves"] = false
	else:
		result = SHIFTS[clampi(index, 0, SHIFTS.size() - 1)].duplicate(true)
	if difficulty == "relaxed":
		result["target"] = int(ceil(float(result["target"]) * 0.8))
		result["duration"] = float(result["duration"]) * 1.2
		result["arrival"] = float(result["arrival"]) * 1.15
		result["patience"] = float(result["patience"]) * 1.4
		result["jam_interval"] = int(result["jam_interval"]) + 6
	result["difficulty"] = difficulty
	result["mode"] = mode
	result["endless"] = mode == "endless"
	result["display_round"] = index + 1
	result["arrival_interval"] = float(result["arrival"])
	return result
