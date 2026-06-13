class_name BounceStream extends BaseHazard

const BORDER:          float = 24.0
const DESIGN_W:        float = 648.0
const WARNING_SCRIPT         := preload("res://scripts/hazards/BulletWarning.gd")

var _rate:        float = 0.8
var _speed:       float = 220.0
var _max_bullets: int   = 35
var _warn_time:   float = 0.35

var _timer:  Timer
var _pool:   Array[BouncingBullet] = []
var _bounds: Rect2


func _ready() -> void:
	_timer          = Timer.new()
	_timer.one_shot = false
	add_child(_timer)
	_timer.timeout.connect(_fire)


func activate(params: Dictionary) -> void:
	_rate        = params.get("rate",        _rate)
	_speed       = params.get("speed",       _speed)
	_max_bullets = params.get("max_bullets", _max_bullets)
	_timer.wait_time = 1.0 / _rate
	_timer.start()
	var director := get_parent()
	if director.has_method("get_play_rect"):
		_bounds = director.get_play_rect()
	else:
		var arena_h: float = director.get_arena_h() if director.has_method("get_arena_h") else 1152.0
		_bounds = Rect2(BORDER, BORDER, DESIGN_W - BORDER * 2.0, arena_h - BORDER * 2.0)
	super.activate(params)


func deactivate() -> void:
	_timer.stop()
	for b in _pool:
		if b.active:
			b.retire()
	super.deactivate()


func update_params(params: Dictionary) -> void:
	if not active:
		return
	_rate        = params.get("rate",        _rate)
	_speed       = params.get("speed",       _speed)
	_max_bullets = params.get("max_bullets", _max_bullets)
	_timer.wait_time = 1.0 / _rate


func _fire() -> void:
	var active_count := 0
	for b in _pool:
		if b.active:
			active_count += 1
	if active_count >= _max_bullets:
		return

	var diagonal  := randi() % 3 != 0
	var edge      := randi() % 4
	var spawn_pt  := _edge_point(edge)

	_show_warning(spawn_pt)
	await get_tree().create_timer(_warn_time).timeout

	if not active:
		return

	var b := _get_or_create()
	b.launch(spawn_pt, _launch_dir(edge, diagonal) * _speed, diagonal)


func _show_warning(pos: Vector2) -> void:
	var w := Node2D.new()
	w.set_script(WARNING_SCRIPT)
	w.position = pos
	get_tree().current_scene.add_child(w)
	get_tree().create_timer(_warn_time).timeout.connect(w.queue_free)


func _edge_point(edge: int) -> Vector2:
	match edge:
		0: return Vector2(randf_range(_bounds.position.x + 20.0, _bounds.end.x - 20.0), _bounds.position.y + 5.0)
		1: return Vector2(randf_range(_bounds.position.x + 20.0, _bounds.end.x - 20.0), _bounds.end.y - 5.0)
		2: return Vector2(_bounds.position.x + 5.0, randf_range(_bounds.position.y + 20.0, _bounds.end.y - 20.0))
		_: return Vector2(_bounds.end.x - 5.0, randf_range(_bounds.position.y + 20.0, _bounds.end.y - 20.0))


func _launch_dir(edge: int, diagonal: bool) -> Vector2:
	var s := 1.0 if randi() % 2 == 0 else -1.0
	if diagonal:
		# Tam 45° açılar — sekerek öngörülebilir bir yol çizer
		match edge:
			0: return Vector2(s,  1.0).normalized()  # üst  → sağ-aşağı / sol-aşağı
			1: return Vector2(s, -1.0).normalized()  # alt  → sağ-yukarı / sol-yukarı
			2: return Vector2( 1.0, s).normalized()  # sol  → sağ + yukarı/aşağı
			_: return Vector2(-1.0, s).normalized()  # sağ  → sol + yukarı/aşağı
	else:
		# Tam yatay veya dikey — duvara çarpta aynı yönde devam eder
		match edge:
			0: return Vector2.DOWN
			1: return Vector2.UP
			2: return Vector2.RIGHT
			_: return Vector2.LEFT
	return Vector2.DOWN


func _get_or_create() -> BouncingBullet:
	for b in _pool:
		if not b.active:
			return b
	var b         := BouncingBullet.new()
	b.arena_bounds = _bounds
	add_child(b)
	b.hit_player.connect(_on_hit_player)
	_pool.append(b)
	return b


func _on_hit_player() -> void:
	hazard_hit_player.emit()
