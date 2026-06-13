class_name LaserStream extends BaseHazard

var _warn_time:   float = 1.0
var _lethal_time: float = 2.2
var _h_bias:      float = 0.75  # horizontal probability
var _count:       int   = 2     # beams per burst
var _stagger:     float = 0.5   # seconds between beams; 0 = simultaneous
var _sweep_speed: float = 0.0   # 0 = static
var _gap:         float = 0.45  # extra pause after burst ends before next one

var _burst_timer: Timer
var _pool: Array[LaserBeam] = []


func _ready() -> void:
	_burst_timer          = Timer.new()
	_burst_timer.one_shot = false
	add_child(_burst_timer)
	_burst_timer.timeout.connect(_on_burst_timer)


func activate(params: Dictionary) -> void:
	_apply_params(params)
	_burst_timer.wait_time = _burst_period()
	_burst_timer.start()
	_fire_burst()
	super.activate(params)


func deactivate() -> void:
	_burst_timer.stop()
	for b: LaserBeam in _pool:
		if b.active:
			b.retire()
	super.deactivate()


func update_params(params: Dictionary) -> void:
	if not active:
		return
	_apply_params(params)
	_burst_timer.wait_time = _burst_period()


func _apply_params(params: Dictionary) -> void:
	_warn_time   = params.get("warn_time",   _warn_time)
	_lethal_time = params.get("lethal_time", _lethal_time)
	_h_bias      = params.get("h_bias",      _h_bias)
	_count       = params.get("count",       _count)
	_stagger     = params.get("stagger",     _stagger)
	if params.has("sweep"):
		_sweep_speed = params.get("sweep_speed", 35.0) if params["sweep"] else 0.0
	else:
		_sweep_speed = params.get("sweep_speed", _sweep_speed)
	_gap = params.get("gap", _gap)


func _burst_period() -> float:
	return _warn_time + _lethal_time + _gap


func _on_burst_timer() -> void:
	_fire_burst()


func _fire_burst() -> void:
	if not active:
		return
	if _stagger > 0.0:
		_fire_staggered(0)
	else:
		for _i: int in _count:
			_fire_one()


func _fire_staggered(index: int) -> void:
	if not active or index >= _count:
		return
	_fire_one()
	await get_tree().create_timer(_stagger).timeout
	_fire_staggered(index + 1)


func _fire_one() -> void:
	var director: Node = get_parent()
	var play_rect: Rect2 = director.get_play_rect()
	var cam_top: float   = director.get_cam_top()
	var cam_bot: float   = director.get_cam_bot()
	var orientation: int = 0 if randf() < _h_bias else 1

	var pos: Vector2
	var span: float

	if orientation == 0:
		span      = play_rect.size.x
		var y: float = randf_range(cam_top + 70.0, cam_bot - 70.0)
		pos = Vector2(play_rect.position.x + span * 0.5, y)
	else:
		span      = cam_bot - cam_top
		var x: float = randf_range(play_rect.position.x + 70.0, play_rect.end.x - 70.0)
		pos = Vector2(x, cam_top + span * 0.5)

	var b: LaserBeam = _get_or_create()
	b.launch(pos, orientation, span, cam_top, cam_bot, play_rect,
			_warn_time, _lethal_time, _sweep_speed, director)


func _get_or_create() -> LaserBeam:
	for b: LaserBeam in _pool:
		if not b.active:
			return b
	var b: LaserBeam = LaserBeam.new()
	get_tree().current_scene.add_child(b)
	b.hit_player.connect(_on_hit_player)
	_pool.append(b)
	return b


func _on_hit_player() -> void:
	hazard_hit_player.emit()
