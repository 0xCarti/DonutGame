extends RefCounted
## Upgrade data kept independent from presentation and run state.

const ALL: Dictionary = {
	"sugar_dust": {"name": "Sweet dividends", "description": "Every donut earns 15% more per level.", "cost": 12, "max_level": 3, "category": "VALUE", "symbol": "+15%"},
	"cinnamon_king": {"name": "Cinnamon royalty", "description": "Cinnamon donuts earn 35% more per level.", "cost": 10, "max_level": 3, "category": "RECIPE", "symbol": "CIN"},
	"snow_day": {"name": "Powder money", "description": "Powdered donuts earn 35% more per level.", "cost": 10, "max_level": 3, "category": "RECIPE", "symbol": "POW"},
	"cocoa_crown": {"name": "Cocoa crown", "description": "Cocoa donuts earn 35% more per level.", "cost": 10, "max_level": 3, "category": "RECIPE", "symbol": "COA"},
	"golden_sixth": {"name": "The golden sixth", "description": "Every sixth donut is golden and worth 2.5 times its usual value.", "cost": 16, "max_level": 1, "category": "GOLD", "symbol": "6TH"},
	"golden_glaze": {"name": "24-karat glaze", "description": "Golden donuts gain another +1x value per level. Needs The golden sixth.", "cost": 18, "max_level": 2, "category": "GOLD", "symbol": "24K", "requires": "golden_sixth"},
	"matching_bonus": {"name": "Perfect dozen / 2", "description": "A full tray of one recipe gains +0.6x payout per level (starts at 2x).", "cost": 14, "max_level": 3, "category": "MATCH", "symbol": "6=6"},
	"variety_bonus": {"name": "Pick 'n' mix", "description": "A full mixed tray gains +0.8x payout per level (starts at 1.6x).", "cost": 12, "max_level": 3, "category": "MIX", "symbol": "MIX"},
	"assorted_batter": {"name": "Variety pack", "description": "Each batch swaps two donuts for the other two recipes. Makes full mixed trays automatically.", "cost": 10, "max_level": 1, "category": "MIX", "symbol": "ABC"},
	"echo_box": {"name": "Echo box", "description": "Every third full tray repeats 35% of your previous full-tray payout per level.", "cost": 18, "max_level": 2, "category": "CHAIN", "symbol": "ECHO"},
	"hot_streak": {"name": "Rush hour", "description": "Sell full trays within 7 seconds of each other for +10% per streak step, up to +50% per level.", "cost": 16, "max_level": 2, "category": "CHAIN", "symbol": "RUSH"},
	"quick_cook": {"name": "Hot rod fryer", "description": "Donuts cook and travel 15% faster per level.", "cost": 14, "max_level": 3, "category": "MACHINE", "symbol": "FAST"},
	"turbo_feed": {"name": "Turbo hopper", "description": "Batch loading cooldown drops by half a second per level.", "cost": 10, "max_level": 2, "category": "MACHINE", "symbol": "FEED"},
	"bulk_batter": {"name": "Deep reserves", "description": "Start every shift with 18 extra donuts' worth of batter per level.", "cost": 8, "max_level": 3, "category": "SUPPLY", "symbol": "+18"},
	"frugal_batter": {"name": "Batter saver", "description": "Every fourth batch uses no batter.", "cost": 12, "max_level": 1, "category": "SUPPLY", "symbol": "FREE"},
	"tray_liner": {"name": "Fancy packaging", "description": "All full trays earn 15% more per level, after recipe and set bonuses.", "cost": 14, "max_level": 3, "category": "VALUE", "symbol": "BOX"},
	"quick_sale": {"name": "Snack attack", "description": "Partial trays earn 35% more per level. Useful when time or tray space is tight.", "cost": 8, "max_level": 2, "category": "VALUE", "symbol": "SNACK"},
	"comeback": {"name": "Opening special", "description": "The first three full trays of each shift earn 40% more per level.", "cost": 12, "max_level": 2, "category": "RUSH", "symbol": "OPEN"},
	"closing_time": {"name": "Last call", "description": "All sales in the final 15 seconds earn 50% more per level.", "cost": 12, "max_level": 2, "category": "RUSH", "symbol": "LATE"},
	"spare_seconds": {"name": "Overtime permit", "description": "Each shift lasts 8 seconds longer per level.", "cost": 16, "max_level": 2, "category": "MACHINE", "symbol": "+8s"},
}


static func price(id: String, current_level: int) -> int:
	if not ALL.has(id):
		return 0
	return int(ceil(float(ALL[id]["cost"]) * (1.0 + float(current_level) * 0.65)))


static func describe(id: String, current_level: int) -> Dictionary:
	if not ALL.has(id):
		return {}
	var result: Dictionary = ALL[id].duplicate(true)
	result["id"] = id
	result["level"] = current_level
	result["cost"] = price(id, current_level)
	return result
