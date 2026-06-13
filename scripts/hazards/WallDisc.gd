class_name WallDisc extends BaseHazard

const DISC_SCENE := preload("res://scenes/hazards/DiscBody.tscn")

var _count:        int   = 1
var _travel_speed: float = 180.0
var _spin_speed:   float = 4.0
var _pool: Array[DiscBody] = []


func activate(params: Dictionary) -> void:
	_count        = params.get("count",         1)
	_travel_speed = params.get("travel_speed", 180.0)
	_spin_speed   = params.get("spin_speed",   4.0)
	for i in _count:
		var disc := _get_from_pool()
		disc.launch(float(i) / float(_count), _travel_speed, _spin_speed)
	super.activate(params)


func deactivate() -> void:
	for d in _pool:
		if d.active:
			d.retire()
	super.deactivate()


func update_params(params: Dictionary) -> void:
	if not active:
		return
	_travel_speed = params.get("travel_speed", _travel_speed)
	_spin_speed   = params.get("spin_speed",   _spin_speed)
	for d in _pool:
		if d.active:
			d.update_speed(_travel_speed, _spin_speed)
	var new_count: int = params.get("count", _count)
	if new_count > _count:
		for i in range(_count, new_count):
			var disc := _get_from_pool()
			disc.launch(float(i) / float(new_count), _travel_speed, _spin_speed)
	_count = new_count


func _get_from_pool() -> DiscBody:
	for d in _pool:
		if not d.active:
			return d
	var d: DiscBody = DISC_SCENE.instantiate()
	get_tree().current_scene.add_child(d)
	d.hit_player.connect(_on_disc_hit_player)
	_pool.append(d)
	return d


func _on_disc_hit_player() -> void:
	hazard_hit_player.emit()
