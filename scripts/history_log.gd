extends Node
class_name HistoryLog

signal events_changed(events: Array[String])

const MAX_EVENTS := 8

var events: Array[String] = []

func add_event(day: int, message: String) -> void:
	events.append("Jour %d : %s" % [day, message])
	while events.size() > MAX_EVENTS:
		events.pop_front()
	events_changed.emit(events.duplicate())

func get_recent_events() -> Array[String]:
	return events.duplicate()
