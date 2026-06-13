extends Node

const BUBBLE_SCENE := preload("res://scenes/ability/AbilityBubble.tscn")
const DESIGN_W     := 648.0
const SPAWN_MARGIN := 80.0
const MIN_INTERVAL := 15.0
const MAX_INTERVAL := 30.0

# Ağırlıklı havuz: CLEAR x4, SLOW x4, INVINCIBILITY x1
const _TYPE_POOL := [
	AbilityBubble.Type.SCREEN_CLEAR,
	AbilityBubble.Type.SCREEN_CLEAR,
	AbilityBubble.Type.SCREEN_CLEAR,
	AbilityBubble.Type.SCREEN_CLEAR,
	AbilityBubble.Type.TIME_SLOW,
	AbilityBubble.Type.TIME_SLOW,
	AbilityBubble.Type.TIME_SLOW,
	AbilityBubble.Type.TIME_SLOW,
	AbilityBubble.Type.INVINCIBILITY,
]

var _player:    Node          = null
var _bubble:    AbilityBubble = null
var _timer:     Timer
var _cam:       Camera2D      = null
var _screen_h:  float         = 0.0
var _play_rect: Rect2         = Rect2()


func _ready() -> void:
	_timer          = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timer)
	_player = get_tree().get_first_node_in_group("player")


func setup(screen_h: float, cam: Camera2D, play_rect: Rect2) -> void:
	_screen_h  = screen_h
	_cam       = cam
	_play_rect = play_rect


func start() -> void:
	_start_timer()


func stop() -> void:
	_timer.stop()
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = null


func on_ability_used() -> void:
	_start_timer()


func _start_timer() -> void:
	_timer.wait_time = randf_range(MIN_INTERVAL, MAX_INTERVAL)
	_timer.start()


func _on_timer() -> void:
	if _player and _player.get("has_ability"):
		_timer.start(5.0)  # oyuncu ability'sini kullanana kadar kısa aralıkla tekrar dene
		return
	if is_instance_valid(_bubble):
		return
	_spawn_bubble()


func _spawn_bubble() -> void:
	_bubble = BUBBLE_SCENE.instantiate() as AbilityBubble
	get_tree().current_scene.add_child(_bubble)

	var cam_top: float
	var cam_bot: float
	if _cam and _screen_h > 0.0:
		var py  := (_cam.get_parent() as Node2D).global_position.y
		cam_top = clampf(py - _screen_h * 0.5, _play_rect.position.y, _play_rect.end.y - _screen_h)
		cam_bot = cam_top + _screen_h
	else:
		cam_top = _play_rect.position.y
		cam_bot = _play_rect.end.y

	var min_x := _play_rect.position.x + SPAWN_MARGIN
	var max_x := _play_rect.end.x      - SPAWN_MARGIN
	var min_y := maxf(cam_top + SPAWN_MARGIN, _play_rect.position.y + SPAWN_MARGIN)
	var max_y := minf(cam_bot - SPAWN_MARGIN, _play_rect.end.y      - SPAWN_MARGIN)

	var pos := Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))

	_bubble.spawn(pos, _TYPE_POOL.pick_random())
	_bubble.picked_up.connect(_on_bubble_picked_up)
	_bubble.expired.connect(_on_bubble_expired)


func _on_bubble_picked_up(_type: int) -> void:
	_bubble = null


func _on_bubble_expired() -> void:
	_bubble = null
	_start_timer()
