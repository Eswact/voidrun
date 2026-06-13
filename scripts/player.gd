extends CharacterBody2D

signal dead
signal ability_received(type: int)
signal ability_used(type: int)

@export var speed: float = 290.0
@export var dash_speed: float = 1000.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 5

var move_direction: Vector2 = Vector2.ZERO
var dash_direction: Vector2 = Vector2.ZERO
var last_facing_direction: Vector2 = Vector2.DOWN

const NEAR_MISS_DIST  := 28.0
const NEAR_MISS_FLASH := 0.12
const TRAIL_MAX       := 18
const TRAIL_SPACING   := 3.0

var is_dashing:             bool  = false
var can_dash:               bool  = true
var is_dead:                bool  = false
var is_invincible:          bool  = false
var has_ability:            bool  = false
var current_ability:        int   = -1
var _dash_cooldown_left:    float = 0.0
var _near_miss_timer:       float = 0.0
var _trail:                 Array[Vector2] = []

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var joystick:        Control          = $"../MobileUI/VirtualJoystick"
@onready var dash_button:     TouchScreenButton = $"../MobileUI/DashButtonContainer/DashButton"
@onready var _dash_label:     Label             = $"../MobileUI/DashButtonContainer/CooldownLabel"


func _ready() -> void:
	add_to_group("player")
	animated_sprite.speed_scale = 1.0
	dash_button.modulate.a = 0.9
	if _dash_label:
		_dash_label.text = ""
	_show_idle_pose()

func revive() -> void:
	is_dead        = false
	is_invincible  = true
	velocity       = Vector2.ZERO
	_trail.clear()
	set_physics_process(true)
	set_process(true)
	animated_sprite.speed_scale = 1.0
	_show_idle_pose()
	modulate = Color(0.35, 0.9, 1.0, 0.55)
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self): return
	for i: int in 6:
		modulate.a = 0.25 if i % 2 == 0 else 1.0
		await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self): return
	modulate      = Color.WHITE
	is_invincible = false


func die() -> void:
	if is_dead:
		return
	is_dead = true
	Input.vibrate_handheld(400)
	AudioManager.play_dead()
	velocity = Vector2.ZERO
	_trail.clear()
	set_physics_process(false)
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("dead"):
		animated_sprite.sprite_frames.set_animation_loop("dead", false)
		animated_sprite.speed_scale = 0.75
		animated_sprite.play("dead")
	else:
		set_process(false)
	dead.emit()


func _physics_process(_delta: float) -> void:

	# =========================
	# DASH STATE
	# =========================
	var ts := maxf(Engine.time_scale, 0.01)

	if is_dashing:
		velocity = dash_direction * dash_speed / ts
		move_and_slide()
		return

	# =========================
	# NORMAL MOVEMENT
	# =========================
	var input_dir = Vector2.ZERO

	if joystick:
		input_dir = joystick.get_output()

	move_direction = input_dir

	# Eğer joystick'ten bir girdi varsa, son bakılan yönü güncelle
	if move_direction != Vector2.ZERO:
		last_facing_direction = move_direction.normalized()

	velocity = move_direction * speed / ts

	move_and_slide()


func _process(delta: float) -> void:

	if not is_dead:
		animated_sprite.speed_scale = 1.0 / maxf(Engine.time_scale, 0.01)

	# =========================
	# DASH COOLDOWN UI
	# =========================
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left -= delta / maxf(Engine.time_scale, 0.01)
		if _dash_label:
			_dash_label.text = str(ceili(_dash_cooldown_left))

	# Near-miss renk flash
	if _near_miss_timer > 0.0:
		_near_miss_timer -= delta
		var t := _near_miss_timer / NEAR_MISS_FLASH
		modulate = Color(1.0, lerpf(1.0, 0.2, t), lerpf(1.0, 0.2, t), modulate.a)
	elif not is_invincible and not is_dead:
		modulate = Color(1.0, 1.0, 1.0, modulate.a)

	queue_redraw()

	if is_dead:
		return

	# Trail güncelleme
	if velocity.length() > 10.0:
		if _trail.is_empty() or global_position.distance_to(_trail[0]) >= TRAIL_SPACING:
			_trail.push_front(global_position)
			if _trail.size() > TRAIL_MAX:
				_trail.pop_back()
	elif _trail.size() > 0:
		_trail.pop_back()

	# Near-miss tespiti
	if not is_dashing and not is_invincible and _near_miss_timer <= 0.0:
		for node in get_tree().get_nodes_in_group("clearable"):
			if node.get("active") == true and global_position.distance_to(node.global_position) < NEAR_MISS_DIST:
				_near_miss_timer = NEAR_MISS_FLASH
				Input.vibrate_handheld(40)
				break

	# =========================
	# DASH ANIMATION
	# =========================
	if is_dashing:
		animated_sprite.rotation = 0.0
		return

	# =========================
	# WALK / IDLE ANIMATIONS
	# =========================
	if velocity != Vector2.ZERO:
		var abs_x: float = abs(velocity.x)
		var abs_y: float = abs(velocity.y)

		if abs_x >= abs_y:
			animated_sprite.flip_h = velocity.x < 0
			_play_walk("walk_right")
		elif velocity.y > 0:
			animated_sprite.flip_h = false
			_play_walk("walk_down")
		else:
			animated_sprite.flip_h = false
			_play_walk("walk_up")
		animated_sprite.rotation = 0.0
	else:
		animated_sprite.rotation = 0.0
		if animated_sprite.is_playing():
			_show_idle_pose()


func _draw() -> void:
	# Hareket izi — bağlı segmentler
	if _trail.size() >= 2:
		for i in range(_trail.size() - 1):
			var t: float = float(i) / float(TRAIL_MAX)
			draw_line(
				to_local(_trail[i]),
				to_local(_trail[i + 1]),
				Color(1.0, 1.0, 1.0, (1.0 - t) * 0.25),
				lerpf(14.0, 2.0, t),
				true
			)

	if is_dead:
		return

	# Yön göstergesi — sprite dikdörtgeninden eşit mesafede nokta (40x64 sprite)
	var dir := last_facing_direction.normalized()
	var tx: float = 28.0 / maxf(abs(dir.x), 0.001)
	var ty: float = 48.0 / maxf(abs(dir.y), 0.001)
	draw_circle(dir * (minf(tx, ty) + 10.0), 4.5, Color(1.0, 1.0, 1.0, 0.55))


func _play_walk(anim: String) -> void:
	if animated_sprite.animation == anim and animated_sprite.is_playing():
		return
	animated_sprite.play(anim)
	animated_sprite.frame = 1


func _play_dash_anim() -> void:
	animated_sprite.rotation = 0.0
	animated_sprite.flip_h   = false
	var abs_x: float = abs(dash_direction.x)
	var abs_y: float = abs(dash_direction.y)
	var anim: String
	if abs_x >= abs_y:
		anim = "dash_left" if dash_direction.x < 0 else "dash_right"
	elif dash_direction.y > 0:
		anim = "dash_down"
	else:
		anim = "dash_up"
	if not (animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim)):
		return
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(anim)


func _show_idle_pose() -> void:
	if not animated_sprite.sprite_frames:
		return
	var abs_x: float = abs(last_facing_direction.x)
	var abs_y: float = abs(last_facing_direction.y)
	var anim: String
	if abs_x > abs_y:
		anim = "walk_right"
		animated_sprite.flip_h = last_facing_direction.x < 0
	elif last_facing_direction.y >= 0.0:
		anim = "walk_down"
		animated_sprite.flip_h = false
	else:
		anim = "walk_up"
		animated_sprite.flip_h = false
	if not animated_sprite.sprite_frames.has_animation(anim):
		animated_sprite.stop()
		return
	animated_sprite.stop()
	animated_sprite.animation = anim
	animated_sprite.frame = 0


func receive_ability(type: int) -> void:
	has_ability     = true
	current_ability = type
	AudioManager.play_pickup()
	ability_received.emit(type)


func use_ability() -> void:
	if not has_ability or is_dead:
		return
	var type        := current_ability
	has_ability     = false
	current_ability = -1
	AudioManager.play_ability()
	ability_used.emit(type)


func _on_dash_pressed() -> void:
	# Karakterin hareket edip etmemesinden bağımsız, bekleme süresi dolduysa dash atabilir
	if can_dash and not is_dead:
		start_dash()


func start_dash() -> void:
	is_dashing     = true
	can_dash       = false
	is_invincible  = true
	dash_direction = last_facing_direction
	velocity       = dash_direction * dash_speed

	AudioManager.play_dash()
	_play_dash_anim()
	dash_button.modulate.a = 0.4

	await get_tree().create_timer(dash_duration, true, false, true).timeout
	is_dashing    = false
	is_invincible = false
	velocity      = Vector2.ZERO
	if is_dead:
		return
	animated_sprite.speed_scale = 1.0
	_show_idle_pose()

	_dash_cooldown_left = dash_cooldown
	await get_tree().create_timer(dash_cooldown, true, false, true).timeout

	can_dash            = true
	_dash_cooldown_left = 0.0
	dash_button.modulate.a = 0.9
	if _dash_label:
		_dash_label.text = ""
