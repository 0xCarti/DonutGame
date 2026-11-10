extends SceneTree

const Presenter = preload("res://scripts/circuit_presenter.gd")
const Content = preload("res://scripts/circuit_content.gd")
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

func _words(value: String) -> int:
	return value.split(" ", false).size()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
