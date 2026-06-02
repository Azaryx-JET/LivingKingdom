extends Node
class_name ResourceManager

signal stocks_changed(stocks: Dictionary)
signal low_resource(resource_name: String, amount: int)

const WOOD := "bois"
const STONE := "pierre"
const FOOD := "nourriture"

var stocks := {
	WOOD: 60,
	STONE: 35,
	FOOD: 90,
}

var low_thresholds := {
	WOOD: 20,
	STONE: 10,
	FOOD: 20,
}

var _last_alert_day := {}

func add_resource(resource_name: String, amount: int) -> void:
	if not stocks.has(resource_name):
		stocks[resource_name] = 0
	stocks[resource_name] += amount
	stocks_changed.emit(stocks.duplicate())

func consume(resource_name: String, amount: int) -> bool:
	if get_amount(resource_name) < amount:
		return false
	stocks[resource_name] -= amount
	stocks_changed.emit(stocks.duplicate())
	return true

func has_resources(cost: Dictionary) -> bool:
	for resource_name in cost.keys():
		if get_amount(resource_name) < int(cost[resource_name]):
			return false
	return true

func consume_many(cost: Dictionary) -> bool:
	if not has_resources(cost):
		return false
	for resource_name in cost.keys():
		stocks[resource_name] -= int(cost[resource_name])
	stocks_changed.emit(stocks.duplicate())
	return true

func get_amount(resource_name: String) -> int:
	return int(stocks.get(resource_name, 0))

func check_alerts(day: int) -> void:
	for resource_name in low_thresholds.keys():
		var amount := get_amount(resource_name)
		if amount < int(low_thresholds[resource_name]) and int(_last_alert_day.get(resource_name, -1)) != day:
			_last_alert_day[resource_name] = day
			low_resource.emit(resource_name, amount)
