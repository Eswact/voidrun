class_name ExplosiveProjectile extends BaseHazard

const EXPL_BULLET_SCENE := preload("res://scenes/hazards/ExplosiveBullet.tscn")

const ARENA_W        := 648.0
const WARNING_SCRIPT := preload("res://scripts/hazards/BulletWarning.gd")
const WARN_TIME      := 0.5

var _rate: float          = 0.35
var _spread_count: int    = 8
var _warn_duration: float = 0.7
var _timer: Timer
var _pool: Array[ExplosiveBullet] = []


func _ready() -> void:
	_timer = Timer.new()
	add_child(_timer)
	_timer.timeout.connect(_fire)


func activate(params: Dictionary) -> void:
	_rate          = params.get("rate",          0.35)
	_spread_count  = params.get("spread_count",  8)
	_warn_duration = params.get("warn_duration", 0.7)
	_timer.wait_time = 1.0 / _rate
	_timer.start()
	super.activate(params)


func deactivate() -> void:
	_timer.stop()
	for eb in _pool:
		eb.force_retire()
	super.deactivate()


func update_params(params: Dictionary) -> void:
	if not active:
		return
	_rate          = params.get("rate",          _rate)
	_spread_count  = params.get("spread_count",  _spread_count)
	_warn_duration = params.get("warn_duration", _warn_duration)
	_timer.wait_time = 1.0 / _rate


func _fire() -> void:
	var edge     := randi() % 4
	var director := get_parent()
	var top:  float = director.get_cam_top()
	var bot:  float = director.get_cam_bot()
	var rect: Rect2 = director.get_play_rect()
	var spawn_top := maxf(top - 30.0, rect.position.y)
	var spawn_bot := minf(bot + 30.0, rect.end.y)
	var mid_y     := maxf(top, rect.position.y)
	var end_y     := minf(bot, rect.end.y)
	var spawn_pos: Vector2
	match edge:
		0: spawn_pos = Vector2(randf_range(rect.position.x, rect.end.x), spawn_top)
		1: spawn_pos = Vector2(randf_range(rect.position.x, rect.end.x), spawn_bot)
		2: spawn_pos = Vector2(rect.position.x, randf_range(mid_y, end_y))
		3: spawn_pos = Vector2(rect.end.x,      randf_range(mid_y, end_y))

	_show_warning(spawn_pos)
	await get_tree().create_timer(WARN_TIME).timeout
	if not active:
		return

	var eb := _get_from_pool()
	eb.launch(spawn_pos, _spread_count, _warn_duration)


func _show_warning(pos: Vector2) -> void:
	var w := Node2D.new()
	w.set_script(WARNING_SCRIPT)
	w.position = pos
	get_tree().current_scene.add_child(w)
	get_tree().create_timer(WARN_TIME).timeout.connect(w.queue_free)


func _get_from_pool() -> ExplosiveBullet:
	for eb in _pool:
		if not eb.active:
			return eb
	var eb: ExplosiveBullet = EXPL_BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(eb)
	eb.hit_player.connect(_on_hit_player)
	_pool.append(eb)
	return eb


func _on_hit_player() -> void:
	hazard_hit_player.emit()
