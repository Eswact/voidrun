class_name GroundCrack extends BaseHazard

const TRAP_SCENE := preload("res://scenes/hazards/TrapZone.tscn")

const SPAWN_MARGIN := 90.0
const ARENA_W      := 648.0

var _zone_count:      int   = 2
var _warn_duration:   float = 1.5
var _active_duration: float = 3.0
var _pool: Array[TrapZone] = []


func activate(params: Dictionary) -> void:
	_zone_count      = params.get("count",           2)
	_warn_duration   = params.get("warn_duration",   1.5)
	_active_duration = params.get("active_duration", 3.0)
	super.activate(params)
	for i in _zone_count:
		_spawn_zone()


func deactivate() -> void:
	super.deactivate()  # active = false önce — zone_finished callback'i yeni zone açmaz
	for z in _pool:
		if z.active:
			z.retire()


func update_params(params: Dictionary) -> void:
	if not active:
		return
	_warn_duration   = params.get("warn_duration",   _warn_duration)
	_active_duration = params.get("active_duration", _active_duration)
	var new_count: int = params.get("count", _zone_count)
	if new_count > _zone_count:
		for i in range(_zone_count, new_count):
			_spawn_zone()
	_zone_count = new_count


func _spawn_zone() -> void:
	var z        := _get_from_pool()
	var director := get_parent()
	var top: float = director.get_cam_top() + SPAWN_MARGIN
	var bot: float = director.get_cam_bot() - SPAWN_MARGIN
	var pos      := Vector2(
		randf_range(SPAWN_MARGIN, ARENA_W - SPAWN_MARGIN),
		randf_range(top, bot)
	)
	z.launch(pos, _warn_duration, _active_duration)


func _get_from_pool() -> TrapZone:
	for z in _pool:
		if not z.active:
			return z
	var z: TrapZone = TRAP_SCENE.instantiate()
	get_tree().current_scene.add_child(z)
	z.hit_player.connect(_on_trap_hit_player)
	z.zone_finished.connect(func(): _on_zone_finished())
	_pool.append(z)
	return z


func _on_zone_finished() -> void:
	if active:
		_spawn_zone()


func _on_trap_hit_player() -> void:
	hazard_hit_player.emit()
