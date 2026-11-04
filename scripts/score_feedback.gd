extends RefCounted
## Presentation only. Never changes payouts, RNG, upgrades, or saved run state.

var chain: int = 0
var last_sale_time: float = -100.0

func reset() -> void:
	chain = 0
	last_sale_time = -100.0

func describe_sale(receipt: Dictionary, elapsed: float, crossed_target: bool = false) -> Dictionary:
	var amount: float = float(receipt.get("amount", 0.0))
	if not is_finite(amount) or amount <= 0.0:
		return {}
	var full: bool = bool(receipt.get("full", false))
	if full:
		chain = mini(chain + 1, 8) if elapsed >= last_sale_time and elapsed - last_sale_time <= 5.0 else 1
	else:
		chain = 0
	last_sale_time = elapsed
	var tier: int = 1 if full else 0
	if amount >= 120.0: tier = maxi(tier, 2)
	if amount >= 280.0: tier = 3
	if full and chain >= 3: tier = maxi(tier, 2)
	if full and chain >= 5: tier = 3
	if crossed_target: tier = mini(tier + 1, 3)
	var title: String = ["FRESH SALE", "SWEET SIX!", "SUGAR RUSH!", "GOLDEN JACKPOT!"][tier]
	if tier == 1 and not full: title = "SWEET SALE!"
	return {
		"amount": amount, "tier": tier, "chain": chain,
		"title": title,
		"combo": str(receipt.get("combo", "Freshly served")),
		"multiplier": float(receipt.get("multiplier", 1.0)),
		"goal": crossed_target,
	}
