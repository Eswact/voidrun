class_name Bullet extends Area2D

signal hit_player

var _speed: float = 400.0
var _direction: Vector2 = Vector2.ZERO
var active: bool = false

var _bounds: Rect2
var _base_scale: Vector2

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("clearable")
	_base_scale = _sprite.scale
	var scene := get_tree().current_scene
	var pr: Rect2 = scene.get("_play_rect") if scene else Rect2()
	if pr.size.x > 0.0 and pr.size.y > 0.0:
		_bounds = pr
	else:
		var win    := DisplayServer.window_get_size()
		var arena_h := float(win.y) * 648.0 / float(win.x)
		_bounds = Rect2(0.0, 0.0, 648.0, arena_h)


func set_texture(tex: Texture2D, scale_multiplier: float = 1.0) -> void:
	_sprite.texture = tex
	_sprite.scale   = _base_scale * scale_multiplier


func launch(from: Vector2, direction: Vector2, speed: float) -> void:
	active = true
	global_position = from
	_direction = direction
	_speed = speed
	rotation = direction.angle()
	show()


func deactivate() -> void:
	active = false
	hide()


func _physics_process(delta: float) -> void:
	if not active:
		return
	global_position += _direction * _speed * delta
	if not _bounds.has_point(global_position):
		deactivate()


func _on_body_entered(body: Node2D) -> void:
	if not active:
		return
	if body.has_method("die") and not body.get("is_invincible"):
		hit_player.emit()
		deactivate()
