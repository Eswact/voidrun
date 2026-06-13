class_name AbilityBubble extends Area2D

signal picked_up(type: int)
signal expired

enum Type { SCREEN_CLEAR, INVINCIBILITY, TIME_SLOW }

const LIFETIME     := 12.0
const TARGET_SIZE  := 48.0

const TEXTURE_CLEAR := preload("res://assets/sprites/ability/clear-bubble.png")
const TEXTURE_GHOST := preload("res://assets/sprites/ability/ghost-bubble.png")
const TEXTURE_SLOW  := preload("res://assets/sprites/ability/slow-bubble.png")

var ability_type: int = Type.SCREEN_CLEAR
var _alive:       bool  = false
var _tween:       Tween = null

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func spawn(pos: Vector2, type: int) -> void:
	ability_type    = type
	_alive          = true
	global_position = pos
	scale           = Vector2.ONE
	match type:
		Type.SCREEN_CLEAR:  _sprite.texture = TEXTURE_CLEAR
		Type.INVINCIBILITY: _sprite.texture = TEXTURE_GHOST
		Type.TIME_SLOW:     _sprite.texture = TEXTURE_SLOW
	var tex_size := _sprite.texture.get_size()
	var s := TARGET_SIZE / maxf(tex_size.x, tex_size.y)
	_sprite.scale = Vector2(s, s)
	show()
	_start_pulse()
	get_tree().create_timer(LIFETIME).timeout.connect(_on_expired)


func _on_expired() -> void:
	if not _alive:
		return
	_kill_tween()
	_alive = false
	hide()
	expired.emit()


func _on_body_entered(body: Node2D) -> void:
	if not _alive:
		return
	if not body.has_method("receive_ability"):
		return
	_kill_tween()
	_alive = false
	hide()
	body.receive_ability(ability_type)
	picked_up.emit(ability_type)


func _kill_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null


func _start_pulse() -> void:
	_tween = create_tween().set_loops()
	_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "scale", Vector2(0.85, 0.85), 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
