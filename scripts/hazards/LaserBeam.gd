class_name LaserBeam extends Area2D

signal hit_player
signal beam_finished

const WARN_COLOR  := Color(1.0, 0.18, 0.18, 0.8)
const CORE_COLOR  := Color(1.0, 0.95, 0.75, 1.0)
const MID_COLOR   := Color(1.0, 0.45, 0.1,  0.55)
const GLOW_COLOR  := Color(1.0, 0.2,  0.05, 0.18)

var active:       bool  = false

var _orientation: int   = 0      # 0 = horizontal, 1 = vertical
var _span:        float = 0.0
var _cam_min:     float = 0.0
var _cam_max:     float = 0.0
var _play_rect:   Rect2 = Rect2()
var _sweep_speed: float = 0.0
var _sweep_dir:   float = 1.0
var _is_lethal:   bool  = false
var _director:    Node  = null
var _warn_tween:  Tween = null

var _line_glow: Line2D
var _line_mid:  Line2D
var _line_core: Line2D
var _col_shape: RectangleShape2D
var _col_node:  CollisionShape2D


func _ready() -> void:
	add_to_group("clearable")

	_line_glow = _make_line(26.0, GLOW_COLOR)
	_line_mid  = _make_line(11.0, MID_COLOR)
	_line_core = _make_line(2.5,  WARN_COLOR)

	_col_shape         = RectangleShape2D.new()
	_col_node          = CollisionShape2D.new()
	_col_node.shape    = _col_shape
	_col_node.disabled = true
	add_child(_col_node)

	body_entered.connect(_on_body_entered)
	hide()


func _process(delta: float) -> void:
	if not active:
		return
	if _director:
		_cam_min = _director.get_cam_top()
		_cam_max = _director.get_cam_bot()
	# vertical lasers track camera center so they always span the full visible screen
	if _orientation == 1:
		global_position.y = (_cam_min + _cam_max) * 0.5
	if _sweep_speed == 0.0:
		return
	var d: float = delta / maxf(Engine.time_scale, 0.01)
	var margin: float = 55.0
	if _orientation == 0:
		global_position.y += _sweep_speed * _sweep_dir * d
		if global_position.y <= _cam_min + margin:
			global_position.y = _cam_min + margin
			_sweep_dir = 1.0
		elif global_position.y >= _cam_max - margin:
			global_position.y = _cam_max - margin
			_sweep_dir = -1.0
	else:
		global_position.x += _sweep_speed * _sweep_dir * d
		if global_position.x <= _play_rect.position.x + margin:
			global_position.x = _play_rect.position.x + margin
			_sweep_dir = 1.0
		elif global_position.x >= _play_rect.end.x - margin:
			global_position.x = _play_rect.end.x - margin
			_sweep_dir = -1.0


func launch(pos: Vector2, orientation: int, span: float,
		cam_min: float, cam_max: float, play_rect: Rect2,
		warn_time: float, lethal_time: float,
		sweep_speed: float = 0.0, director: Node = null) -> void:
	active        = true
	_is_lethal    = false
	_orientation  = orientation
	_span         = span
	_cam_min      = cam_min
	_cam_max      = cam_max
	_play_rect    = play_rect
	_sweep_speed  = sweep_speed
	_sweep_dir    = 1.0 if randf() > 0.5 else -1.0
	_director     = director

	global_position = pos
	_build_geometry()

	_line_glow.visible      = false
	_line_mid.visible       = false
	_line_core.visible      = true
	_line_core.default_color = WARN_COLOR
	_line_core.width        = 2.5
	_line_core.modulate     = Color.WHITE

	_col_node.disabled = true
	monitoring         = false
	modulate.a         = 1.0
	show()

	_warn_tween = create_tween().set_loops(0)
	_warn_tween.tween_property(_line_core, "modulate:a", 0.2, 0.17)
	_warn_tween.tween_property(_line_core, "modulate:a", 1.0, 0.17)

	_run_sequence(warn_time, lethal_time)


func retire() -> void:
	if not active:
		return
	active     = false
	_is_lethal = false
	if _warn_tween:
		_warn_tween.kill()
		_warn_tween = null
	_col_node.disabled = true
	monitoring         = false
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		modulate.a = 1.0
		hide()
		beam_finished.emit()
	)


func _run_sequence(warn_time: float, lethal_time: float) -> void:
	await get_tree().create_timer(warn_time).timeout
	if not active:
		return
	_go_lethal()
	await get_tree().create_timer(lethal_time).timeout
	if not active:
		return
	retire()


func _go_lethal() -> void:
	_is_lethal = true
	if _warn_tween:
		_warn_tween.kill()
		_warn_tween = null
	_line_core.modulate      = Color.WHITE
	_line_core.default_color = CORE_COLOR
	_line_core.width         = 5.0
	_line_mid.visible        = true
	_line_glow.visible       = true
	_col_node.disabled       = false
	monitoring               = true
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.15, 0.06)
	tw.tween_property(self, "modulate:a", 1.0,  0.06)


func _build_geometry() -> void:
	var half: float = _span / 2.0
	var p0: Vector2
	var p1: Vector2
	if _orientation == 0:
		p0 = Vector2(-half, 0.0)
		p1 = Vector2( half, 0.0)
		_col_shape.size = Vector2(_span, 10.0)
	else:
		p0 = Vector2(0.0, -half)
		p1 = Vector2(0.0,  half)
		_col_shape.size = Vector2(10.0, _span)
	for line: Line2D in [_line_glow, _line_mid, _line_core]:
		line.clear_points()
		line.add_point(p0)
		line.add_point(p1)


func _make_line(w: float, color: Color) -> Line2D:
	var l: Line2D = Line2D.new()
	l.width          = w
	l.default_color  = color
	l.antialiased    = true
	l.begin_cap_mode = Line2D.LINE_CAP_NONE
	l.end_cap_mode   = Line2D.LINE_CAP_NONE
	add_child(l)
	return l


func _on_body_entered(body: Node2D) -> void:
	if not active or not _is_lethal:
		return
	if body.has_method("die") and not body.get("is_invincible"):
		hit_player.emit()
		retire()
