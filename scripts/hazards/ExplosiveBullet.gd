class_name ExplosiveBullet extends Area2D

signal hit_player

const BULLET_SCENE  := preload("res://scenes/hazards/Bullet.tscn")
const SHORT_TEX     := preload("res://assets/sprites/hazards/bullets/short-bullet.png")

const FLY_SPEED     := 320.0
const SHARD_SPEED   := 140.0
const EXPLODE_DIST  := 150.0

var active: bool = false
var _spread_count: int = 8
var _warn_duration: float = 0.7
var _is_exploding: bool = false
var _warning_tween: Tween = null
var _shard_pool: Array[Bullet] = []
var _player: Node2D = null


func _ready() -> void:
	add_to_group("clearable")
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _arena_center() -> Vector2:
	if _player:
		return Vector2(324.0, _player.global_position.y)
	var win := DisplayServer.window_get_size()
	return Vector2(324.0, float(win.y) * 648.0 / float(win.x) / 2.0)


func launch(from: Vector2, spread_count: int, warn_duration: float) -> void:
	active = true
	_spread_count = spread_count
	_warn_duration = warn_duration
	_is_exploding = false
	scale = Vector2.ONE
	global_position = from
	rotation = (_arena_center() - from).angle()
	show()


func retire() -> void:
	active = false
	_is_exploding = false
	if _warning_tween:
		_warning_tween.kill()
		_warning_tween = null
	scale = Vector2.ONE
	hide()


func force_retire() -> void:
	for b in _shard_pool:
		if b.active:
			b.deactivate()
	retire()


func _physics_process(delta: float) -> void:
	if not active or _is_exploding:
		return
	var center := _arena_center()
	var dir := (center - global_position).normalized()
	global_position += dir * FLY_SPEED * delta
	rotation = dir.angle()
	if global_position.distance_to(center) < EXPLODE_DIST:
		_is_exploding = true
		_start_warning()


func _start_warning() -> void:
	_warning_tween = create_tween()
	_warning_tween.tween_property(self, "scale", Vector2(1.8, 1.8), _warn_duration * 0.4)
	_warning_tween.tween_property(self, "scale", Vector2(0.6, 0.6), _warn_duration * 0.3)
	_warning_tween.tween_property(self, "scale", Vector2(2.2, 2.2), _warn_duration * 0.3)
	_warning_tween.finished.connect(_on_warning_done)


func _on_warning_done() -> void:
	_warning_tween = null
	if active:
		_explode()


func _explode() -> void:
	var root := get_tree().current_scene
	if root and root.has_method("shake"):
		root.shake(8.0, 0.3)
	for i in _spread_count:
		var angle := i * TAU / float(_spread_count)
		var b := _get_shard()
		b.set_texture(SHORT_TEX)
		b.launch(global_position, Vector2.from_angle(angle), SHARD_SPEED)
	retire()


func _on_body_entered(body: Node2D) -> void:
	if not active:
		return
	if body.has_method("die") and not body.get("is_invincible"):
		hit_player.emit()
		retire()


func _get_shard() -> Bullet:
	for b in _shard_pool:
		if not b.active:
			return b
	var b: Bullet = BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(b)
	b.hit_player.connect(func(): hit_player.emit())
	_shard_pool.append(b)
	return b
