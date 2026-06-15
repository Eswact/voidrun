class_name ProjectileStream extends BaseHazard

const BULLET_SCENE      := preload("res://scenes/hazards/Bullet.tscn")
const FAST_BULLET_SCENE := preload("res://scenes/hazards/FastBullet.tscn")
const WARNING_SCRIPT    := preload("res://scripts/hazards/BulletWarning.gd")
const _SHORT_TEX        := preload("res://assets/sprites/hazards/bullets/short-bullet.png")
const _LONG_TEX         := preload("res://assets/sprites/hazards/bullets/long-bullet.png")

const ARENA_W         := 648.0
const SPREAD          := 220.0
const STILL_THRESHOLD := 10.0

var _rate:         float = 1.5
var _speed:        float = 140.0
var _warn_time:    float = 0.7
var _straight_mode: bool = false

var _timer:      Timer
var _pool:       Array[Bullet] = []
var _fast_pool:  Array[Bullet] = []

var _player:           Node2D = null
var _player_still_time: float  = 0.0
var _last_player_pos:  Vector2 = Vector2.ZERO


func _ready() -> void:
	_timer = Timer.new()
	add_child(_timer)
	_timer.timeout.connect(_fire)
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_last_player_pos = _player.global_position


func _process(delta: float) -> void:
	if not active or _player == null:
		return
	var pos: Vector2 = _player.global_position
	if pos.distance_to(_last_player_pos) < 5.0:
		_player_still_time += delta
	else:
		_player_still_time = 0.0
		_last_player_pos = pos


func activate(params: Dictionary) -> void:
	_apply_params(params)
	_timer.wait_time = 1.0 / _rate
	_timer.start()
	super.activate(params)


func deactivate() -> void:
	_timer.stop()
	_player_still_time = 0.0
	for b in _pool:
		if b.active:
			b.deactivate()
	for b in _fast_pool:
		if b.active:
			b.deactivate()
	super.deactivate()


func update_params(params: Dictionary) -> void:
	if not active:
		return
	_apply_params(params)
	_timer.wait_time = 1.0 / _rate


func _apply_params(params: Dictionary) -> void:
	_rate         = params.get("rate",       _rate)
	_speed        = params.get("speed",      _speed)
	_warn_time    = params.get("warn_time",  _warn_time)
	_straight_mode = params.get("straight", _straight_mode)


# ─── Fire loop ────────────────────────────────────────────────────────────────

func _fire() -> void:
	var edge      := randi() % 4
	var spawn_pos := _edge_spawn_pos(edge)

	if _player_near_edge(edge, spawn_pos):
		_show_warning(_edge_warn_pos(spawn_pos, edge))

	await get_tree().create_timer(_warn_time).timeout

	if not active:
		return

	# Player moved during warning — re-clamp spawn to current camera edge
	spawn_pos = _snap_spawn_to_cam(spawn_pos, edge)

	var bullet: Bullet
	if _straight_mode:
		bullet = _get_bullet()
		bullet.set_texture(_SHORT_TEX)
	else:
		bullet = _get_fast_bullet()
		bullet.set_texture(_LONG_TEX)
	bullet.launch(spawn_pos, _calc_direction(spawn_pos, edge), _speed)


func _cam_top() -> float:
	return get_parent().get_cam_top()


func _cam_bot() -> float:
	return get_parent().get_cam_bot()


func _play_rect() -> Rect2:
	return get_parent().get_play_rect()


func _edge_spawn_pos(edge: int) -> Vector2:
	var rect  := _play_rect()
	var min_y := maxf(_cam_top() - 20.0, rect.position.y)
	var max_y := minf(_cam_bot() + 20.0, rect.end.y)
	var mid_y := maxf(_cam_top(), rect.position.y)
	var end_y := minf(_cam_bot(), rect.end.y)
	match edge:
		0: return Vector2(randf_range(rect.position.x, rect.end.x), min_y)
		1: return Vector2(randf_range(rect.position.x, rect.end.x), max_y)
		2: return Vector2(rect.position.x, randf_range(mid_y, end_y))
		3: return Vector2(rect.end.x,      randf_range(mid_y, end_y))
	return Vector2.ZERO


func _snap_spawn_to_cam(spawn_pos: Vector2, edge: int) -> Vector2:
	var rect  := _play_rect()
	var min_y := maxf(_cam_top() - 20.0, rect.position.y)
	var max_y := minf(_cam_bot() + 20.0, rect.end.y)
	var vis_y0 := maxf(_cam_top(), rect.position.y)
	var vis_y1 := minf(_cam_bot(), rect.end.y)
	match edge:
		0: return Vector2(spawn_pos.x, min_y)
		1: return Vector2(spawn_pos.x, max_y)
		2, 3: return Vector2(spawn_pos.x, clampf(spawn_pos.y, vis_y0, vis_y1))
	return spawn_pos


func _edge_warn_pos(spawn_pos: Vector2, edge: int) -> Vector2:
	var rect := _play_rect()
	match edge:
		0: return Vector2(spawn_pos.x, maxf(_cam_top() + 15.0, rect.position.y + 5.0))
		1: return Vector2(spawn_pos.x, minf(_cam_bot() - 15.0, rect.end.y - 5.0))
		2: return Vector2(rect.position.x + 5.0, spawn_pos.y)
		3: return Vector2(rect.end.x - 5.0,      spawn_pos.y)
	return spawn_pos


func _player_near_edge(edge: int, spawn_pos: Vector2) -> bool:
	if _player == null:
		return false
	var rect     := _play_rect()
	var vis_h    := _cam_bot() - _cam_top()
	var thresh_v := vis_h * 0.35
	var thresh_h := rect.size.x * 0.35
	var py       := _player.global_position.y
	var px       := _player.global_position.x
	match edge:
		0: return py - _cam_top()      < thresh_v
		1: return _cam_bot() - py      < thresh_v
		2: return (px - rect.position.x < thresh_h) and (absf(spawn_pos.y - py) < vis_h * 0.45)
		3: return (rect.end.x - px     < thresh_h) and (absf(spawn_pos.y - py) < vis_h * 0.45)
	return false


func _show_warning(pos: Vector2) -> void:
	var w := Node2D.new()
	w.set_script(WARNING_SCRIPT)
	w.position = pos
	get_tree().current_scene.add_child(w)
	get_tree().create_timer(_warn_time).timeout.connect(w.queue_free)


func _calc_direction(from: Vector2, edge: int) -> Vector2:
	if _straight_mode:
		match edge:
			0: return Vector2(0.0,  1.0)
			1: return Vector2(0.0, -1.0)
			2: return Vector2(1.0,  0.0)
			3: return Vector2(-1.0, 0.0)
		return Vector2.DOWN

	# Diagonal: 10s hareketsiz oyuncuya nişan al, yoksa merkeze
	var aim: Vector2
	if _player != null and _player_still_time >= STILL_THRESHOLD:
		aim = _player.global_position
	else:
		aim = Vector2(324.0, (_cam_top() + _cam_bot()) / 2.0)

	var to_aim := (aim - from).normalized()
	var perp   := Vector2(-to_aim.y, to_aim.x)
	var target := aim + perp * randf_range(-SPREAD, SPREAD)
	return (target - from).normalized()


# ─── Pool ─────────────────────────────────────────────────────────────────────

func _get_bullet() -> Bullet:
	for b in _pool:
		if not b.active:
			return b
	var b: Bullet = BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(b)
	b.hit_player.connect(_on_bullet_hit_player)
	_pool.append(b)
	return b


func _get_fast_bullet() -> Bullet:
	for b in _fast_pool:
		if not b.active:
			return b
	var b: Bullet = FAST_BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(b)
	b.hit_player.connect(_on_bullet_hit_player)
	_fast_pool.append(b)
	return b


func _on_bullet_hit_player() -> void:
	hazard_hit_player.emit()
