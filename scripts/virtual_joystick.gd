class_name VirtualJoystick
extends Control

@export var clamp_distance: float = 48.0

const DEAD_ZONE: float = 0.08

@onready var base: Sprite2D = $Base
@onready var knob: Sprite2D = $Knob

var output_vector:    Vector2 = Vector2.ZERO
var is_pressing:      bool    = false
var touch_index:      int     = -1
var _joystick_center: Vector2 = Vector2.ZERO
var _hint_pos:        Vector2 = Vector2.ZERO
var _canvas_h:        float   = 1152.0
var _decelerating:    bool    = false
var disabled:         bool    = false:
	set(v):
		disabled = v
		if v and is_pressing:
			_stop()


func _ready() -> void:
	var win   := DisplayServer.window_get_size()
	var scale := float(win.x) / 648.0
	_canvas_h = float(win.y) / scale
	_hint_pos = Vector2(324.0, _canvas_h - 150.0)
	base.global_position = _hint_pos
	knob.global_position = _hint_pos
	base.modulate.a = 0.5
	knob.modulate.a = 0.25


func _input(event: InputEvent) -> void:
	if disabled: return
	if event is InputEventScreenTouch:
		if event.pressed and not is_pressing:
			if not _is_button_area(event.position):
				_start(event.position, event.index)
		elif not event.pressed and event.index == touch_index:
			_stop()
	elif event is InputEventScreenDrag:
		if is_pressing and event.index == touch_index:
			_move(event.position)


func _is_button_area(pos: Vector2) -> bool:
	if pos.y < 200.0:
		return true
	if pos.y > _canvas_h - 200.0 and (pos.x < 190.0 or pos.x > 458.0):
		return true
	return false


func _process(delta: float) -> void:
	if _decelerating:
		output_vector = output_vector.move_toward(Vector2.ZERO, delta / 0.15)
		if output_vector.is_zero_approx():
			output_vector  = Vector2.ZERO
			_decelerating  = false


func _start(touch_pos: Vector2, index: int) -> void:
	is_pressing   = true
	touch_index   = index
	_decelerating = false
	_joystick_center = touch_pos
	base.global_position = touch_pos
	knob.global_position = touch_pos
	base.modulate.a = 0.8
	knob.modulate.a = 1.0
	Input.vibrate_handheld(30)


func _move(touch_pos: Vector2) -> void:
	var offset  := touch_pos - _joystick_center
	var clamped := offset.limit_length(clamp_distance)
	knob.global_position = _joystick_center + clamped

	var raw := clamped / clamp_distance
	output_vector = Vector2.ZERO if raw.length() < DEAD_ZONE else raw


func _stop() -> void:
	is_pressing   = false
	touch_index   = -1
	_decelerating = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(base, "global_position", _hint_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(knob, "global_position", _hint_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(base, "modulate:a", 0.5, 0.15)
	tw.tween_property(knob, "modulate:a", 0.25, 0.15)


func get_output() -> Vector2:
	return output_vector
