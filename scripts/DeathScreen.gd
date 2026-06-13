class_name DeathScreen
extends CanvasLayer


@export var _time_label:  Label         = null
@export var _best_label:  Label         = null
@export var _restart_btn: TextureButton = null
@export var _submit_btn:  TextureButton = null
@export var _menu_btn:    BaseButton    = null
@export var _rank_label:  Label         = null

var _pending_time:       float = 0.0
var _nick_screen_active: bool  = false


func _ready() -> void:
	visible = false
	_restart_btn.pressed.connect(func() -> void:
		AudioManager.play_select()
		get_tree().reload_current_scene()
	)
	if _submit_btn:
		_submit_btn.pressed.connect(_on_submit_pressed)
		_submit_btn.visible = false
	if _menu_btn:
		_menu_btn.pressed.connect(func() -> void:
			AudioManager.play_select()
			get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		)

	if _rank_label: _rank_label.visible = false

	Leaderboard.score_submitted.connect(_on_score_submitted)
	Leaderboard.rank_fetched.connect(_on_rank_fetched)
	Leaderboard.request_failed.connect(_on_request_failed)


func show_result(time: float, is_new_best: bool, best_time: float) -> void:
	_pending_time = time
	var fmt := func(s: float) -> String: return "%d:%02d" % [int(s) / 60, int(s) % 60]
	_time_label.text     = fmt.call(time)
	_rank_label.visible  = false
	if _submit_btn: _submit_btn.visible = false

	if is_new_best:
		_best_label.text = "NEW RECORD!"
		if SaveData.has_nick():
			_set_status("Submitting...")
			Leaderboard.submit_score(SaveData.user_nick, time)
		else:
			if _submit_btn and Leaderboard.has_internet: _submit_btn.visible = true
	else:
		_best_label.text = fmt.call(best_time)

	visible = true


func _on_submit_pressed() -> void:
	AudioManager.play_select()
	SaveData.pending_submission = _pending_time
	if _submit_btn: _submit_btn.visible = false
	var scn: PackedScene = load("res://scenes/ui/NickInputScreen.tscn")
	if scn == null:
		push_warning("DeathScreen: NickInputScreen.tscn not found")
		return
	_nick_screen_active = true
	visible = false
	var nick_screen: NickInputScreen = scn.instantiate()
	nick_screen.rank_ready.connect(_on_nick_rank_ready)
	nick_screen.cancelled.connect(_on_nick_cancelled)
	add_child(nick_screen)


func _on_nick_rank_ready(rank: int) -> void:
	_nick_screen_active = false
	visible = true
	_show_rank(rank)


func _on_nick_cancelled() -> void:
	_nick_screen_active = false
	visible = true
	if _submit_btn and Leaderboard.has_internet: _submit_btn.visible = true


func _on_score_submitted() -> void:
	if _nick_screen_active: return
	Leaderboard.get_rank(_pending_time)


func _on_rank_fetched(rank: int) -> void:
	if _nick_screen_active: return
	_show_rank(rank)


func _on_request_failed(_error: String) -> void:
	if _nick_screen_active: return
	_set_status("Submit failed")


func _set_status(text: String) -> void:
	_rank_label.text                  = text
	_rank_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))
	_rank_label.visible               = true


func _show_rank(rank: int) -> void:
	_rank_label.text = "#%d IN THE WORLD" % rank if rank > 0 else "Submitted!"
	_rank_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	_rank_label.visible = true


