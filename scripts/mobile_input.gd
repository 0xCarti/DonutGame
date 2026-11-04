extends RefCounted
## One world gesture owns one pointer. GUI touches never enter this recognizer.
## Coordinates are logical UI pixels, so the drag threshold is resolution independent.

const NO_POINTER = -2147483648
const DRAG_DISTANCE = 14.0
const HOLD_DELAY = 0.22
var pointer: int = NO_POINTER
var origin = Vector2.ZERO
var last = Vector2.ZERO
var station = ""
var began_at = 0.0
var dragging = false
var holding = false

func owns(id: int) -> bool:
	return pointer == id

func begin(id: int, position: Vector2, hit_station: String, now: float) -> Array:
	if pointer != NO_POINTER: return []
	pointer = id
	origin = position
	last = position
	station = hit_station
	began_at = now
	dragging = false
	holding = false
	return []

func advance(now: float) -> Array:
	if pointer == NO_POINTER or dragging or holding: return []
	if station in ["repair", "refill"] and now - began_at >= HOLD_DELAY:
		holding = true
		return [{"kind": "hold_start", "station": station}]
	return []

func move(id: int, position: Vector2) -> Array:
	if not owns(id): return []
	var events: Array = []
	if not dragging and position.distance_to(origin) > DRAG_DISTANCE:
		dragging = true
		if holding:
			holding = false
			events.append({"kind": "hold_end", "station": station})
	if dragging: events.append({"kind": "look", "delta": position - last})
	last = position
	return events

func end(id: int, position: Vector2, canceled: bool = false) -> Array:
	if not owns(id): return []
	var events: Array = []
	if holding: events.append({"kind": "hold_end", "station": station})
	elif not canceled and not dragging and position.distance_to(origin) <= DRAG_DISTANCE and not station.is_empty() and station not in ["repair", "refill"]:
		events.append({"kind": "tap", "station": station})
	_reset()
	return events

func cancel() -> Array:
	return end(pointer, last, true) if pointer != NO_POINTER else []

func _reset() -> void:
	pointer = NO_POINTER
	station = ""
	dragging = false
	holding = false

static func canvas_rect(view_size: Vector2, safe_rect: Rect2) -> Rect2:
	var available = safe_rect.intersection(Rect2(Vector2.ZERO, view_size))
	if available.size.x < 1.0 or available.size.y < 1.0: available = Rect2(Vector2.ZERO, view_size)
	var factor = minf(available.size.x / 1280.0, available.size.y / 800.0)
	var dimensions = Vector2(1280, 800) * factor
	return Rect2(available.position + (available.size - dimensions) * 0.5, dimensions)
