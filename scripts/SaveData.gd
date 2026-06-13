extends Node

const SAVE_PATH := "user://save.dat"

var best_time:          float  = 0.0
var user_nick:          String = ""
var device_id:          String = ""
var pending_submission: float  = -1.0


func _ready() -> void:
	_load()


func save_if_best(time: float) -> bool:
	if time > best_time:
		best_time = time
		_save()
		return true
	return false


func save_nick(nick: String) -> void:
	user_nick = nick.strip_edges()
	_save()


func has_nick() -> bool:
	return user_nick.length() >= 2


func _save() -> void:
	var f := ConfigFile.new()
	f.set_value("data", "best_time",  best_time)
	f.set_value("data", "user_nick",  user_nick)
	f.set_value("data", "device_id",  device_id)
	f.save(SAVE_PATH)


func _load() -> void:
	var f := ConfigFile.new()
	if f.load(SAVE_PATH) == OK:
		best_time = f.get_value("data", "best_time", 0.0)
		user_nick = f.get_value("data", "user_nick", "")
		device_id = f.get_value("data", "device_id", "")
	if device_id.is_empty():
		device_id = _generate_device_id()
		_save()


func reset() -> void:
	best_time  = 0.0
	user_nick  = ""
	device_id  = _generate_device_id()
	pending_submission = -1.0
	_save()


func _generate_device_id() -> String:
	return "%08x%08x%08x%08x" % [randi(), randi(), randi(), randi()]
