extends SceneTree

const Presenter = preload("res://scripts/circuit_presenter.gd")
const Content = preload("res://scripts/circuit_content.gd")
const Model = preload("res://scripts/circuit_model.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var valid_icons := ["cash", "rep", "stock", "truck", "fryer", "heart", "star", "clock", "crew", "shield"]
	var valid_art := ["travel", "machine", "customer", "crew", "weather", "opportunity", "story"]
	for event: Dictionary in Content.EVENTS:
		_check(Presenter.TEASERS.has(str(event.id)), "Authored teaser: " + str(event.id))
		var teaser: String = Presenter.event_teaser(event)
		_check(_words(teaser) <= 16 and _words(teaser) >= 5, "Teaser length: " + str(event.id))
		_check(teaser.ends_with(".") or teaser.ends_with("?"), "Teaser is a complete sentence: " + str(event.id))
		_check(Presenter.event_art_key(event) in valid_art, "Artwork for " + str(event.id))
		for choice: Dictionary in event.choices:
			var chips: Array[Dictionary] = Presenter.choice_chips(choice)
			_check(not chips.is_empty(), "Every choice has a concise outcome")
			for chip in chips:
				_check(str(chip.icon) in valid_icons, "Known icon " + str(chip.icon))
				_check(str(chip.tone) in ["good", "bad", "neutral", "risk"], "Known chip tone")
				_check(not "flag" in str(chip.label), "No technical story flags in player text")
			_check_effect_coverage(choice.get("effects", {}), chips, false, 0)
			if choice.has("risk"):
				_check_effect_coverage(choice.risk.get("effects", {}), chips, true, float(choice.risk.chance))
	for venue: Dictionary in Content.VENUES:
		_check(Presenter.VENUE_TAGLINES.has(str(venue.id)), "Authored venue tagline")
		_check(_words(Presenter.venue_tagline(venue)) <= 7, "Venue tagline length")
	for person: Dictionary in Content.STAFF:
		_check(Presenter.STAFF_NOTES.has(str(person.id)), "Authored staff note")
		_check(_words(Presenter.staff_note(person)) <= 7, "Staff note length")
	_check(Presenter.effect_label("delay", 0.12) == "Capacity -12%", "Delay is lost capacity, not lost demand")
	_check(Presenter.effect_label("demand", -0.08) == "Demand -8%", "Demand carries a signed percentage")
	_check(Presenter.effect_label("quality", 0.12) == "Quality +0.12", "Quality is not misrepresented as sales percentage")
	_check(Presenter.effect_label("cash", -85) == "-$85", "Cost is clearly negative")
	_check(Presenter.effect_label("cash", 35.5) == "+$35.5", "Fractional cash preserved")
	var delayed: Array[Dictionary] = Presenter.choice_chips({"effects": {"delay": 0.08}})
	_check(delayed[0].tone == "bad", "Positive delay is a penalty")
	var no_effects: Array[Dictionary] = Presenter.choice_chips({"effects": {"flag": "some_story", "clear_flag": "another_story"}})
	_check(no_effects.size() == 1 and no_effects[0].label == "No cost", "Pure story choices remain compact")
	var future: Array[Dictionary] = Presenter.choice_chips({"effects": {"future_stat": -3}})
	_check(future[0].label == "Future Stat -3" and future[0].tone == "bad", "Unknown future penalties are not silently omitted")
	var synthetic: Dictionary = {"effects": {"stock": -2, "delay": 0.1, "rep": 1}, "risk": {"chance": 0.25, "effects": {"cash": -45, "fryer": -4}}}
	var synthetic_chips: Array[Dictionary] = Presenter.choice_chips(synthetic)
	_check(synthetic_chips.size() == 5, "Every effect survives beyond a four-chip limit")
	_check_effect_coverage(synthetic.effects, synthetic_chips, false, 0)
	_check_effect_coverage(synthetic.risk.effects, synthetic_chips, true, 0.25)
	_test_expanded_effects()
	_test_visible_outcomes()
	if failures.is_empty():
		print("PASS: %d presenter checks; all event teasers, venue/staff captions, complete outcomes and explicit risks." % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("FAIL: %d failures across %d checks." % [failures.size(), checks])
		quit(1)

func _check_effect_coverage(effects: Dictionary, chips: Array[Dictionary], is_risk: bool, chance: float) -> void:
	for key in effects:
		if not (effects[key] is int or effects[key] is float): continue
		var expected: String = Presenter.effect_label(str(key), float(effects[key]))
		var found := false
		for chip in chips:
			if is_risk:
				if str(chip.tone) == "risk" and str(chip.label).ends_with(expected) and str(chip.label).begins_with("%.0f%% risk: " % (chance * 100)):
					found = true
			elif str(chip.tone) != "risk" and str(chip.label) == expected:
				found = true
		_check(found, "Disclose %s %s: %s" % ["risk" if is_risk else "guaranteed", str(key), expected])

func _test_expanded_effects() -> void:
	for event: Dictionary in Content.EVENTS:
		for choice: Dictionary in event.choices:
			for context in ["travel", "trading"]:
				var cards: Array[Dictionary] = Presenter.choice_effects(choice, context, {"staff": []})
				for source in ["certain", "risk"]:
					var effects: Dictionary = choice.get("effects", {}) if source == "certain" else choice.get("risk", {}).get("effects", {})
					for key in effects:
						if not (effects[key] is float or effects[key] is int): continue
						var found := false
						for card in cards:
							if str(card.key) == key and str(card.source) == source:
								found = true
								_check(not str(card.title).is_empty() and not str(card.value).is_empty() and not str(card.duration).is_empty() and not str(card.detail).is_empty(), "Every consequence is named, quantified and timed")
								_check(is_equal_approx(float(card.amount), float(effects[key])), "Underlying effect delta remains inspectable")
								if key in ["quality", "demand", "delay"]:
									_check(card.duration == ("Next trading day" if context == "travel" else "This trading day"), "Temporary effect duration follows context")
								if source == "risk": _check(is_equal_approx(float(card.chance), float(choice.risk.chance)), "Risk keeps its exact probability")
						_check(found, "Expanded cards disclose every effect: " + str(event.id) + "/" + str(key))
	var quality: Dictionary = Presenter.choice_effects({"effects": {"quality": 0.1}}, "travel")[0]
	_check(quality.value == "+4% appeal" and "+0.25 review reputation" in str(quality.detail), "Quality shows both actual model contributions")
	var delay: Dictionary = Presenter.choice_effects({"effects": {"delay": 0.12}})[0]
	_check(delay.value == "-12%" and delay.title == "Production capacity" and "does not remove a calendar day" in str(delay.detail), "Delay clearly reduces production, not days")
	var crew: Array[Dictionary] = Presenter.choice_effects({"effects": {"morale": 8, "loyalty": 2}}, "trading", {"staff": []})
	for card in crew: _check(card.value == "0 · No hired crew" and card.duration == "No effect", "No crew means no morale or loyalty reward")
	var state := {"phase": "planning", "carry_travel_modifiers": true, "day_modifiers": {"quality": 0.1, "demand": 0.2, "delay": 0.1}, "day": 2, "minigame_day": 2, "minigame_boost": 0.15}
	var active: Array[Dictionary] = Presenter.active_effects(state)
	_check(active.size() == 4, "Pending effects include all travel modifiers and practice")
	for card in active: _check(card.duration == "Next trading day", "Planning shows pending rather than expired buffs")
	state.phase = "event"
	state.event = {"context": "trading"}
	for card in Presenter.active_effects(state): _check(card.duration == "This trading day", "Opening switches the duration to this trading day")
	state.phase = "report"
	_check(Presenter.active_effects(state).is_empty(), "Reports never show spent buffs as active")
	state.phase = "planning"
	state.carry_travel_modifiers = false
	state.minigame_day = 1
	_check(Presenter.active_effects(state).is_empty(), "Stale legacy modifier values cannot show phantom buffs")

func _test_visible_outcomes() -> void:
	var model = Model.new()
	model.new_run("Outcome display", 50)
	model.act("book", {"id": "willowbank"})
	model.state.rep = 99.0
	model.state.event.choices = [{"label": "Try it", "result": "The demo result.", "effects": {"rep": 8, "morale": 8, "quality": 0.1}, "risk": {"chance": 1, "effects": {"cash": -35}}}]
	model.act("decide", {"choice": 0})
	var cards: Array[Dictionary] = Presenter.outcome_effects(model.state)
	var rep_found := false
	var crew_found := false
	var risk_found := false
	for card in cards:
		if card.key == "rep": rep_found = card.value == "+1 points" and "Actual change" in str(card.detail)
		if card.key == "morale": crew_found = card.value == "0 · No hired crew" and card.tone == "neutral"
		if card.key == "risk": risk_found = card.title == "Risk happened"
	_check(rep_found, "Outcome cards show the clamped reputation reward, not the promised eight")
	_check(crew_found, "Outcome cards disclose zero effect without crew")
	_check(risk_found, "Outcome cards explicitly say whether the risk happened")
	model.act("advance")
	model.state.event.choices = [{"label": "Keep steady", "result": "All clear.", "effects": {}, "risk": {"chance": 0, "effects": {"cash": -35}}}]
	model.act("decide", {"choice": 0})
	var avoided := false
	var spent := false
	for card in Presenter.outcome_effects(model.state):
		if card.key == "risk" and card.title == "Risk avoided": avoided = true
		if card.key == "quality" and str(card.duration).begins_with("Used on day "): spent = true
	_check(avoided and spent, "Report distinguishes avoided risks and consumed travel quality")
	var used: Array[Dictionary] = Presenter.used_effects(model.state)
	_check(used.size() == 1 and used[0].value == "+4% appeal", "Report can show aggregate temporary effects actually used")

func _words(value: String) -> int:
	return value.split(" ", false).size()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
