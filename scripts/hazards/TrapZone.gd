class_name TrapZone extends Area2D

signal hit_player
signal zone_finished

const COLOR_WARN   := Color(1.0, 0.9, 0.0, 0.45)  # sarı, yarı şeffaf
const COLOR_LETHAL := Color(1.0, 0.25, 0.25, 1.0)  # kırmızı, opak

var active:           bool  = false
var _warn_duration:   float = 1.5
var _active_duration: float = 3.0
var _is_lethal:       bool  = false


func _ready() -> void:
	z_index = -1
	add_to_group("clearable")


func launch(pos: Vector2, warn_duration: float, active_duration: float) -> void:
	active = true
	_warn_duration   = warn_duration
	_active_duration = active_duration
	_is_lethal = false
	global_position = pos
	modulate = COLOR_WARN
	show()
	_run_sequence()


func retire() -> void:
	if not active:
		return
	active = false
	_is_lethal = false
	hide()
	zone_finished.emit()


func _run_sequence() -> void:
	await get_tree().create_timer(_warn_duration).timeout
	if not active:
		return
	_is_lethal = true
	modulate = COLOR_LETHAL

	await get_tree().create_timer(_active_duration).timeout
	if not active:
		return
	retire()


func _on_body_entered(body: Node2D) -> void:
	if not active:
		return
	if _is_lethal and body.has_method("die") and not body.get("is_invincible"):
		hit_player.emit()
		retire()
