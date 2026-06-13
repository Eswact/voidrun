class_name SettingsScreen
extends CanvasLayer

const _TEX_SOUND_ON  := preload("res://assets/sprites/mobile_ui/sound-on.png")
const _TEX_SOUND_OFF := preload("res://assets/sprites/mobile_ui/sound-off.png")
const _TEX_MUSIC_ON  := preload("res://assets/sprites/mobile_ui/music-on.png")
const _TEX_MUSIC_OFF := preload("res://assets/sprites/mobile_ui/music-off.png")

@export var _close_btn: BaseButton    = null
@export var _sound_btn: TextureButton = null
@export var _music_btn: TextureButton = null
@export var _reset_btn: BaseButton    = null
@export var _confirm_panel: Control   = null
@export var _confirm_yes:   BaseButton = null
@export var _confirm_no:    BaseButton = null


func _ready() -> void:
	layer = 12
	_close_btn.pressed.connect(_on_close)
	_sound_btn.pressed.connect(func() -> void:
		AudioManager.play_select()
		AudioManager.toggle_sfx()
	)
	_music_btn.pressed.connect(func() -> void:
		AudioManager.play_select()
		AudioManager.toggle_music()
	)
	_reset_btn.pressed.connect(_on_reset_pressed)

	if _confirm_panel:
		_confirm_panel.visible = false
	if _confirm_yes:
		_confirm_yes.pressed.connect(_on_confirm_yes)
	if _confirm_no:
		_confirm_no.pressed.connect(_on_confirm_no)

	AudioManager.sfx_toggled.connect(_on_sfx_toggled)
	AudioManager.music_toggled.connect(_on_music_toggled)
	_refresh_buttons()


func _on_reset_pressed() -> void:
	AudioManager.play_select()
	if _confirm_panel:
		_confirm_panel.visible = true
	else:
		_do_reset()


func _on_confirm_yes() -> void:
	AudioManager.play_select()
	if _confirm_panel: _confirm_panel.visible = false
	_do_reset()


func _on_confirm_no() -> void:
	AudioManager.play_select()
	if _confirm_panel: _confirm_panel.visible = false


func _do_reset() -> void:
	SaveData.reset()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _on_sfx_toggled(muted: bool) -> void:
	_sound_btn.texture_normal = _TEX_SOUND_OFF if muted else _TEX_SOUND_ON


func _on_music_toggled(muted: bool) -> void:
	_music_btn.texture_normal = _TEX_MUSIC_OFF if muted else _TEX_MUSIC_ON


func _refresh_buttons() -> void:
	_sound_btn.texture_normal = _TEX_SOUND_OFF if AudioManager.sfx_muted   else _TEX_SOUND_ON
	_music_btn.texture_normal = _TEX_MUSIC_OFF if AudioManager.music_muted else _TEX_MUSIC_ON


func _on_close() -> void:
	AudioManager.play_select()
	queue_free()
