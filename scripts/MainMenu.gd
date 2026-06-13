extends Control

@export var _play_btn:        BaseButton = null
@export var _leaderboard_btn: BaseButton = null
@export var _settings_btn:    BaseButton = null


func _ready() -> void:
	AudioManager.play_menu_music()
	_play_btn.pressed.connect(func() -> void:
		AudioManager.play_select()
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	if _leaderboard_btn:
		_leaderboard_btn.pressed.connect(_on_leaderboard_pressed)
	if _settings_btn:
		_settings_btn.pressed.connect(_on_settings_pressed)
	Leaderboard.get_top_scores(100, false)
	Leaderboard.get_top_scores(100, true)


func _on_leaderboard_pressed() -> void:
	AudioManager.play_select()
	var scn: PackedScene = load("res://scenes/ui/LeaderboardScreen.tscn")
	if scn == null:
		push_warning("MainMenu: LeaderboardScreen.tscn not found")
		return
	var screen: LeaderboardScreen = scn.instantiate()
	add_child(screen)


func _on_settings_pressed() -> void:
	AudioManager.play_select()
	var scn: PackedScene = load("res://scenes/ui/SettingsScreen.tscn")
	if scn == null:
		push_warning("MainMenu: SettingsScreen.tscn not found")
		return
	var screen: SettingsScreen = scn.instantiate()
	add_child(screen)
