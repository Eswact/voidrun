class_name PauseScreen
extends CanvasLayer

const _TEX_SOUND_ON  := preload("res://assets/sprites/mobile_ui/sound-on.png")
const _TEX_SOUND_OFF := preload("res://assets/sprites/mobile_ui/sound-off.png")
const _TEX_MUSIC_ON  := preload("res://assets/sprites/mobile_ui/music-on.png")
const _TEX_MUSIC_OFF := preload("res://assets/sprites/mobile_ui/music-off.png")

@export var _continue_btn: Button        = null
@export var _sound_btn:    TextureButton = null
@export var _music_btn:    TextureButton = null
@export var _menu_btn:     BaseButton    = null


func _ready() -> void:
	visible = false

	_continue_btn.pressed.connect(func() -> void:
		AudioManager.play_select()
		resume()
	)
	_sound_btn.pressed.connect(func() -> void:
		AudioManager.play_select()
		AudioManager.toggle_sfx()
	)
	_music_btn.pressed.connect(func() -> void:
		AudioManager.play_select()
		AudioManager.toggle_music()
	)
	if _menu_btn:
		_menu_btn.pressed.connect(func() -> void:
			AudioManager.play_select()
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		)

	AudioManager.sfx_toggled.connect(_on_sfx_toggled)
	AudioManager.music_toggled.connect(_on_music_toggled)

	_refresh_buttons()


func show_pause() -> void:
	visible = true
	AudioManager.pause_music()
	get_tree().paused = true


func resume() -> void:
	visible = false
	AudioManager.resume_music()
	get_tree().paused = false


func _on_sfx_toggled(muted: bool) -> void:
	_sound_btn.texture_normal = _TEX_SOUND_OFF if muted else _TEX_SOUND_ON


func _on_music_toggled(muted: bool) -> void:
	_music_btn.texture_normal = _TEX_MUSIC_OFF if muted else _TEX_MUSIC_ON


func _refresh_buttons() -> void:
	_sound_btn.texture_normal = _TEX_SOUND_OFF if AudioManager.sfx_muted   else _TEX_SOUND_ON
	_music_btn.texture_normal = _TEX_MUSIC_OFF if AudioManager.music_muted else _TEX_MUSIC_ON
