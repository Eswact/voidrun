class_name HomingBullet extends Area2D

signal hit_player

const _SHORT_TEX := preload("res://assets/sprites/hazards/bullets/short-bullet.png")

const SPEED      := 200.0
const TURN_SPEED := 2.0   # rad/s — 180° dönüş ~1.6s sürer
const LIFETIME   := 6.0

var active:   bool    = false
var _vel:     Vector2 = Vector2.ZERO
var _life:    float   = 0.0
var _bounds:  Rect2
var _spr:     Sprite2D
var _player:  Node2D  = null


func _ready() -> void:
	add_to_group("clearable")
	var shape := RectangleShape2D.new()
	shape.size    = Vector2(32.0, 16.0)
	var col       := CollisionShape2D.new()
	col.shape     = shape
	col.position  = Vector2(12.0, 0.0)
	add_child(col)

	_spr          = Sprite2D.new()
	_spr.texture  = _SHORT_TEX
	_spr.scale    = Vector2(0.09, 0.09)
	_spr.modulate = Color(1.0, 0.35, 0.35)  # kırmızı — normal mermi ile karışmasın
	add_child(_spr)

	body_entered.connect(_on_body_entered)

	var scene := get_tree().current_scene
	var pr: Rect2 = scene.get("_play_rect") if scene else Rect2()
	_bounds = pr if pr.size.x > 0.0 else Rect2(40.0, 80.0, 568.0, 1200.0)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	hide()


func launch(from: Vector2, initial_dir: Vector2) -> void:
	active = true
	_vel   = initial_dir.normalized() * SPEED
	_life  = LIFETIME
	global_position = from
	rotation = _vel.angle()
	show()


func retire() -> void:
	active = false
	hide()


func _physics_process(delta: float) -> void:
	if not active:
		return
	_life -= delta
	if _life <= 0.0:
		retire()
		return

	if _player:
		var target_dir:   Vector2 = (_player.global_position - global_position).normalized()
		var cur_angle:    float   = _vel.angle()
		var target_angle: float   = target_dir.angle()
		var diff:         float   = wrapf(target_angle - cur_angle, -PI, PI)
		var steer:        float   = clampf(diff, -TURN_SPEED * delta, TURN_SPEED * delta)
		_vel = Vector2.from_angle(cur_angle + steer) * SPEED

	global_position += _vel * delta
	rotation = _vel.angle()

	if _bounds.size.x > 0.0 and not _bounds.grow(80.0).has_point(global_position):
		retire()


func _on_body_entered(body: Node2D) -> void:
	if not active:
		return
	if body.has_method("die") and not body.get("is_invincible"):
		hit_player.emit()
		retire()
