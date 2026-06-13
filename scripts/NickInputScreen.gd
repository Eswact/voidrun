class_name NickInputScreen
extends CanvasLayer

signal rank_ready(rank: int)
signal cancelled

@export var _nick_input:   LineEdit   = null
@export var _confirm_btn:  BaseButton = null
@export var _status_label: Label      = null
@export var _close_btn:    BaseButton = null


func _ready() -> void:
	layer = 15  # renders above DeathScreen (layer 10)
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	if _status_label: _status_label.visible = false
	if _close_btn: _close_btn.pressed.connect(_on_close_pressed)
	Leaderboard.score_submitted.connect(_on_score_submitted)
	Leaderboard.rank_fetched.connect(_on_rank_fetched)
	Leaderboard.request_failed.connect(_on_request_failed)
	_nick_input.grab_focus()


func _on_confirm_pressed() -> void:
	var nick: String = _nick_input.text.strip_edges()
	if nick.is_empty():
		nick = "unknown"
	elif nick.length() < 2 or nick.length() > 12:
		_nick_input.placeholder_text = "2-12 characters!"
		_nick_input.text = ""
		return
	AudioManager.play_select()
	SaveData.save_nick(nick)
	_confirm_btn.disabled = true
	_nick_input.editable  = false
	_show_status("Submitting...")
	Leaderboard.submit_score(nick, SaveData.pending_submission)


func _on_score_submitted() -> void:
	Leaderboard.get_rank(SaveData.pending_submission)


func _on_rank_fetched(rank: int) -> void:
	rank_ready.emit(rank)
	queue_free()


func _on_close_pressed() -> void:
	AudioManager.play_select()
	cancelled.emit()
	queue_free()


func _on_request_failed(_error: String) -> void:
	_confirm_btn.disabled = false
	_nick_input.editable  = true
	_show_status("Connection failed. Try again.")


func _show_status(text: String) -> void:
	if _status_label:
		_status_label.text    = text
		_status_label.visible = true
