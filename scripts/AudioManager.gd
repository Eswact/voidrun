extends Node

const _SFX_DASH    := preload("res://assets/audio/sound_effects/dash.wav")
const _SFX_DEAD    := preload("res://assets/audio/sound_effects/dead.wav")
const _SFX_PICKUP  := preload("res://assets/audio/sound_effects/pickup-ability.wav")
const _SFX_ABILITY := preload("res://assets/audio/sound_effects/ability-use.wav")
const _SFX_SELECT  := preload("res://assets/audio/sound_effects/select.wav")
const _MUSIC       := preload("res://assets/audio/music/voidrun-loop.mp3")
const _MENU_MUSIC  := preload("res://assets/audio/music/menu.mp3")

const _MUSIC_VOL_DB := -6.0

var sfx_muted:    bool = false
var music_muted:  bool = false
var _music_active: bool = false

signal sfx_toggled(muted: bool)
signal music_toggled(muted: bool)

var _dash:    AudioStreamPlayer
var _dead:    AudioStreamPlayer
var _pickup:  AudioStreamPlayer
var _ability: AudioStreamPlayer
var _select:  AudioStreamPlayer
var _music:   AudioStreamPlayer


func _ready() -> void:
	_dash    = _make(_SFX_DASH)
	_dead    = _make(_SFX_DEAD)
	_pickup  = _make(_SFX_PICKUP)
	_ability = _make(_SFX_ABILITY)
	_select  = _make(_SFX_SELECT)

	_music              = AudioStreamPlayer.new()
	_music.stream       = _MUSIC
	_music.volume_db    = _MUSIC_VOL_DB
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music)


func play_dash()    -> void: if not sfx_muted: _dash.play()
func play_dead()    -> void: if not sfx_muted: _dead.play()
func play_pickup()  -> void: if not sfx_muted: _pickup.play()
func play_ability() -> void: if not sfx_muted: _ability.play()
func play_select()  -> void: if not sfx_muted: _select.play()

func play_menu_music() -> void:
	_music_active  = true
	_music.stream  = _MENU_MUSIC
	if not music_muted: _music.play()

func play_music() -> void:
	_music_active  = true
	_music.stream  = _MUSIC
	if not music_muted: _music.play()

func stop_music() -> void:
	_music_active = false
	_music.stop()

func pause_music()  -> void: _music.stream_paused = true
func resume_music() -> void:
	if not music_muted: _music.stream_paused = false


func toggle_sfx() -> void:
	sfx_muted = not sfx_muted
	sfx_toggled.emit(sfx_muted)


func toggle_music() -> void:
	music_muted = not music_muted
	if music_muted:
		_music.stop()
	elif _music_active:
		_music.play()
	music_toggled.emit(music_muted)


func _make(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream       = stream
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p
