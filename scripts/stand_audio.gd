extends "res://scripts/game_audio.gd"
## Idea 2 serving actions reuse the project's original synthesized palette.
## The inherited shared voice budget, mute, and independent music apply here.

var _last_stand_warning_msec := -10000


func play_action(action: String, reward_tier: int = 1) -> void:
	match action.to_lower():
		"scoop", "pickup_scoop", "supply", "tray":
			super.play_event("flip")
		"pour", "dump", "refill", "hopper", "package":
			super.play_event("drop")
		"bag", "bucket", "container", "sugar", "cinnamon", "powdered", "heat", "heat_up", "heat_down", "customer", "trash", "discard":
			super.play_event("click")
		"serve", "order_complete":
			play_sale(clampi(reward_tier, 0, 2))
		"repair", "jam_cleared":
			super.play_event("upgrade")
		"quota", "shift_goal":
			play_goal()
		"jam", "too_hot", "overheat", "wrong_order", "wrongorder", "customer_left", "walkout":
			var now := Time.get_ticks_msec()
			if now - _last_stand_warning_msec >= 900:
				_last_stand_warning_msec = now
				super.play_event("failure")
		"win":
			super.play_event("win")
		"loss":
			super.play_event("failure")
		_:
			super.play_event(action)


func play_warning(code: String) -> void:
	play_action(code if code in ["jam", "overheat", "walkout", "wrongorder", "wrong_order", "too_hot", "customer_left"] else "wrong_order")


func play_customer() -> void:
	super.play_event("click")


func play_served(amount: float, streak: int) -> void:
	play_sale(2 if amount >= 25.0 or streak >= 3 else 1, streak)
