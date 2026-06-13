extends Node2D

const DESIGN_W:         float = 648.0
const BORDER_SIDE:      float = 40.0
const IMAGE_BORDER_PX:  float = 224.0  # arena.png üst/alt dekoratif kenar kalınlığı (px)
const UI_BOTTOM_CLEAR:  float = 200.0  # butonlar için minimum alt boşluk (game unit)

const TEXTURE_BTN_EMPTY := preload("res://assets/sprites/mobile_ui/ability-button-empty.png")
const TEXTURE_BTN_CLEAR := preload("res://assets/sprites/mobile_ui/ability-button-clear.png")
const TEXTURE_BTN_GHOST := preload("res://assets/sprites/mobile_ui/ability-button-ghost.png")
const TEXTURE_BTN_SLOW  := preload("res://assets/sprites/mobile_ui/ability-button-slow.png")
const TEXTURE_CLEARED   := preload("res://assets/sprites/mobile_ui/cleared.png")

const TIME_SLOW_SCALE      := 0.3
const TIME_SLOW_DURATION   := 5.0
const GHOST_DURATION       := 5.0
const GHOST_BLINK_TIME     := 2.0
const GHOST_BLINK_COUNT    := 4

@onready var _timer_label:    Label             = $MobileUI/TimerLabel
@onready var _pause_button:   TextureButton     = $MobileUI/PauseButton
@onready var _special_button: TouchScreenButton = $MobileUI/SpecialButtonContainer/TouchScreenButton
@onready var _joystick:       VirtualJoystick   = $MobileUI/VirtualJoystick

var _is_dead:         bool     = false
var _camera:          Camera2D = null
var _shake_intensity: float    = 0.0
var _shake_duration:  float    = 0.0
var _arena_h:         float    = 0.0
var _screen_h:        float    = 0.0
var _play_rect:       Rect2    = Rect2()

var _death_screen:   DeathScreen = null
var _pause_screen:   PauseScreen = null
var _continue_count: int         = 0


func _ready() -> void:
	if OS.get_name() == "Android":
		var config := RequestConfiguration.new()
		config.test_device_ids = Secrets.TEST_DEVICE_IDS
		MobileAds.set_request_configuration(config)
		MobileAds.initialize()
	_setup_arena()
	_death_screen = preload("res://scenes/ui/DeathScreen.tscn").instantiate()
	add_child(_death_screen)
	_pause_screen = preload("res://scenes/ui/PauseScreen.tscn").instantiate()
	add_child(_pause_screen)
	$Player.dead.connect(_on_player_dead)
	$HazardDirector.shake_requested.connect(shake)
	$HazardDirector.start()

	_pause_button.texture_normal = load("res://assets/sprites/mobile_ui/pause.png")
	_pause_button.process_mode   = Node.PROCESS_MODE_ALWAYS
	_pause_button.pressed.connect(_on_pause_pressed)

	_special_button.texture_normal = TEXTURE_BTN_EMPTY
	_special_button.modulate.a     = 0.35
	_special_button.pressed.connect(func(): $Player.use_ability())
	$Player.ability_received.connect(_on_ability_received)
	$Player.ability_used.connect(_on_ability_used)
	$AbilityDirector.start()




func _process(_delta: float) -> void:
	var t: float = $HazardDirector.survival_time
	_timer_label.text = "%d:%02d" % [int(t) / 60, int(t) % 60]
	_update_shake(_delta)



func shake(intensity: float, duration: float) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_duration  = maxf(_shake_duration, duration)


func _update_shake(delta: float) -> void:
	if not _camera or _shake_duration <= 0.0:
		return
	_shake_duration  -= delta
	_shake_intensity  = lerpf(_shake_intensity, 0.0, delta * 10.0)
	_camera.offset    = Vector2(
		randf_range(-_shake_intensity, _shake_intensity),
		randf_range(-_shake_intensity, _shake_intensity)
	)
	if _shake_duration <= 0.0:
		_camera.offset = Vector2.ZERO


func _setup_arena() -> void:
	_screen_h = get_viewport().get_visible_rect().size.y

	var bg     := $Background as TextureRect
	var bg_tex := bg.texture

	var border_top:    float
	var border_bottom: float
	if bg_tex and bg_tex.get_width() > 0:
		_arena_h   = float(bg_tex.get_height()) * DESIGN_W / float(bg_tex.get_width())
		var img_border := IMAGE_BORDER_PX * DESIGN_W / float(bg_tex.get_width())
		border_top    = img_border
		border_bottom = maxf(img_border, UI_BOTTOM_CLEAR)
	else:
		_arena_h      = _screen_h
		border_top    = 80.0
		border_bottom = UI_BOTTOM_CLEAR

	var play_w := DESIGN_W - BORDER_SIDE * 2.0
	var play_h := _arena_h - border_top - border_bottom
	var mid_x  := DESIGN_W / 2.0
	var mid_y  := border_top + play_h / 2.0

	_create_border(Vector2(mid_x, border_top),               Vector2(play_w, 0.0))
	_create_border(Vector2(mid_x, _arena_h - border_bottom), Vector2(play_w, 0.0))
	_create_border(Vector2(BORDER_SIDE, mid_y),              Vector2(0.0, play_h))
	_create_border(Vector2(DESIGN_W - BORDER_SIDE, mid_y),   Vector2(0.0, play_h))

	bg.position     = Vector2.ZERO
	bg.size         = Vector2(DESIGN_W, _arena_h)
	bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE

	$Player.position = Vector2(mid_x, mid_y)

	_camera              = Camera2D.new()
	_camera.limit_left   = 0
	_camera.limit_right  = int(DESIGN_W)
	_camera.limit_top    = 0
	_camera.limit_bottom = int(_arena_h)
	$Player.add_child(_camera)

	_play_rect = Rect2(BORDER_SIDE, border_top, play_w, play_h)
	$HazardDirector.setup(_screen_h, _arena_h, _camera, _play_rect)
	$AbilityDirector.setup(_screen_h, _camera, _play_rect)
	AudioManager.play_music()


func _create_border(pos: Vector2, size: Vector2) -> void:
	var body  := StaticBody2D.new()
	body.position = pos
	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)




func _on_pause_pressed() -> void:
	if _is_dead:
		return
	AudioManager.play_select()
	if get_tree().paused:
		_pause_screen.resume()
	else:
		_pause_screen.show_pause()


func _on_ability_received(type: int) -> void:
	match type:
		AbilityBubble.Type.SCREEN_CLEAR:  _special_button.texture_normal = TEXTURE_BTN_CLEAR
		AbilityBubble.Type.INVINCIBILITY: _special_button.texture_normal = TEXTURE_BTN_GHOST
		AbilityBubble.Type.TIME_SLOW:     _special_button.texture_normal = TEXTURE_BTN_SLOW
	_special_button.modulate.a = 1.0


func _on_ability_used(type: int) -> void:
	_special_button.texture_normal = TEXTURE_BTN_EMPTY
	_special_button.modulate.a     = 0.35
	$AbilityDirector.on_ability_used()
	match type:
		AbilityBubble.Type.SCREEN_CLEAR:  _do_screen_clear()
		AbilityBubble.Type.TIME_SLOW:     _do_time_slow()
		AbilityBubble.Type.INVINCIBILITY: _do_invincibility()


func _do_screen_clear() -> void:
	shake(7.0, 0.3)
	# Streams clearable grubuna girmez — manüel durdur ve sonra devam ettir
	var paused_streams: Array = []
	for pool_list: Array in $HazardDirector.pools.values():
		for h: BaseHazard in pool_list:
			if h.active and not h.is_in_group("clearable"):
				paused_streams.append(h)
				h.deactivate()
	for node in get_tree().get_nodes_in_group("clearable"):
		if node.get("active") == true:
			if node.has_method("deactivate"):
				node.deactivate()
			elif node.has_method("retire"):
				node.retire()
	_show_cleared_fx()
	await get_tree().create_timer(1.87).timeout
	if _is_dead:
		return
	for h: BaseHazard in paused_streams:
		if is_instance_valid(h):
			h.activate({})


func _show_cleared_fx() -> void:
	var spr       := Sprite2D.new()
	spr.texture    = TEXTURE_CLEARED
	spr.scale      = Vector2(0.5, 0.5)
	spr.position   = get_viewport().get_visible_rect().get_center()
	spr.z_index    = 10
	spr.modulate.a = 0.0
	$MobileUI.add_child(spr)

	var tw := spr.create_tween()
	tw.tween_property(spr, "modulate:a", 1.0, 0.12)
	tw.tween_interval(1.5)
	tw.tween_property(spr, "modulate:a", 0.0, 0.25)
	tw.tween_callback(spr.queue_free)


func _do_time_slow() -> void:
	shake(5.0, 0.2)
	Engine.time_scale = TIME_SLOW_SCALE
	await get_tree().create_timer(TIME_SLOW_DURATION, true, false, true).timeout
	Engine.time_scale = 1.0


func _do_invincibility() -> void:
	var player := $Player
	player.is_invincible = true
	player.modulate.a    = 0.35

	await get_tree().create_timer(GHOST_DURATION - GHOST_BLINK_TIME, true, false, true).timeout

	var interval := GHOST_BLINK_TIME / (GHOST_BLINK_COUNT * 2)
	for i in GHOST_BLINK_COUNT * 2:
		if not is_instance_valid(player):
			return
		player.modulate.a = 1.0 if (i % 2 == 0) else 0.35
		await get_tree().create_timer(interval, true, false, true).timeout

	if is_instance_valid(player):
		player.is_invincible = false
		player.modulate.a    = 1.0


func _show_death_screen(t: float) -> void:
	var is_new_best := SaveData.save_if_best(t)
	_death_screen.show_result(t, is_new_best, SaveData.best_time)


func _on_player_dead() -> void:
	shake(14.0, 0.6)
	AudioManager.stop_music()
	_is_dead = true
	_pause_button.disabled = true
	_joystick.disabled     = true
	Engine.time_scale      = 1.0
	$HazardDirector.stop()
	$AbilityDirector.stop()
	if get_tree().paused:
		_pause_screen.resume()
	var anim: AnimatedSprite2D = $Player.get_node("AnimatedSprite2D")
	if anim and anim.is_playing():
		await anim.animation_finished
	await get_tree().create_timer(0.5).timeout
	if _continue_count < 3 and Leaderboard.has_internet:
		_show_continue_screen()
	else:
		_show_death_screen($HazardDirector.survival_time)


func _show_continue_screen() -> void:
	var scn: PackedScene = load("res://scenes/ui/ContinueScreen.tscn")
	if scn == null:
		_show_death_screen($HazardDirector.survival_time)
		return
	var screen: ContinueScreen = scn.instantiate()
	var survival: float = $HazardDirector.survival_time
	screen.ad_completed.connect(func() -> void:
		screen.queue_free()
		_continue_count += 1
		_revive_player()
	)
	screen.expired.connect(func() -> void:
		screen.queue_free()
		_show_death_screen(survival)
	)
	add_child(screen)


func _revive_player() -> void:
	_is_dead               = false
	_joystick.disabled     = false
	_pause_button.disabled = false
	for node in get_tree().get_nodes_in_group("clearable"):
		if node.get("active") == true:
			if node.has_method("deactivate"):
				node.deactivate()
			elif node.has_method("retire"):
				node.retire()
	$HazardDirector.restart_from($HazardDirector.survival_time)
	$AbilityDirector.start()
	AudioManager.play_music()
	await $Player.revive()
