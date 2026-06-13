class_name BouncingBullet extends Area2D

signal hit_player

const _SHORT_TEX  := preload("res://assets/sprites/hazards/bullets/short-bullet.png")
const _LONG_TEX   := preload("res://assets/sprites/hazards/bullets/long-bullet.png")
const MAX_BOUNCES := 5

var active:         bool    = false
var arena_bounds:   Rect2
var _velocity:      Vector2 = Vector2.ZERO
var _bounce_count:  int     = 0
var _bounce_r:      float   = 8.0
var _spr:           Sprite2D
var _col_shape:     RectangleShape2D
var _col_node:      CollisionShape2D


func _ready() -> void:
	_col_shape      = RectangleShape2D.new()
	_col_shape.size = Vector2(32.0, 16.0)
	_col_node          = CollisionShape2D.new()
	_col_node.shape    = _col_shape
	_col_node.position = Vector2(12.0, 0.0)
	add_child(_col_node)

	_spr         = Sprite2D.new()
	_spr.texture = _SHORT_TEX
	_spr.scale   = Vector2(0.9, 0.9)
	add_child(_spr)

	body_entered.connect(_on_body_entered)
	add_to_group("clearable")
	hide()


func launch(from: Vector2, velocity: Vector2, diagonal: bool = false) -> void:
	if diagonal:
		_spr.texture       = _LONG_TEX
		_spr.scale         = Vector2(0.16, 0.16)
		_col_shape.size    = Vector2(44.0, 16.0)
		_col_node.position = Vector2(40.0, 0.0)
	else:
		_spr.texture       = _SHORT_TEX
		_spr.scale         = Vector2(0.09, 0.09)
		_col_shape.size    = Vector2(32.0, 16.0)
		_col_node.position = Vector2(12.0, 0.0)
	_bounce_r       = 8.0
	global_position = from
	_velocity       = velocity
	_bounce_count   = 0
	active          = true
	show()


func retire() -> void:
	active = false
	hide()


func _physics_process(delta: float) -> void:
	if not active:
		return

	global_position += _velocity * delta
	rotation         = _velocity.angle()

	if _bounce_count >= MAX_BOUNCES:
		if not arena_bounds.grow(20.0).has_point(global_position):
			retire()
		return

	var bounced := false
	if global_position.x - _bounce_r < arena_bounds.position.x:
		global_position.x = arena_bounds.position.x + _bounce_r
		_velocity.x       = abs(_velocity.x)
		bounced = true
	elif global_position.x + _bounce_r > arena_bounds.end.x:
		global_position.x = arena_bounds.end.x - _bounce_r
		_velocity.x       = -abs(_velocity.x)
		bounced = true

	if global_position.y - _bounce_r < arena_bounds.position.y:
		global_position.y = arena_bounds.position.y + _bounce_r
		_velocity.y       = abs(_velocity.y)
		bounced = true
	elif global_position.y + _bounce_r > arena_bounds.end.y:
		global_position.y = arena_bounds.end.y - _bounce_r
		_velocity.y       = -abs(_velocity.y)
		bounced = true

	if bounced:
		_bounce_count += 1


func _on_body_entered(body: Node2D) -> void:
	if not active:
		return
	if body.has_method("die") and not body.get("is_invincible"):
		hit_player.emit()
		retire()
