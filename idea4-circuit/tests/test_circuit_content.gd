extends SceneTree
## Contract, mobile copy, and story-graph checks for the authored catalogue.
const Content = preload("res://scripts/circuit_content.gd")
const EFFECT_KEYS: Array = [
	"cash", "rep", "stock", "truck", "fryer", "morale", "loyalty", "fame",
	"relationship", "demand", "quality", "delay", "flag", "clear_flag"
]
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	var catalogues: Dictionary = {
		"venues": Content.VENUES, "recipes": Content.RECIPES, "staff": Content.STAFF,
		"fryers": Content.FRYERS, "trucks": Content.TRUCKS, "stands": Content.STANDS,
		"badges": Content.BADGES, "events": Content.EVENTS
	}
	var minimums: Dictionary = {
		"venues": 12, "recipes": 10, "staff": 14, "fryers": 4, "trucks": 4,
		"stands": 4, "badges": 12, "events": 50
	}
	for catalogue_name: String in catalogues:
		var rows: Array = catalogues[catalogue_name]
		check(rows.size() >= int(minimums[catalogue_name]), catalogue_name + ": enough entries")
		var seen: Dictionary = {}
		for row: Dictionary in rows:
			var id: String = String(row.get("id", ""))
			check(not id.is_empty() and not seen.has(id), catalogue_name + ": unique nonempty id " + id)
			seen[id] = true
			check(Content.find(rows, id) == row, catalogue_name + ": find resolves " + id)
	check(Content.find(Content.VENUES, "missing").is_empty(), "unknown id returns an empty dictionary")

	var venue_fields: Array = ["id", "name", "town", "description", "tagline", "days", "distance", "fee", "demand", "min_rep", "flavor", "tags", "color"]
	for venue: Dictionary in Content.VENUES:
		require_fields(venue, venue_fields)
		check(not Content.find(Content.RECIPES, String(venue.flavor)).is_empty(), String(venue.id) + ": local flavour exists")
		check(int(venue.days) >= 2 and int(venue.days) <= 4, String(venue.id) + ": phone-friendly stay length")
		check(float(venue.fee) < float(venue.demand) * 3.0, String(venue.id) + ": plausible fee at target demand")
	for recipe: Dictionary in Content.RECIPES:
		require_fields(recipe, ["id", "name", "description", "cost", "appeal", "unlock_rep", "tags", "color"])
		check(float(recipe.cost) >= 1.0 and float(recipe.cost) <= 4.0, String(recipe.id) + ": recipe cost bounds")
		check(float(recipe.appeal) >= 0.0 and float(recipe.appeal) <= 20.0, String(recipe.id) + ": appeal bounds")
	check(int(Content.find(Content.RECIPES, "classic").unlock_rep) == 0, "classic starts unlocked")
	for employee: Dictionary in Content.STAFF:
		require_fields(employee, ["id", "name", "role", "skill", "reliability", "kindness", "wage", "trait", "description", "color"])
		check(int(employee.wage) >= 35 and int(employee.wage) <= 100, String(employee.id) + ": wage bounds")
		for rating: String in ["skill", "reliability", "kindness"]:
			check(int(employee[rating]) >= 0 and int(employee[rating]) <= 100, String(employee.id) + ": " + rating + " bounds")
	for tiers: Array in [Content.FRYERS, Content.TRUCKS, Content.STANDS]:
		check(int(tiers[0].cost) == 0, String(tiers[0].id) + ": basic equipment included")
		var prior_capacity: int = 0
		var prior_cost: int = -1
		for tier: Dictionary in tiers:
			require_fields(tier, ["id", "name", "cost", "capacity", "reliability", "description"])
			check(int(tier.capacity) > prior_capacity, String(tier.id) + ": increasing capacity")
			check(int(tier.cost) > prior_cost, String(tier.id) + ": increasing upgrade cost")
			prior_capacity = int(tier.capacity)
			prior_cost = int(tier.cost)
	for badge: Dictionary in Content.BADGES:
		require_fields(badge, ["id", "name", "description", "icon", "color"])

	var produced_flags: Dictionary = {}
	var needed_flags: Dictionary = {}
	var chain_events: int = 0
	var risky_choices: int = 0
	for event: Dictionary in Content.EVENTS:
		require_fields(event, ["id", "title", "body", "tags", "weight", "min_day", "once", "choices"])
		var id: String = String(event.id)
		var choices: Array = event.choices
		check(String(event.body).split(" ", false).size() <= 65, id + ": body fits the phone")
		check(choices.size() >= 3 and choices.size() <= 4, id + ": 3-4 choices")
		check(event.tags.has("travel") or event.tags.has("trading"), id + ": reachable event context")
		check(float(event.weight) > 0.0, id + ": positive event weight")
		var free_choice: bool = false
		var prerequisite: String = String(event.get("requires_flag", ""))
		if not prerequisite.is_empty():
			needed_flags[prerequisite] = id
		if event.tags.has("story"):
			chain_events += 1
			check(bool(event.once), id + ": story stage is never repeated")
		for choice: Dictionary in choices:
			require_fields(choice, ["label", "detail", "result", "effects"])
			var effects: Dictionary = choice.effects
			var risk: Dictionary = choice.get("risk", {})
			var risk_effects: Dictionary = risk.get("effects", {})
			check(String(choice.label).length() <= 28, id + ": short choice label")
			check(String(choice.detail).length() <= 85, id + ": short choice detail")
			check(not String(choice.result).is_empty(), id + ": authored result")
			if float(effects.get("cash", 0)) >= 0 and float(effects.get("stock", 0)) >= 0 and float(risk_effects.get("cash", 0)) >= 0 and float(risk_effects.get("stock", 0)) >= 0:
				free_choice = true
			validate_effects(effects, id)
			if effects.has("flag"):
				produced_flags[String(effects.flag)] = true
			if not prerequisite.is_empty():
				check(String(effects.get("clear_flag", "")) == prerequisite, id + ": clears the consumed prerequisite")
				check(effects.has("flag") and String(effects.flag) != prerequisite, id + ": progresses or concludes the chain")
			if not risk.is_empty():
				risky_choices += 1
				require_fields(risk, ["chance", "effects", "summary"])
				var chance: float = float(risk.chance)
				check(chance > 0.0 and chance < 1.0, id + ": valid probability")
				check(String(choice.detail).contains(str(roundi(chance * 100.0)) + "%"), id + ": risk chance disclosed")
				validate_effects(risk_effects, id + ": risk")
				for equipment: String in ["truck", "fryer"]:
					var improvement: float = float(effects.get(equipment, 0))
					if improvement > 0.0 and float(risk_effects.get(equipment, 0)) < 0.0:
						check(float(event.get("max_" + equipment, 100)) <= 100.0 - improvement, id + ": cancelled improvement cannot become damage at the condition cap")
		check(free_choice, id + ": option remains viable with no money or supplies")
	check(chain_events == 30, "ten authored three-stage stories")
	check(needed_flags.size() == 20, "twenty continuing story stages")
	check(risky_choices >= 8, "enough clearly disclosed risky opportunities")
	for needed_flag: String in needed_flags:
		check(produced_flags.has(needed_flag), String(needed_flags[needed_flag]) + ": prerequisite can be produced")

	if failures.is_empty():
		print("CONTENT PASS: %d checks, %d events, 10 chains, %d risky choices." % [checks, Content.EVENTS.size(), risky_choices])
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("CONTENT FAIL: %d of %d checks failed." % [failures.size(), checks])
		quit(1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func require_fields(row: Dictionary, fields: Array) -> void:
	var id: String = String(row.get("id", row.get("label", "entry")))
	for field: String in fields:
		check(row.has(field), id + ": field " + field)

func validate_effects(effects: Dictionary, id: String) -> void:
	for key: String in effects:
		check(EFFECT_KEYS.has(key), id + ": supported effect " + key)
		if key in ["flag", "clear_flag"]:
			check(effects[key] is String and not String(effects[key]).is_empty(), id + ": nonempty flag value")
		else:
			check(effects[key] is int or effects[key] is float, id + ": numeric effect " + key)
