class_name HomingStream extends BaseHazard

const WARNING_SCRIPT := preload("res://scripts/hazards/BulletWarning.gd")

var _rate:      float = 0.4
var _warn_time: float = 0.55
var _timer:     Timer
var _pool:      Array[HomingBullet] = []


func _ready() -> void:
	_timer = Timer.new()
	add_child(_timer)
	_timer.timeout.connect(_fire)


func activate(params: Dictionary) -> void:
	_rate      = params.get("rate",      _rate)
	_warn_time = params.get("warn_time", _warn_time)
	_timer.wait_time = 1.0 / _rate
	_timer.start()
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
	_rate      = params.get("rate",      _rate)
	_warn_time = params.get("warn_time", _warn_time)
	_timer.wait_time = 1.0 / _rate


func _fire() -> void:
	var edge:      int     = randi() % 4
	var spawn_pos: Vector2 = _edge_spawn_pos(edge)
	_show_warning(spawn_pos)
	await get_tree().create_timer(_warn_time).timeout
	if not active:
		return
	var b:   HomingBullet = _get_or_create()
	var dir: Vector2      = _initial_dir(spawn_pos)
	b.launch(spawn_pos, dir)


func _edge_spawn_pos(edge: int) -> Vector2:
	var director        := get_parent()
	var rect: Rect2      = director.get_play_rect()
	var top:  float      = director.get_cam_top()
	var bot:  float      = director.get_cam_bot()
	var mid_y: float     = maxf(top, rect.position.y)
	var end_y: float     = minf(bot, rect.end.y)
	match edge:
		0: return Vector2(randf_range(rect.position.x, rect.end.x), maxf(top - 20.0, rect.position.y))
		1: return Vector2(randf_range(rect.position.x, rect.end.x), minf(bot + 20.0, rect.end.y))
		2: return Vector2(rect.position.x, randf_range(mid_y, end_y))
		3: return Vector2(rect.end.x,      randf_range(mid_y, end_y))
	return Vector2.ZERO


func _initial_dir(from: Vector2) -> Vector2:
	var director    := get_parent()
	var rect: Rect2  = director.get_play_rect()
	var top:  float  = director.get_cam_top()
	var bot:  float  = director.get_cam_bot()
	var center := Vector2(rect.get_center().x, (top + bot) * 0.5)
	return (center - from).normalized()


func _show_warning(pos: Vector2) -> void:
	var w := Node2D.new()
	w.set_script(WARNING_SCRIPT)
	w.position = pos
	get_tree().current_scene.add_child(w)
	get_tree().create_timer(_warn_time).timeout.connect(w.queue_free)


func _get_or_create() -> HomingBullet:
	for b in _pool:
		if not b.active:
			return b
	var b := HomingBullet.new()
	get_tree().current_scene.add_child(b)
	b.hit_player.connect(func(): hazard_hit_player.emit())
	_pool.append(b)
	return b
