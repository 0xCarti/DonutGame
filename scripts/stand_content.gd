extends RefCounted
## Campaign and earned equipment content. No payments or entitlements.

const VENUES: Array[Dictionary] = [
	{"id": "fairground", "name": "The Fairground"},
	{"id": "concert", "name": "The Concert"},
	{"id": "stadium", "name": "The Stadium"},
]
const MACHINES: Array[Dictionary] = [
	{"id": "compact", "name": "Compact", "tray": 36, "hopper": 72, "interval": 1.0, "jam_grace": 0},
	{"id": "twin_lane", "name": "Twin-Lane", "tray": 48, "hopper": 102, "interval": 0.82, "jam_grace": 12},
	{"id": "festival_pro", "name": "Festival Pro", "tray": 60, "hopper": 132, "interval": 0.66, "jam_grace": 24},
]
const BUFFS: Dictionary = {
	"fresh_oil": {"name": "Fresh Oil", "description": "Next shift, heat 3 regulates around 190°C. Heat 4 still needs care."},
	"freshly_serviced": {"name": "Freshly Serviced", "description": "Next shift, produce 18 extra donuts between feeder jams."},
	"good_vibes": {"name": "Good Vibes", "description": "Next shift, customers wait 10 seconds longer and correct service adds 2 extra appeal."},
	"emergency_batter": {"name": "Emergency Batter", "description": "Next shift, an empty hopper automatically refills once."},
	"rush_contract": {"name": "Rush Contract", "description": "Next shift, arrivals are 18% closer together, the quota is 15% higher, and correct orders pay 25% more."},
}

const SHIFTS: Array[Dictionary] = [
	{"name": "Opening Day", "description": "Learn your rhythm with a patient morning crowd. The first orders are a cinnamon bag, a powdered bag, then a cinnamon bucket.", "target": 110, "duration": 105.0, "arrival": 15.0, "patience": 56.0, "bucket_chance": 0.35, "jam_interval": 27, "modifiers": ["Patient morning customers", "First three orders introduce the counter"]},
	{"name": "Powdered Parade", "description": "Powdered sugar is the fair's favourite today. Powdered orders pay $2 extra.", "target": 175, "duration": 110.0, "arrival": 12.0, "patience": 51.0, "bucket_chance": 0.40, "powder_chance": 0.75, "powder_premium": 2.0, "jam_interval": 27, "modifiers": ["Mostly powdered orders", "+$2 on powdered orders"]},
	{"name": "Family Afternoon", "description": "Families are sharing buckets. More large orders, and bucket customers wait 12 seconds longer than bag customers.", "target": 250, "duration": 115.0, "arrival": 10.5, "patience": 48.0, "bucket_chance": 0.65, "bucket_patience": 12.0, "jam_interval": 28, "modifiers": ["More bucket orders", "Buckets get 12 extra seconds of patience"]},
	{"name": "Sunset Sprint", "description": "The midway is getting busy. Finish an order within 14 seconds of arrival to earn a $2 rush tip.", "target": 330, "duration": 120.0, "arrival": 9.2, "patience": 45.0, "bucket_chance": 0.45, "rush_tip": 2.0, "jam_interval": 28, "modifiers": ["Faster arrivals", "+$2 for service within 14 seconds"]},
	{"name": "Main Stage Break", "description": "Customers arrive in short waves between performances. Serving while all three queue places are occupied earns a $2 crowd tip.", "target": 420, "duration": 150.0, "arrival": 8.4, "patience": 43.0, "bucket_chance": 0.50, "waves": true, "crowd_tip": 2.0, "jam_interval": 29, "modifiers": ["Predictable waves of arrivals", "+$2 while the queue is full"]},
	{"name": "Fireworks Finale", "description": "One last rush before the fireworks. Every order pays $2 extra, and service in the final 30 seconds earns another $3 tip.", "target": 520, "duration": 155.0, "arrival": 7.8, "patience": 42.0, "bucket_chance": 0.60, "menu_premium": 2.0, "closing_tip": 3.0, "jam_interval": 29, "modifiers": ["+$2 on every order", "+$3 tips in the final 30 seconds"]},
	{"name": "Sound Check", "description": "Open the concert stand with your new Twin-Lane fryer. The concert menu pays $4 extra per order.", "target": 480, "duration": 150.0, "arrival": 7.5, "patience": 48.0, "bucket_chance": 0.45, "menu_premium": 4.0, "jam_interval": 29, "modifiers": ["Twin-Lane fryer unlocked", "+$4 concert menu"]},
	{"name": "Opening Act", "description": "Fans favor quick bags before the music starts. A bag earns a $2 opening-act tip.", "target": 510, "duration": 155.0, "arrival": 7.3, "patience": 47.0, "bucket_chance": 0.30, "menu_premium": 4.0, "bag_tip": 2.0, "jam_interval": 29, "modifiers": ["More bags", "+$2 on bag service"]},
	{"name": "Powdered Encore", "description": "Powdered sugar is tonight's special. Powdered orders pay another $3.", "target": 550, "duration": 160.0, "arrival": 7.0, "patience": 46.0, "bucket_chance": 0.50, "powder_chance": 0.75, "menu_premium": 4.0, "powder_premium": 3.0, "jam_interval": 29, "modifiers": ["Mostly powdered orders", "+$3 powdered special"]},
	{"name": "Between Sets", "description": "The crowd approaches in waves. Full-queue service earns a $4 crowd tip.", "target": 590, "duration": 165.0, "arrival": 6.8, "patience": 45.0, "bucket_chance": 0.50, "menu_premium": 4.0, "waves": true, "wave_fast": 5.4, "wave_slow": 8.2, "crowd_tip": 4.0, "jam_interval": 30, "modifiers": ["Intermission waves", "+$4 full-queue tip"]},
	{"name": "Headliner Rush", "description": "Keep the line moving before the headliner. Service within 14 seconds earns a $4 rush tip.", "target": 620, "duration": 170.0, "arrival": 6.6, "patience": 44.0, "bucket_chance": 0.55, "menu_premium": 4.0, "rush_tip": 4.0, "jam_interval": 30, "modifiers": ["Fast arrivals", "+$4 express tip"]},
	{"name": "One More Song", "description": "The final concert rush favors shared buckets. The last 30 seconds pay a $5 encore tip.", "target": 660, "duration": 175.0, "arrival": 6.4, "patience": 44.0, "bucket_chance": 0.65, "menu_premium": 4.0, "closing_tip": 5.0, "jam_interval": 30, "modifiers": ["More shared buckets", "+$5 closing tip"]},
	{"name": "Gates Open", "description": "The Festival Pro is ready for the stadium. Every order earns the $7 stadium menu premium.", "target": 670, "duration": 165.0, "arrival": 6.6, "patience": 47.0, "bucket_chance": 0.50, "menu_premium": 7.0, "jam_interval": 30, "modifiers": ["Festival Pro unlocked", "+$7 stadium menu"]},
	{"name": "First Quarter", "description": "Quick bags keep fans moving to their seats. Each bag earns a $3 tip.", "target": 700, "duration": 170.0, "arrival": 6.4, "patience": 46.0, "bucket_chance": 0.35, "menu_premium": 7.0, "bag_tip": 3.0, "jam_interval": 30, "modifiers": ["More bags", "+$3 on bag service"]},
	{"name": "Team Bucket", "description": "Fans are sharing with their whole row. Buckets get 16 extra seconds of patience and a $3 team tip.", "target": 730, "duration": 175.0, "arrival": 6.2, "patience": 44.0, "bucket_chance": 0.75, "bucket_patience": 16.0, "menu_premium": 7.0, "bucket_tip": 3.0, "jam_interval": 31, "modifiers": ["Mostly buckets", "+$3 bucket tip / +16s patience"]},
	{"name": "Half-Time", "description": "Fans arrive in short waves at the break. A packed queue earns a $5 crowd tip.", "target": 770, "duration": 180.0, "arrival": 6.0, "patience": 43.0, "bucket_chance": 0.55, "menu_premium": 7.0, "waves": true, "wave_fast": 4.8, "wave_slow": 7.0, "crowd_tip": 5.0, "jam_interval": 31, "modifiers": ["Half-time arrival waves", "+$5 full-queue tip"]},
	{"name": "Extra Time", "description": "The game goes long. Fast correct service within 14 seconds earns another $5.", "target": 810, "duration": 185.0, "arrival": 5.8, "patience": 42.0, "bucket_chance": 0.55, "menu_premium": 7.0, "rush_tip": 5.0, "jam_interval": 31, "modifiers": ["Sustained rush", "+$5 express tip"]},
	{"name": "Championship Night", "description": "Finish your tour under the stadium lights. Every order in the final 45 seconds earns a $7 championship tip.", "target": 850, "duration": 190.0, "arrival": 5.6, "patience": 42.0, "bucket_chance": 0.65, "menu_premium": 7.0, "closing_tip": 7.0, "closing_window": 45.0, "jam_interval": 32, "modifiers": ["The final championship rush", "+$7 tips in the final 45 seconds"]},
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
	"second_chance": {"name": "A Friendly Apology", "description": "An imperfect order loses 5 appeal instead of 9. Customers still pay only a fraction of its price.", "cost": 10, "max_level": 1, "category": "CUSTOMERS"},
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
	var venue: Dictionary = VENUES[(index / 6) % VENUES.size()]
	var machine: Dictionary = MACHINES[mini(2, index / 6)]
	result["venue_id"] = venue["id"]
	result["venue_name"] = venue["name"]
	result["venue_shift"] = index % 6 + 1
	result["machine_id"] = machine["id"]
	result["machine_name"] = machine["name"]
	return result
