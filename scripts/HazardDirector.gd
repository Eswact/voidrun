extends Node

const _HomingStreamScript := preload("res://scripts/hazards/HomingStream.gd")
const _LaserStreamScript  := preload("res://scripts/hazards/LaserStream.gd")

signal difficulty_changed(phase: int)
signal shake_requested(intensity: float, duration: float)

@export var player_path: NodePath

var survival_time: float = 0.0
var is_running: bool = false
var player: CharacterBody2D

var _cam:       Camera2D = null
var _screen_h:  float    = 0.0
var _arena_h:   float    = 0.0
var _play_rect: Rect2    = Rect2()

var _current_phase: int = -1
var _phase_thresholds: Array = [0, 30, 60, 90]
var _timeline_index: int = 0

var timeline: Array = [
	# ══ BÖLÜM 1 · ISINMA (0-20s) ══════════════════════════════════════════
	{ "at": 0,   "spawn":  "straight_stream", "params": { "rate": 1.0,  "speed": 120.0, "straight": true, "warn_time": 1.1 } },

	# ══ BÖLÜM 2 · TEMEL (20-45s) ══════════════════════════════════════════
	{ "at": 20,  "update": "straight_stream", "params": { "rate": 1.7,  "speed": 140.0, "warn_time": 0.95 } },
	{ "at": 35,  "update": "straight_stream", "params": { "rate": 2.4,  "speed": 155.0, "warn_time": 0.85 } },

	# ══ BÖLÜM 3 · ÇAPRAZ (45-75s) ══════════════════════════════════════════
	{ "at": 45,  "update": "straight_stream", "params": { "rate": 0.7,  "speed": 145.0 } },
	{ "at": 45,  "spawn":  "diag_stream",     "params": { "rate": 0.85, "speed": 230.0, "straight": false, "warn_time": 0.7 } },
	{ "at": 55,  "spawn":  "laser_stream",    "params": { "count": 1, "gap": 11.0, "h_bias": 0.85, "warn_time": 1.1, "lethal_time": 1.8, "stagger": 0.0 } },
	{ "at": 60,  "spawn":  "explosive_projectile", "params": { "rate": 0.18, "spread_count": 4, "warn_duration": 1.1 } },
	{ "at": 68,  "update": "diag_stream",     "params": { "rate": 1.2,  "speed": 260.0 } },

	# ══ ÖZEL 1 · SEKEN MERMİLER (75-110s) ═════════════════════════════════
	{ "at": 75,  "shake": true, "intensity": 10.0, "duration": 0.5 },
	{ "at": 75,  "stop":  "straight_stream" },
	{ "at": 75,  "stop":  "diag_stream" },
	{ "at": 75,  "stop":  "explosive_projectile" },
	{ "at": 75,  "stop":  "laser_stream" },
	{ "at": 75,  "spawn": "bounce_stream",    "params": { "rate": 0.85, "speed": 210.0, "max_bullets": 30 } },
	{ "at": 95,  "update": "bounce_stream",   "params": { "rate": 1.15, "speed": 235.0, "max_bullets": 42 } },

	# ══ BÖLÜM 4 · TOPARLANMA + ZEMİN TUZAKLARI (110-155s) ═════════════════
	{ "at": 110, "shake": true, "intensity": 6.0, "duration": 0.3 },
	{ "at": 110, "stop":  "bounce_stream" },
	{ "at": 110, "spawn": "straight_stream",  "params": { "rate": 0.9, "speed": 150.0, "straight": true, "warn_time": 0.85 } },
	{ "at": 110, "spawn": "diag_stream",      "params": { "rate": 0.85, "speed": 265.0, "straight": false, "warn_time": 0.65 } },
	{ "at": 110, "spawn": "explosive_projectile", "params": { "rate": 0.3, "spread_count": 6, "warn_duration": 1.0 } },
	{ "at": 110, "spawn": "ground_crack",     "params": { "count": 2, "warn_duration": 2.0, "active_duration": 3.2 } },
	{ "at": 120, "spawn": "laser_stream",     "params": { "count": 1, "gap": 10.0, "h_bias": 0.8, "warn_time": 1.0, "lethal_time": 1.9, "stagger": 0.0 } },
	{ "at": 132, "update": "straight_stream", "params": { "rate": 1.2,  "speed": 163.0 } },

	# ══ ÖZEL 2 · TAKİP EDEN MERMİLER (155-190s) ═══════════════════════════
	{ "at": 155, "shake": true, "intensity": 10.0, "duration": 0.5 },
	{ "at": 155, "stop":  "straight_stream" },
	{ "at": 155, "stop":  "diag_stream" },
	{ "at": 155, "stop":  "explosive_projectile" },
	{ "at": 155, "stop":  "ground_crack" },
	{ "at": 155, "stop":  "laser_stream" },
	{ "at": 155, "spawn": "homing_stream",    "params": { "rate": 0.35, "warn_time": 0.65 } },
	{ "at": 175, "update": "homing_stream",   "params": { "rate": 0.6 } },

	# ══ BÖLÜM 5 · YOĞUN (190-250s) ════════════════════════════════════════
	{ "at": 190, "shake": true, "intensity": 7.0, "duration": 0.4 },
	{ "at": 190, "stop":  "homing_stream" },
	{ "at": 190, "spawn": "straight_stream",  "params": { "rate": 1.0,  "speed": 163.0, "straight": true, "warn_time": 0.78 } },
	{ "at": 190, "spawn": "diag_stream",      "params": { "rate": 1.15, "speed": 280.0, "straight": false, "warn_time": 0.58 } },
	{ "at": 190, "spawn": "explosive_projectile", "params": { "rate": 0.4, "spread_count": 7, "warn_duration": 0.85 } },
	{ "at": 190, "spawn": "ground_crack",     "params": { "count": 2, "warn_duration": 1.5, "active_duration": 2.8 } },
	{ "at": 200, "spawn": "laser_stream",     "params": { "count": 1, "gap": 9.0,  "h_bias": 0.75, "warn_time": 1.0, "lethal_time": 2.0, "stagger": 0.0 } },
	{ "at": 215, "update": "diag_stream",     "params": { "rate": 1.4,  "speed": 300.0 } },
	{ "at": 215, "update": "explosive_projectile", "params": { "rate": 0.55, "spread_count": 9 } },
	{ "at": 235, "update": "ground_crack",    "params": { "count": 3, "warn_duration": 1.3 } },

	# ══ ÖZEL 3 · SEKEN + PATLAYAN KOMBO (250-285s) ═════════════════════════
	{ "at": 250, "shake": true, "intensity": 12.0, "duration": 0.6 },
	{ "at": 250, "stop":  "straight_stream" },
	{ "at": 250, "stop":  "diag_stream" },
	{ "at": 250, "stop":  "ground_crack" },
	{ "at": 250, "stop":  "laser_stream" },
	{ "at": 250, "spawn": "bounce_stream",    "params": { "rate": 1.3, "speed": 260.0, "max_bullets": 48 } },
	{ "at": 268, "update": "bounce_stream",   "params": { "rate": 1.65, "speed": 278.0 } },

	# ══ ÖZEL 4 · LAZERLER (285-320s) ══════════════════════════════════════════
	{ "at": 285, "shake": true, "intensity": 10.0, "duration": 0.6 },
	{ "at": 285, "stop":  "bounce_stream" },
	{ "at": 285, "spawn": "laser_stream",     "params": { "h_bias": 0.75, "count": 2, "stagger": 0.55, "warn_time": 1.0, "lethal_time": 2.2, "gap": 0.45 } },
	{ "at": 302, "update": "laser_stream",    "params": { "count": 3, "stagger": 0.0 } },
	{ "at": 313, "update": "laser_stream",    "params": { "count": 1, "sweep": true, "sweep_speed": 35.0, "warn_time": 1.2 } },

	# ══ FİNAL + ENDLESS GİRİŞ (320s+) ══════════════════════════════════════
	{ "at": 320, "shake": true, "intensity": 8.0, "duration": 0.4 },
	{ "at": 320, "stop":  "laser_stream" },
	{ "at": 320, "spawn": "straight_stream",  "params": { "rate": 1.5,  "speed": 175.0, "straight": true, "warn_time": 0.7 } },
	{ "at": 320, "spawn": "diag_stream",      "params": { "rate": 1.6,  "speed": 320.0, "straight": false, "warn_time": 0.5 } },
	{ "at": 320, "update": "explosive_projectile", "params": { "rate": 0.8, "spread_count": 10, "warn_duration": 0.75 } },
	{ "at": 320, "spawn": "ground_crack",     "params": { "count": 4, "warn_duration": 1.2, "active_duration": 2.5 } },
	{ "at": 325, "spawn": "laser_stream",     "params": { "count": 1, "gap": 10.0, "h_bias": 0.75, "warn_time": 1.0, "lethal_time": 2.0, "stagger": 0.0 } },

	# ══ ENDLESS MODE (335s+) ════════════════════════════════════════════════
	{ "at": 335, "shake": true, "intensity": 14.0, "duration": 0.7 },
	{ "at": 355, "update": "laser_stream",    "params": { "gap": 9.0 } },
	{ "at": 355, "update": "straight_stream", "params": { "rate": 2.0,  "speed": 190.0 } },
	{ "at": 355, "update": "diag_stream",     "params": { "rate": 2.0,  "speed": 340.0 } },
	{ "at": 355, "update": "explosive_projectile", "params": { "rate": 1.0, "spread_count": 12, "warn_duration": 0.65 } },
	{ "at": 385, "update": "ground_crack",    "params": { "count": 5,  "warn_duration": 1.0 } },
	{ "at": 395, "update": "straight_stream", "params": { "rate": 2.5,  "speed": 205.0, "warn_time": 0.6 } },
	{ "at": 395, "update": "diag_stream",     "params": { "rate": 2.5,  "speed": 360.0 } },
	{ "at": 425, "update": "explosive_projectile", "params": { "rate": 1.2, "spread_count": 14, "warn_duration": 0.55 } },
	{ "at": 435, "update": "ground_crack",    "params": { "count": 6,  "warn_duration": 0.9 } },
	{ "at": 455, "update": "straight_stream", "params": { "rate": 3.0,  "speed": 220.0 } },
	{ "at": 455, "update": "diag_stream",     "params": { "rate": 3.0,  "speed": 380.0 } },
	{ "at": 485, "update": "explosive_projectile", "params": { "rate": 1.4, "spread_count": 16, "warn_duration": 0.5 } },
	{ "at": 495, "update": "ground_crack",    "params": { "count": 7,  "warn_duration": 0.8 } },
	{ "at": 515, "update": "straight_stream", "params": { "rate": 3.5,  "speed": 240.0, "warn_time": 0.5 } },
	{ "at": 515, "update": "diag_stream",     "params": { "rate": 3.5,  "speed": 400.0, "warn_time": 0.4 } },
]

var _hazard_scenes: Dictionary = {
	"straight_stream":      "res://scenes/hazards/ProjectileStream.tscn",
	"diag_stream":          "res://scenes/hazards/ProjectileStream.tscn",
	"explosive_projectile": "res://scenes/hazards/ExplosiveProjectile.tscn",
	"ground_crack":         "res://scenes/hazards/GroundCrack.tscn",
}

var pools: Dictionary = {
	"straight_stream":      [],
	"diag_stream":          [],
	"explosive_projectile": [],
	"ground_crack":         [],
	"bounce_stream":        [],
	"homing_stream":        [],
	"laser_stream":         [],
}

var _hazard_factories: Dictionary = {}


func _ready() -> void:
	_hazard_factories["bounce_stream"]  = func() -> BaseHazard: return BounceStream.new()
	_hazard_factories["homing_stream"]  = func() -> BaseHazard: return _HomingStreamScript.new()
	_hazard_factories["laser_stream"]   = func() -> BaseHazard: return _LaserStreamScript.new()
	if player_path:
		player = get_node(player_path)


func setup(screen_h: float, arena_h: float, cam: Camera2D, play_rect: Rect2) -> void:
	_screen_h  = screen_h
	_arena_h   = arena_h
	_cam       = cam
	_play_rect = play_rect
	if not player:
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D


func get_cam_top() -> float:
	if not _cam or _screen_h <= 0.0:
		return 0.0
	var py := (_cam.get_parent() as Node2D).global_position.y
	return clampf(py - _screen_h * 0.5, 0.0, _arena_h - _screen_h)


func get_cam_bot() -> float:
	return get_cam_top() + _screen_h


func get_arena_h() -> float:
	return _arena_h


func get_play_rect() -> Rect2:
	return _play_rect


func start() -> void:
	survival_time = 0.0
	_timeline_index = 0
	_current_phase = -1
	is_running = true


func stop() -> void:
	is_running = false
	for type in pools:
		for h: BaseHazard in pools[type]:
			if h.active:
				h.deactivate()


func restart_from(time: float) -> void:
	survival_time   = time
	_timeline_index = 0
	_current_phase  = -1
	is_running      = true


func _process(delta: float) -> void:
	if not is_running:
		return
	survival_time += delta / maxf(Engine.time_scale, 0.01)
	_check_phase()
	_check_timeline()


func _check_phase() -> void:
	for i in range(_phase_thresholds.size() - 1, -1, -1):
		if survival_time >= _phase_thresholds[i] and _current_phase < i:
			_current_phase = i
			difficulty_changed.emit(i)
			break


func _check_timeline() -> void:
	while _timeline_index < timeline.size():
		var entry = timeline[_timeline_index]
		if survival_time >= entry["at"]:
			if entry.has("spawn"):
				_spawn_hazard(entry["spawn"], entry["params"])
			elif entry.has("stop"):
				_stop_hazard_type(entry["stop"])
			elif entry.has("update"):
				_update_hazard_type(entry["update"], entry["params"])
			elif entry.has("shake"):
				shake_requested.emit(entry.get("intensity", 8.0), entry.get("duration", 0.4))
			_timeline_index += 1
		else:
			break


func _stop_hazard_type(type: String) -> void:
	for h in pools.get(type, []):
		if h.active:
			h.deactivate()


func _update_hazard_type(type: String, params: Dictionary) -> void:
	for h in pools.get(type, []):
		if h.active:
			h.update_params(params)


func _spawn_hazard(type: String, params: Dictionary) -> void:
	var hazard = _get_from_pool(type)
	if hazard == null:
		return
	hazard.activate(params)


func _get_from_pool(type: String) -> BaseHazard:
	for h in pools[type]:
		if not h.active:
			return h
	var h: BaseHazard
	if _hazard_factories.has(type):
		h = _hazard_factories[type].call()
	elif _hazard_scenes.has(type):
		var packed: PackedScene = load(_hazard_scenes[type])
		if packed == null:
			push_warning("HazardDirector: sahne bulunamadı — '%s'" % type)
			return null
		h = packed.instantiate()
	else:
		return null
	add_child(h)
	h.hazard_hit_player.connect(_on_hazard_hit_player)
	pools[type].append(h)
	return h


func _on_hazard_hit_player() -> void:
	stop()
	if player and player.has_method("die"):
		player.die()
