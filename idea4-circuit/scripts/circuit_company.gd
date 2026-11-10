extends RefCounted
## Optional circuit systems. Read helpers never advance the simulation RNG.
const Content = preload("res://scripts/circuit_content.gd")
const CONTRACTS := [
	{"id":"warm_bags", "title":"A bag for everyone", "icon":"bag", "metric":"sold", "goal":250, "cash_reward":120, "decoration":"bunting", "decoration_name":"Festival bunting"},
	{"id":"familiar_roads", "title":"Two towns, one company", "icon":"map", "metric":"stops", "goal":2, "cash_reward":180, "decoration":"route_sign", "decoration_name":"Hand-painted route sign"},
	{"id":"helping_hands", "title":"Small jobs, big difference", "icon":"skill", "metric":"activities", "goal":3, "cash_reward":90, "decoration":"flower_box", "decoration_name":"Counter flower box"},
	{"id":"rainy_fund", "title":"The rainy-day fund", "icon":"cash", "metric":"profit", "goal":1000, "cash_reward":150, "decoration":"golden_lamp", "decoration_name":"Golden counter lamp"},
	{"id":"good_word", "title":"Word gets around", "icon":"rep", "metric":"reputation", "goal":5, "cash_reward":120, "decoration":"review_board", "decoration_name":"Regulars' chalkboard"},
	{"id":"learn_together", "title":"Pass on the craft", "icon":"crew", "metric":"training", "goal":2, "cash_reward":140, "decoration":"crew_frame", "decoration_name":"Crew portrait frame"},
	{"id":"steady_work", "title":"A golden touch", "icon":"star", "metric":"perfect", "goal":3, "cash_reward":125, "decoration":"golden_rosette", "decoration_name":"Golden rosette"},
	{"id":"room_to_grow", "title":"Room to grow", "icon":"upgrade", "metric":"upgrades", "goal":1, "cash_reward":160, "decoration":"striped_awning", "decoration_name":"Striped festival valance"},
]
const METRICS := ["activities", "training", "perfect", "upgrades", "reputation"]
const MOMENTS := {
	"bea":["The regulars' notebook", "Bea has made a page for every familiar face. She wants to share the names with the crew."],
	"ozzy":["The fryer soundtrack", "Ozzy has composed a ridiculous frying rhythm. It is catchy enough that someone is already tapping along."],
	"nell":["A useful little question", "Nell has spotted a simpler way to stack the bags. She would like someone to try it with her."],
	"ravi":["Margaret saves the day", "Ravi's favourite wrench has earned another story. He wants to teach the crew the checks behind it."],
	"mabel":["The voice of the queue", "Mabel has a new welcome for nervous first-time customers. She wants to rehearse it before the rush."],
	"kit":["The mystery of the spare pen", "Kit has counted every box twice. The missing spare pen is, somehow, behind their own ear."],
	"dottie":["Flowers on the chalkboard", "Dottie has a pocket-sized sketch of your stand. There is a tiny painted flower for each employee."],
	"sol":["One small adjustment", "Sol offers to show the crew the difference between a good batch and a great one. The lesson involves serious concentration."],
	"june":["Room to breathe", "June notices everyone rushing past one another. She proposes a quiet check-in before opening."],
	"pip":["Only slightly the wrong tea", "Pip has brought everyone's favourite drink. One is labelled for a person who works at the carousel."],
	"ida":["The missing pinch", "Ida has found a note from her family's orchard kitchen. She thinks the crew would enjoy the story behind it."],
	"gus":["The road with the view", "Gus has marked a lovely picnic lay-by on the map. He insists that the view improves sandwiches."],
	"tansy":["A place at the counter", "Tansy wants every crew member to teach the others one thing they are proud of."],
	"mo":["A note for tomorrow", "Mo has left a thank-you note under the closing checklist. It names something each person did well."],
}

static func absolute_day(s: Dictionary) -> int:
	return (int(s.season) - 1) * 36 + int(s.day)

static func fresh(s: Dictionary, previous: Dictionary = {}) -> Dictionary:
	var metrics: Dictionary = previous.get("metrics", {}).duplicate(true)
	for key in METRICS:
		if not metrics.has(key): metrics[key] = 0.0
	var extension := {"version":1, "metrics":metrics, "baseline":{}, "contracts":[], "decorations":previous.get("decorations", []).duplicate(),
		"itinerary":[], "resolved_activities":[], "crew_cooldowns":previous.get("crew_cooldowns", {}).duplicate(), "crew_counts":previous.get("crew_counts", {}).duplicate(),
		"friendships":previous.get("friendships", {}).duplicate(), "last_activity":{}, "last_crew":{}}
	for key in ["sold", "stops", "profit"]:
		extension.baseline[key] = float(s.stats.get({"sold":"total_sold", "stops":"completed_stops", "profit":"total_profit"}[key], 0))
	for key in METRICS: extension.baseline[key] = float(metrics[key])
	for offset in range(3):
		var definition: Dictionary = CONTRACTS[((int(s.season) - 1) * 3 + offset) % CONTRACTS.size()]
		extension.contracts.append({"id":str(definition.id), "claimed":false})
	return extension

static func contract_offers(s: Dictionary) -> Array:
	var out: Array = []
	for saved in s.circuit.contracts:
		var definition: Dictionary = Content.find(CONTRACTS, str(saved.id)).duplicate(true)
		var metric := str(definition.metric)
		var value: float = float(s.circuit.metrics.get(metric, 0))
		if metric in ["sold", "stops", "profit"]:
			value = float(s.stats[{"sold":"total_sold", "stops":"completed_stops", "profit":"total_profit"}[metric]])
		definition["progress"] = minf(float(definition.goal), maxf(0, value - float(s.circuit.baseline[metric])))
		definition["complete"] = float(definition.progress) >= float(definition.goal)
		definition["claimed"] = bool(saved.claimed)
		definition["season"] = int(s.season)
		definition["description"] = {"sold":"Sell 250 bags", "stops":"Complete two fairground stops", "activities":"Complete three optional activities", "profit":"Earn $1,000 in operating profit", "reputation":"Earn 5 reputation points", "training":"Complete two crew training sessions", "perfect":"Earn at least 90% in three mini-games or delegated activities", "upgrades":"Buy an equipment upgrade"}[metric] + " this season."
		out.append(definition)
	return out

static func activity_offers(s: Dictionary) -> Array:
	if str(s.phase) != "planning": return []
	var out: Array = []
	for target in ["truck", "fryer"]:
		if float(s[target]) <= 75:
			out.append({"kind":"repair", "target":target, "title":"Patch up the " + target, "description":"A short workshop puzzle restores worn equipment.",
				"id":"%d:repair:%s:%d" % [int(s.season), target, int((int(s.day) - 1) / 3)], "self_cost":15.0, "help_cost":70.0,
				"reward_hint":"Restore up to 24 condition. Parts cost $15; a specialist costs $70.", "difficulty":int(s.get(target + "_tier", 0))})
	if not str(s.booked_id).is_empty():
		out.append({"kind":"orders", "target":str(s.booked_id), "title":"Know your regulars", "description":"Remember the illustrated orders before the fair opens.",
			"id":"%d:orders:%s" % [int(s.season), str(s.booked_id)], "self_cost":0.0, "help_cost":40.0,
			"reward_hint":"Up to $35 in pre-order tips and +8% appeal at your next opening.", "difficulty":int(s.stand_tier)})
		out.append({"kind":"inspection", "target":str(s.booked_id), "title":"The opening inspection", "description":"Spot hazards in your stand before the inspection.",
			"id":"%d:inspection:%s" % [int(s.season), str(s.booked_id)], "self_cost":0.0, "help_cost":55.0,
			"reward_hint":"Up to +1.2 reputation and +8 fryer condition. Once at this fair.", "difficulty":int(s.stand_tier)})
	var available: Array = []
	for offer in out:
		if str(offer.id) in s.circuit.resolved_activities: continue
		var best: Dictionary = {}
		var best_score := -1.0
		for person in s.staff:
			if int(person.rested_day) == int(s.day): continue
			var skill_key := "skill" if offer.kind == "repair" else ("kindness" if offer.kind == "orders" else "reliability")
			var score := clampf(0.3 + float(person[skill_key]) * 0.005 + float(person.morale) * 0.001, 0, 0.92)
			if score > best_score:
				best = person
				best_score = score
		offer["seed"] = int(str(offer.id).hash() & 0x7fffffff)
		offer["delegate_id"] = str(best.get("id", ""))
		offer["delegate_name"] = str(best.get("name", "No available crew"))
		offer["delegate_score"] = maxf(0, best_score)
		offer["can_self"] = maxf(0, float(s.cash)) >= float(offer.self_cost)
		offer["can_help"] = maxf(0, float(s.cash)) >= float(offer.help_cost)
		offer["can_delegate"] = not best.is_empty() and bool(offer.can_self)
		offer["delegate_cost"] = float(offer.self_cost)
		offer["delegate_hint"] = "Same parts cost; -2 morale for the helper. Expected quality: %d%%." % int(round(maxf(0, best_score) * 100))
		offer["reason"] = "" if offer.can_self else "Not enough cash for parts."
		available.append(offer)
	return available

static func itinerary(s: Dictionary) -> Array:
	var out: Array = []
	var cursor := int(s.day)
	var current: Dictionary = Content.find(Content.VENUES, str(s.booked_id))
	if not current.is_empty():
		cursor += int(current.days) - int(s.venue_day)
		if str(s.phase) == "event" and str(s.event.get("context", "")) == "travel": cursor += 1
	for id in s.circuit.itinerary:
		var row: Dictionary = Content.find(Content.VENUES, str(id)).duplicate(true)
		row["travel_day"] = cursor
		row["start_day"] = cursor + 1
		row["end_day"] = cursor + int(row.days)
		row["fits"] = int(row.end_day) <= int(s.season_length)
		row["cost"] = float(row.fee) * int(row.days) + ceilf(maxf(20, float(row.distance) * (0.6 - int(s.truck_tier) * 0.045)))
		row["reason"] = "Outside this season" if not row.fits else ("Requires %d reputation to book" % int(row.min_rep) if float(s.rep) < float(row.min_rep) else "Estimated; pay only when booked")
		out.append(row)
		cursor = int(row.end_day) + 1
	return out

static func crew_moments(s: Dictionary) -> Array:
	if str(s.phase) != "planning": return []
	var out: Array = []
	for person in s.staff:
		if int(person.rested_day) == int(s.day): continue
		if absolute_day(s) - int(s.circuit.crew_cooldowns.get(str(person.id), -100)) < 5: continue
		var story: Array = MOMENTS[str(person.id)]
		var count := int(s.circuit.get("crew_counts", {}).get(str(person.id), 0))
		var chapter := count % 3
		var title := str(story[0])
		var body := str(story[1])
		var partner: Dictionary = {}
		for other in s.staff:
			if other.id != person.id and int(other.rested_day) != int(s.day):
				partner = other
				break
		var choices := [
			{"label":"Make time to listen", "detail":"Free · +5 morale, +2 loyalty for " + str(person.name), "cost":0.0, "morale":5.0, "loyalty":2.0, "bond":0.0},
			{"label":"Treat them to a little break", "detail":"$35 · +9 morale, +4 loyalty for " + str(person.name), "cost":35.0, "morale":9.0, "loyalty":4.0, "bond":0.0},
		]
		if not partner.is_empty(): choices.append({"label":"Bring " + str(partner.name) + " along", "detail":"Free · +3 morale each, +12 friendship", "cost":0.0, "morale":3.0, "loyalty":0.0, "bond":12.0})
		if chapter == 1:
			title = "A word about the wages"
			body = str(person.name) + " wants to stay on the circuit, but asks whether their pay can grow with the company."
			if float(person.morale) < 60: body += " They have looked tired lately."
			choices[0] = {"label":"Listen and explain the budget", "detail":"Free · +2 morale, +1 loyalty. Wage unchanged.", "cost":0.0, "morale":2.0, "loyalty":1.0, "bond":0.0}
			var raise_amount := minf(4, maxf(0, 500 - float(person.wage)))
			choices[1] = {"label":"Agree a lasting pay rise", "detail":"+$%.0f wage every trading day · +8 morale, +5 loyalty. No charge today." % raise_amount, "cost":0.0, "morale":8.0, "loyalty":5.0, "bond":0.0, "wage":raise_amount}
			if choices.size() > 2: choices.remove_at(2)
		elif chapter == 2:
			title = "Pass it down the counter"
			body = str(person.name) + " has a little trick to share with the crew."
			if not partner.is_empty():
				var bond := float(s.circuit.friendships.get(friendship_key(str(person.id), str(partner.id)), 0))
				body += " " + str(partner.name) + (" is already waiting with their usual notebook." if bond >= 12 else " would like to learn it.")
			else: body += " A set of training materials would turn the trick into a useful routine."
			choices[0] = {"label":"Let them tell the story", "detail":"Free · +5 morale, +2 loyalty.", "cost":0.0, "morale":5.0, "loyalty":2.0, "bond":0.0}
			choices[1] = {"label":"Get proper training materials", "detail":"$35 · +2 skill, +4 morale, +2 loyalty for " + str(person.name), "cost":35.0, "morale":4.0, "loyalty":2.0, "bond":0.0, "skill":2.0}
			if choices.size() > 2: choices[2] = {"label":"Learn together with " + str(partner.name), "detail":"$25 · +2 skill and morale each, +8 friendship", "cost":25.0, "morale":2.0, "loyalty":0.0, "bond":8.0, "skill":2.0}
		out.append({"id":"%d:%s:%d:%d" % [int(s.season), str(person.id), int(s.circuit.crew_cooldowns.get(str(person.id), -100)), count],
			"title":title, "body":body, "chapter":chapter, "staff_ids":[str(person.id)] if partner.is_empty() else [str(person.id), str(partner.id)], "choices":choices})
		if out.size() >= 2: break
	return out

static func friendship_key(a: String, b: String) -> String:
	return a + ":" + b if a < b else b + ":" + a

static func staff_personality(s: Dictionary, id: String) -> Dictionary:
	var person: Dictionary = Content.find(s.staff, id)
	if person.is_empty(): return {}
	var friends: Array = []
	for other in s.staff:
		if other.id == person.id: continue
		var bond := float(s.circuit.friendships.get(friendship_key(id, str(other.id)), 0))
		if bond > 0: friends.append({"id":str(other.id), "name":str(other.name), "bond":bond, "label":"Close friends" if bond >= 60 else ("Friends" if bond >= 30 else "Getting acquainted")})
	return {"trait":str(person.trait), "mood":"Glowing" if float(person.morale) >= 85 else ("Content" if float(person.morale) >= 60 else ("Tired" if float(person.morale) >= 35 else "Frustrated")), "friends":friends}

static func valid(value, s: Dictionary) -> bool:
	if not value is Dictionary or not number(value.get("version"), 1, 1): return false
	for key in ["metrics", "baseline", "crew_cooldowns", "friendships", "last_activity", "last_crew"]:
		if not value.get(key) is Dictionary: return false
	for key in ["contracts", "decorations", "itinerary", "resolved_activities"]:
		if not value.get(key) is Array: return false
	if value.contracts.size() != 3 or value.itinerary.size() > 3 or value.resolved_activities.size() > 128 or value.decorations.size() > CONTRACTS.size(): return false
	if value.metrics.size() != METRICS.size() or value.baseline.size() != METRICS.size() + 3: return false
	for key in METRICS:
		if not number(value.metrics.get(key), 0, 1000000000): return false
	for key in METRICS + ["sold", "stops", "profit"]:
		if not number(value.baseline.get(key), -1000000000, 1000000000): return false
	var ids: Array = []
	for c in value.contracts:
		if not c is Dictionary or not c.get("id") is String or Content.find(CONTRACTS, str(c.id)).is_empty() or c.id in ids or not c.get("claimed") is bool: return false
		ids.append(c.id)
	ids.clear()
	for id in value.itinerary:
		if not id is String or id in ids or Content.find(Content.VENUES, id).is_empty() or id in s.completed or id == str(s.booked_id): return false
		ids.append(id)
	ids.clear()
	for id in value.resolved_activities:
		if not id is String or id.length() > 100 or id in ids: return false
		ids.append(id)
	ids.clear()
	for id in value.decorations:
		var known := false
		for c in CONTRACTS:
			if c.decoration == id: known = true
		if not id is String or not known or id in ids: return false
		ids.append(id)
	if value.crew_cooldowns.size() > Content.STAFF.size() or value.friendships.size() > 10: return false
	if value.has("crew_counts"):
		if not value.crew_counts is Dictionary or value.crew_counts.size() > Content.STAFF.size(): return false
		for id in value.crew_counts:
			if Content.find(Content.STAFF, str(id)).is_empty() or not number(value.crew_counts[id], 0, 1000000000) or float(value.crew_counts[id]) != floorf(float(value.crew_counts[id])): return false
	for id in value.crew_cooldowns:
		if Content.find(Content.STAFF, str(id)).is_empty() or not number(value.crew_cooldowns[id], 0, absolute_day(s)) or float(value.crew_cooldowns[id]) != floorf(float(value.crew_cooldowns[id])): return false
	for key in value.friendships:
		var parts: PackedStringArray = str(key).split(":")
		if parts.size() != 2 or parts[0] == parts[1] or Content.find(s.staff, parts[0]).is_empty() or Content.find(s.staff, parts[1]).is_empty() or str(key) != friendship_key(parts[0], parts[1]) or not number(value.friendships[key], 0, 100): return false
	if not valid_result(value.last_activity, true) or not valid_result(value.last_crew, false): return false
	return true

static func valid_result(result: Dictionary, activity: bool) -> bool:
	if result.is_empty(): return true
	for key in ["id", "title", "message"]:
		if not result.get(key) is String or str(result[key]).length() > 1000: return false
	if not result.get("effects") is Array or result.effects.size() > 10: return false
	for effect in result.effects:
		if not effect is Dictionary or str(effect.get("key", "")) not in ["cash", "rep", "truck", "fryer", "demand", "morale", "loyalty", "skill", "wage", "friendship"]: return false
		for key in ["before", "after", "value"]:
			if not number(effect.get(key), -1000000000, 1000000000): return false
		if effect.has("staff_id") and not effect.staff_id is String: return false
		if effect.has("name") and not effect.name is String: return false
	if activity:
		if str(result.get("kind", "")) not in ["repair", "orders", "inspection"] or str(result.get("mode", "")) not in ["self", "delegate", "help"] or not number(result.get("score"), 0, 1): return false
		if result.has("cost") and not number(result.cost, 0, 1000): return false
	else:
		if not result.get("staff_ids") is Array or result.staff_ids.size() > 2: return false
		for id in result.staff_ids:
			if not id is String or Content.find(Content.STAFF, id).is_empty(): return false
	return true

static func number(v, low: float, high: float) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) >= low and float(v) <= high
