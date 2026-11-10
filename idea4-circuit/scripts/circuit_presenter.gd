extends RefCounted
## Compact, authored display copy. All outcomes still come from the simulation.
## A risk chip always states both its probability and its numerical consequence.

const TEASERS: Dictionary = {
	"gull_01": "A bold seagull claims your sign. A child names her Duchess.",
	"gull_02": "Duchess keeps her distance. Should your feathered regular join the chalkboard?",
	"gull_03": "An artist offers to paint Duchess. Your unpaid manager demands recognition.",
	"recipe_01": "An old tin holds a fairground recipe and thirty summers of memories.",
	"recipe_02": "An oil stain hides the recipe's mystery spice. Time for a careful experiment?",
	"recipe_03": "The recipe's family visits your stand. What would make a fitting thank-you?",
	"van_01": "Your van rattles on left turns. A mechanic finds a loose bracket.",
	"van_02": "The mechanic's notebook recommends spare parts, regular checks, and excellent soup.",
	"van_03": "A puppet-show van breaks down. You recognise the fault; thirty children await their dragon.",
	"crew_01": "A shy colleague sketches a smarter counter layout. The arrows make sense.",
	"crew_02": "The new layout works. Two colleagues claim the idea; its author stays quiet.",
	"crew_03": "Your crew's notebook overflows with good ideas. Could it become a handbook?",
	"rival_01": "Mara opens another donut stand next door. She offers a friendly handshake.",
	"rival_02": "Mara's delivery reached the wrong fair. Can you spare supplies for her queue?",
	"rival_03": "Mara returns your favour with supplies and a tip about an overflow pitch.",
	"mascot_01": "The vegetable parade needs a turnip. A volunteer offers you the costume.",
	"mascot_02": "The parade makes the paper. Your stand looks lovely behind the giant turnip.",
	"mascot_03": "Three grateful vegetable mascots visit your stand. Their handler offers a photograph.",
	"radio_01": "A tired radio host stops for tea and asks what brought you here.",
	"radio_02": "A warm radio mention sends two new customers your way.",
	"radio_03": "The radio host wants to record your working day: queues, fryers, and fairground lights.",
	"awning_01": "Rain floods the quilt seller's tent. There's room beneath your awning.",
	"awning_02": "The quilt seller brings a thank-you pennant and offers matching bunting.",
	"awning_03": "Rain returns. Friendly traders join their shelters into one cheerful covered lane.",
	"goose_01": "A lost plush goose waits on a bench. Can you find its person?",
	"goose_02": "Captain Honk's family arrives for a joyful, slightly sticky reunion.",
	"goose_03": "A handmade thank-you names your stand a Safe Harbour for Geese.",
	"orchard_01": "A grower offers delicious, oddly shaped apples that the judges overlooked.",
	"orchard_02": "The grower offers another crate. Could your chalkboard tell her orchard's story?",
	"orchard_03": "Your recommendation brought customers to the orchard. The grower returns with thanks.",
	"delivery_damp": "Wet packaging arrives. Take a refund or wait for replacements?",
	"surprise_bus": "A coachful of hungry walkers arrives with only forty minutes to spare.",
	"queue_murmur": "Your queue is losing patience. Three folded receipts aren't much of an order system.",
	"portion_question": "The wider bags look emptier. A regular questions the portion in front of everyone.",
	"price_comparison": "A customer points to a cheaper stall. How do you explain your price?",
	"rain_menu": "Rain blurs your menu. Is today's special cinnamon or submarine?",
	"heat_wave": "The fair swelters. Customers seek shade; your crew needs a breather.",
	"cold_snap": "A chilly breeze arrives. Suddenly, hot donuts smell even more tempting.",
	"gust_warning": "Your awning lifts in the wind. The steward asks everyone to secure their pitch.",
	"fryer_filter": "The fryer slows between batches. Its filter needs attention; your queue needs donuts.",
	"van_light": "Your van has a dead tail light. The bulb is nearby; delivery isn't.",
	"roadworks": "Roadworks block the route. Take the slow diversion or a stranger's uncertain shortcut?",
	"scenic_layby": "A beautiful valley opens ahead. Stop for the view or arrive early?",
	"crew_birthday": "A colleague quietly mentions their birthday. There's still time to make it special.",
	"crew_music": "The crew splits over music. Gentle songs or a toolbox falling downstairs?",
	"crew_tired": "The jokes stop. Tired colleagues snap over a small mistake.",
	"supplier_demo": "A supplier demonstrates gentler fryer cleaning. Could you spare a few minutes?",
	"power_pause": "The electrician pauses your row's power. Your fryer and the carousel take an unexpected break.",
	"batch_experiment": "Your experimental batch smells promising. The taste tester calls it memorable.",
	"cider_pairing": "The apple-drink seller suggests sharing customers. Cold cups, warm donuts, good neighbours.",
	"band_interval": "A brass band wants a quick snack before the next march.",
	"chalkboard_artist": "An illustrator offers your menu a little personality. Their teapots are excellent.",
	"smoke_direction": "Your cooking smell drifts into the candle stall. Can you rearrange the pitch?",
	"dancers_order": "Thirty dancers offer a prepaid order. Will you spare the stock from your queue?",
	"photographer": "A photographer loves your glowing stand. Those empty boxes might spoil the shot.",
	"community_award": "The fair offers a prize for welcoming businesses. A volunteer suggests your stand.",
	"toolbox_sale": "A retiring trader sells spare tools. Some look useful; one is a mystery.",
	"route_wall": "Old receipts sketch your season's journey. Fuel, apples, tea, and a growing company.",
	"last_bag": "A tired cleaner arrives near closing. You have a few warm portions left.",
	"coin_tin": "A customer pays with carefully saved coins. Your queue waits while you count.",
	"midway_mist": "Mist softens the lights. Customers drift home. Make one last push or close calmly?"
}

const VENUE_TAGLINES: Dictionary = {
	"willowbank": "Small fair. Warm beginnings.",
	"brass_bell": "Carousel lights and cinnamon nights.",
	"juniper": "Prize hens. Apple-loving crowds.",
	"lantern_quay": "Lemon sugar beside the harbour.",
	"copperfield": "Steam engines and maple mornings.",
	"orchard_days": "Local apples. Loyal families.",
	"cedar_sound": "Late encores. Coffee-fuelled crowds.",
	"moonwheel": "Big wheel. Colourful cravings.",
	"saltwind": "Sea air and salted caramel.",
	"meadow_crown": "Big crowds. Berry favourites.",
	"solstice": "Long sunsets. Bold flavours.",
	"grand_circuit": "The whole circuit comes together."
}

const STAFF_NOTES: Dictionary = {
	"bea": "Remembers every regular's order.",
	"ozzy": "Fries to an imaginary drumbeat.",
	"nell": "Quiet questions. Clever improvements.",
	"ravi": "A patient ear for machinery.",
	"mabel": "Makes every queue feel welcome.",
	"kit": "A spare pen. A perfect count.",
	"dottie": "Turns menus into little masterpieces.",
	"sol": "Perfect batches. Exacting standards.",
	"june": "Makes busy days feel manageable.",
	"pip": "Fast feet. Boundless enthusiasm.",
	"ida": "Always finds the missing pinch.",
	"gus": "Knows the road with the view.",
	"tansy": "A warm welcome for everyone.",
	"mo": "Shines in the final hour."
}

const EFFECT_ORDER: Array[String] = [
	"cash", "stock", "rep", "demand", "delay", "truck", "fryer",
	"quality", "morale", "loyalty", "fame", "relationship"
]
const EFFECT_ICONS: Dictionary = {
	"cash": "cash", "stock": "stock", "rep": "rep", "demand": "crew",
	"delay": "clock", "truck": "truck", "fryer": "fryer", "quality": "star",
	"morale": "heart", "loyalty": "crew", "fame": "star", "relationship": "heart"
}

static func event_teaser(event: Dictionary) -> String:
	return str(TEASERS.get(str(event.get("id", "")), "A new moment on the circuit. How will you handle it?"))

static func venue_tagline(venue: Dictionary) -> String:
	return str(VENUE_TAGLINES.get(str(venue.get("id", "")), "Your next stop awaits."))

static func staff_note(staff: Dictionary) -> String:
	return str(STAFF_NOTES.get(str(staff.get("id", "")), "Another pair of helping hands."))

static func event_art_key(event: Dictionary) -> String:
	var id := str(event.get("id", ""))
	var tags: Array = event.get("tags", [])
	if id.begins_with("van_") or id in ["fryer_filter", "supplier_demo", "power_pause", "toolbox_sale"]:
		return "machine"
	if "staff" in tags or id.begins_with("crew_"):
		return "crew"
	if id.begins_with("awning_") or "weather" in tags or id in ["rain_menu", "heat_wave", "cold_snap", "gust_warning", "midway_mist"]:
		return "weather"
	if "travel" in tags and not "story" in tags:
		return "travel"
	if id in ["surprise_bus", "queue_murmur", "portion_question", "price_comparison", "band_interval", "dancers_order", "last_bag", "coin_tin"]:
		return "customer"
	if "story" in tags:
		return "story"
	return "opportunity"

static func choice_chips(choice: Dictionary) -> Array[Dictionary]:
	var chips: Array[Dictionary] = []
	_append_effects(chips, choice.get("effects", {}))
	var risk: Dictionary = choice.get("risk", {})
	if not risk.is_empty():
		var chance := clampf(float(risk.get("chance", 0)), 0, 1)
		_append_effects(chips, risk.get("effects", {}), chance)
	if chips.is_empty():
		chips.append({"icon": "shield", "label": "No cost", "tone": "neutral"})
	return chips

## Expanded consequence cards. `value` is formatted display text; `amount` is the
## underlying model delta. A chance of -1 means certain. Risk effects are additional
## to the certain effects, not an alternative reward table.
static func choice_effects(choice: Dictionary, context: String = "trading", state: Dictionary = {}) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for source in ["certain", "risk"]:
		var effects: Dictionary = choice.get("effects", {}) if source == "certain" else choice.get("risk", {}).get("effects", {})
		for key in _ordered_numeric_keys(effects):
			var card := _effect_card(key, float(effects[key]), context, state)
			card.source = source
			if source == "risk":
				card.chance = clampf(float(choice.get("risk", {}).get("chance", 0)), 0, 1)
				card.detail = "If the risk happens, additionally: " + str(card.detail)
				card.tone = "risk"
			cards.append(card)
	if cards.is_empty():
		cards.append(_plain_card("shield", "No stat changes", "Story only", "This choice continues the story without changing company stats.", "Immediate"))
	return cards

## Only modifiers that still affect an upcoming sale. Permanent stats are already
## reflected in the company dashboard and are not presented as temporary buffs.
static func active_effects(state: Dictionary) -> Array[Dictionary]:
	var phase := str(state.get("phase", "planning"))
	if phase in ["report", "season_end", "bankrupt"]: return []
	var trading := phase == "event" and str(state.get("event", {}).get("context", "")) == "trading"
	var context := "trading" if trading else "travel"
	var modifiers: Dictionary = state.get("day_modifiers", {})
	var cards: Array[Dictionary] = []
	if trading or bool(state.get("carry_travel_modifiers", false)):
		for key in ["demand", "quality", "delay"]:
			var amount := float(modifiers.get(key, 0))
			if is_zero_approx(amount): continue
			var card := _effect_card(key, amount, context, state)
			card.source = "active"
			cards.append(card)
	if int(state.get("minigame_day", -1)) == int(state.get("day", 0)) and float(state.get("minigame_boost", 0)) > 0:
		cards.append(_practice_card(float(state.minigame_boost), context))
	return cards

## Historical cards show recorded deltas, never the original uncapped promise.
## Reports include the travel effects consumed by that day as well as its decision.
static func outcome_effects(state: Dictionary) -> Array[Dictionary]:
	var outcomes: Array = []
	if str(state.get("phase", "")) == "report":
		outcomes = state.get("last_report", {}).get("event_outcomes", [])
	elif not state.get("last_outcome", {}).is_empty():
		outcomes = [state.last_outcome]
	var cards: Array[Dictionary] = []
	for outcome: Dictionary in outcomes:
		if float(outcome.get("risk_chance", -1)) >= 0:
			var happened := bool(outcome.get("risk_happened", false))
			var risk_card := _plain_card("shield", "Risk happened" if happened else "Risk avoided", "%.0f%% chance" % (float(outcome.risk_chance) * 100), "The extra consequence happened." if happened else "No extra risk penalties were applied.", "Resolved")
			risk_card.key = "risk"
			risk_card.tone = "bad" if happened else "good"
			risk_card.source = "result"
			risk_card["event_title"] = str(outcome.get("title", "Decision"))
			risk_card["choice_label"] = str(outcome.get("choice_label", ""))
			cards.append(risk_card)
		for record: Dictionary in outcome.get("effects", []):
			var key := str(record.key)
			var card := _effect_card(key, float(record.value), str(outcome.context), {})
			card.source = str(record.source)
			card["event_title"] = str(outcome.get("title", "Decision"))
			card["choice_label"] = str(outcome.get("choice_label", ""))
			card["before"] = float(record.before)
			card["after"] = float(record.after)
			card["requested"] = float(record.requested)
			card["consumed"] = bool(outcome.get("consumed", false))
			if key in ["demand", "quality", "delay"] and bool(outcome.get("consumed", false)):
				card.duration = "Used on day %d" % int(outcome.get("consumed_day", outcome.day))
			if key in ["morale", "loyalty"]:
				var members: Array = record.get("members", [])
				card["members"] = members.duplicate(true)
				if members.is_empty():
					card.value = "0 · No hired crew"
					card.detail = "You had no hired employees, so this did not change any stats."
					card.duration = "No effect"
					card.tone = "neutral"
				else:
					var changes: Array[String] = []
					for member in members:
						changes.append("%s %s" % [str(member.name), _signed(float(member.value))])
					card.value = "%s average" % _signed(float(record.value)) if members.size() > 1 else _signed(float(record.value))
					card.detail = ", ".join(changes) + ". " + str(card.detail)
			elif not is_equal_approx(float(record.value), float(record.requested)):
				card.detail = "Actual change after the stat limit. " + str(card.detail)
			if key == "relationship" and not str(record.get("town", "")).is_empty():
				card.detail = str(record.town) + ": " + str(card.detail)
			cards.append(card)
	return cards

## Totals actually used by a trading report, independent of the now-cleared buffs.
static func used_effects(state: Dictionary) -> Array[Dictionary]:
	var report: Dictionary = state.get("last_report", {})
	var cards: Array[Dictionary] = []
	for key in ["demand", "quality", "delay"]:
		var amount := float(report.get("used_modifiers", {}).get(key, 0))
		if is_zero_approx(amount): continue
		var card := _effect_card(key, amount, "trading", {})
		card.duration = "Used on day %d" % int(report.get("day", 0))
		card.source = "used"
		cards.append(card)
	if float(report.get("practice_boost", 0)) > 0:
		var card := _practice_card(float(report.practice_boost), "trading")
		card.duration = "Used on day %d" % int(report.get("day", 0))
		cards.append(card)
	return cards

static func _effect_card(key: String, amount: float, context: String, state: Dictionary) -> Dictionary:
	var duration := "Next trading day" if context == "travel" else "This trading day"
	var card := _plain_card(str(EFFECT_ICONS.get(key, "shield")), key.capitalize(), _signed(amount), "A one-time change to this company stat.", "Permanent")
	card.key = key
	card.amount = amount
	card.tone = "good" if (amount > 0 if key != "delay" else amount < 0) else ("neutral" if is_zero_approx(amount) else "bad")
	match key:
		"cash":
			card.title = "Cash"
			card.value = effect_label("cash", amount)
			card.duration = "Immediate"
			card.detail = "One-off cash change; not a recurring cost or reward."
		"stock":
			card.title = "Stock"
			card.value = _signed(amount) + " portions"
			card.duration = "Immediate"
			card.detail = "Changes stocked portions now, within the van's storage limit."
		"rep":
			card.title = "Reputation"
			card.value = _signed(amount) + " points"
			card.detail = "Stays in your reputation score; other events and reviews can change it. Capped at 0–100."
		"demand":
			card.title = "Customer appeal"
			card.value = _signed(amount * 100) + "%"
			card.duration = duration
			card.detail = "Adds to the customer-appeal multiplier for one trading day. Sales also depend on weather, price, capacity and stock."
		"delay":
			card.title = "Production capacity"
			card.value = _signed(-amount * 100) + "%"
			card.duration = duration
			card.detail = "Reduces the number of portions you can make that day; it does not remove a calendar day. Total loss is capped at 85%."
		"quality":
			card.title = "Batch quality"
			card.value = _signed(amount * 40) + "% appeal"
			card.duration = duration
			card.detail = "%s review reputation; %s%% added customer appeal for that day. Final reputation is capped at 0–100." % [_signed(amount * 2.5), _signed(amount * 40)]
		"truck", "fryer":
			card.title = "Truck condition" if key == "truck" else "Fryer condition"
			card.value = _signed(amount) + " points"
			card.detail = "Condition changes now and stays changed until wear, another event or servicing. Capped at 0–100."
		"morale", "loyalty":
			card.title = "Crew morale" if key == "morale" else "Crew loyalty"
			card.value = _signed(amount) + " per employee"
			card.detail = "Every hired employee, capped at 0–100. Low morale below 40 increases absence risk." if key == "morale" else "Every hired employee, capped at 0–100. Tracks your team bond; there is no direct sales bonus."
			if state.has("staff") and state.staff.is_empty():
				card.value = "0 · No hired crew"
				card.detail = "This normally gives %s to each hired employee. You have none, so it has no effect." % _signed(amount)
				card.duration = "No effect"
				card.tone = "neutral"
		"fame":
			card.title = "Fame"
			card.value = _signed(amount) + " points"
			card.detail = "Adds to your lasting fame; each point contributes 35 to the season score."
		"relationship":
			card.title = "Local goodwill"
			card.value = _signed(amount) + " points"
			card.detail = "Remembers you in this town across seasons. Each point adds 0.4% customer appeal here; capped at -50–100."
	return card

static func _practice_card(amount: float, context: String) -> Dictionary:
	var card := _plain_card("star", "Practice batch", _signed(amount * 100) + "% appeal", "%s review reputation; %s morale for each employee who works. Expires after one trading day." % [_signed(amount * 3), _signed(amount * 5)], "Next trading day" if context == "travel" else "This trading day")
	card.key = "practice"
	card.amount = amount
	card.tone = "good"
	card.source = "active"
	return card

static func _plain_card(icon: String, title: String, value: String, detail: String, duration: String) -> Dictionary:
	return {"icon": icon, "title": title, "value": value, "detail": detail, "duration": duration,
		"tone": "neutral", "chance": -1.0, "key": "story", "amount": 0.0, "source": "certain"}

static func _ordered_numeric_keys(effects: Dictionary) -> Array[String]:
	var keys: Array[String] = EFFECT_ORDER.duplicate()
	for key in effects:
		if str(key) not in keys: keys.append(str(key))
	var valid: Array[String] = []
	for key in keys:
		if effects.has(key) and (effects[key] is float or effects[key] is int) and is_finite(float(effects[key])):
			valid.append(key)
	return valid

static func _append_effects(chips: Array[Dictionary], effects: Dictionary, risk_chance: float = -1) -> void:
	var ordered_keys: Array[String] = EFFECT_ORDER.duplicate()
	# Future numerical effects remain visible even before receiving bespoke display copy.
	for key in effects:
		if str(key) not in ordered_keys and key not in ["flag", "clear_flag"]:
			ordered_keys.append(str(key))
	for key in ordered_keys:
		if not effects.has(key) or not (effects[key] is int or effects[key] is float):
			continue
		var value := float(effects[key])
		if not is_finite(value):
			continue
		var label := effect_label(key, value)
		var good := value > 0 if key != "delay" else value < 0
		var tone := "good" if good else ("bad" if value != 0 else "neutral")
		if risk_chance >= 0:
			label = "%s%% risk: %s" % [_number(risk_chance * 100), label]
			tone = "risk"
		chips.append({"icon": str(EFFECT_ICONS.get(key, "shield")), "label": label, "tone": tone})

static func effect_label(key: String, value: float) -> String:
	match key:
		"cash": return ("+" if value > 0 else ("-" if value < 0 else "")) + "$" + _number(absf(value))
		"stock": return "Stock " + _signed(value)
		"rep": return "Rep " + _signed(value)
		"demand": return "Demand " + _signed(value * 100) + "%"
		"delay": return "Capacity " + _signed(-value * 100) + "%"
		"truck": return "Truck " + _signed(value)
		"fryer": return "Fryer " + _signed(value)
		"quality": return "Quality " + _signed(value)
		"morale": return "Morale " + _signed(value)
		"loyalty": return "Loyalty " + _signed(value)
		"fame": return "Fame " + _signed(value)
		"relationship": return "Local ties " + _signed(value)
	return key.capitalize() + " " + _signed(value)

static func _signed(value: float) -> String:
	return ("+" if value > 0 else "") + _number(value)

static func _number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
