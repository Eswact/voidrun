class_name DiscBody extends Area2D

signal hit_player

const WALL_INSET := 30.0
const ARENA_W    := 648.0
const SEG_H      := ARENA_W - 2.0 * WALL_INSET   # 588

var active:        bool  = false


func _game_h() -> float:
	var win := DisplayServer.window_get_size()
	return float(win.y) * 648.0 / float(win.x)


func _seg_v() -> float:
	return _game_h() - 2.0 * WALL_INSET


func _perimeter() -> float:
	return 2.0 * (SEG_H + _seg_v())
var _t:            float = 0.0
var _travel_speed: float = 200.0
var _spin_speed:   float = 5.0


func launch(start_t: float, travel_speed: float, spin_speed: float) -> void:
	active = true
	_t = start_t
	_travel_speed = travel_speed
	_spin_speed = spin_speed
	global_position = _pos_from_t(_t)
	show()


func retire() -> void:
	active = false
	hide()


func update_speed(travel_speed: float, spin_speed: float) -> void:
	_travel_speed = travel_speed
	_spin_speed = spin_speed


func _physics_process(delta: float) -> void:
	if not active:
		return
	_t = fmod(_t + _travel_speed * delta / _perimeter(), 1.0)
	rotation += _spin_speed * delta
	global_position = _pos_from_t(_t)


func _pos_from_t(t: float) -> Vector2:
	var h  := _game_h()
	var sv := _seg_v()
	var d  := t * _perimeter()
	if d < SEG_H:
		return Vector2(WALL_INSET + d, WALL_INSET)
	d -= SEG_H
	if d < sv:
		return Vector2(ARENA_W - WALL_INSET, WALL_INSET + d)
	d -= sv
	if d < SEG_H:
		return Vector2(ARENA_W - WALL_INSET - d, h - WALL_INSET)
	d -= SEG_H
	return Vector2(WALL_INSET, h - WALL_INSET - d)


func _on_body_entered(body: Node2D) -> void:
	if not active:
		return
	if body.has_method("die") and not body.get("is_invincible"):
		hit_player.emit()
