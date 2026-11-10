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
