extends RefCounted
## Store boundary only. A platform adapter and server-verified receipts are required
## before real purchases can be enabled. This class never grants wallet value.

const Catalog = preload("res://scripts/stand_catalog.gd")
const STORE_CONFIGURED = false

func store_configured() -> bool:
	return STORE_CONFIGURED

func get_status() -> Dictionary:
	return {"store_configured": false, "available": false, "status": "unconfigured", "message": "Real-money checkout is not available in this build."}

func get_catalog() -> Array:
	var result: Array = []
	for entry in Catalog.get_catalog():
		if int(entry.tickets) == 0: continue
		result.append({"id": entry.id, "name": entry.name, "kind": entry.kind, "status": "unavailable",
			"store_configured": false, "available": false, "product_id": "", "price_text": "", "currency": ""})
	return result

func product_status(id: String) -> Dictionary:
	var item: Dictionary = Catalog.get_item(id)
	return {"id": id, "store_configured": false, "available": false, "status": "unconfigured" if not item.is_empty() else "unknown_product",
		"message": "Real-money checkout is not available in this build."}

func request_purchase(id: String) -> Dictionary:
	return {"ok": false, "id": id, "status": "unavailable", "reason": "store_unconfigured", "store_configured": false,
		"message": "Real-money checkout is not available in this build. Earn Tickets by completing shifts and achievements."}

func restore_purchases() -> Dictionary:
	return {"ok": false, "status": "unavailable", "reason": "store_unconfigured", "store_configured": false}
