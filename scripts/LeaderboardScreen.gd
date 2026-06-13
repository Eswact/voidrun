class_name LeaderboardScreen
extends CanvasLayer

@export var _close_btn:      BaseButton    = null
@export var _all_time_btn:   BaseButton    = null
@export var _weekly_btn:     BaseButton    = null
@export var _list_container: VBoxContainer = null
@export var _status_label:   Label         = null
@export var _own_row:        HBoxContainer = null

const _FONT      := preload("res://assets/fonts/Orbitron-VariableFont_wght.ttf")
const _COLOR_GOLD := Color(1.0, 0.85, 0.3)
const _COLOR_OWN  := Color(0.3, 0.9, 1.0)
const _COLOR_DIM  := Color(1.0, 1.0, 1.0, 0.85)

var _weekly:       bool  = false
var _own_rank_lbl: Label = null
var _own_nick_lbl: Label = null
var _own_time_lbl: Label = null


func _ready() -> void:
	layer = 12
	_close_btn.pressed.connect(_on_close)
	_all_time_btn.pressed.connect(func() -> void:
		AudioManager.play_select()
		_select_tab(false)
	)
	_weekly_btn.pressed.connect(func() -> void:
		AudioManager.play_select()
		_select_tab(true)
	)
	Leaderboard.scores_fetched.connect(_on_scores_fetched)
	Leaderboard.rank_fetched.connect(_on_own_rank_fetched)
	Leaderboard.request_failed.connect(_on_request_failed)
	if _status_label: _status_label.visible = false
	_setup_own_row()
	_select_tab(false)


func _setup_own_row() -> void:
	if _own_row == null:
		return
	_own_row.modulate.a = 0.0
	_own_row.add_theme_constant_override("separation", 12)
	_own_rank_lbl = _make_label("",  28, Color(0.6, 0.6, 0.6))
	_own_nick_lbl = _make_label("",  32, _COLOR_OWN)
	_own_time_lbl = _make_label("",  32, _COLOR_OWN)
	_own_rank_lbl.custom_minimum_size.x = 40
	_own_nick_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_own_time_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	_own_row.add_child(_own_rank_lbl)
	_own_row.add_child(_own_nick_lbl)
	_own_row.add_child(_own_time_lbl)


func _select_tab(weekly: bool) -> void:
	_weekly = weekly
	_all_time_btn.modulate.a = 0.45 if weekly else 1.0
	_weekly_btn.modulate.a   = 1.0  if weekly else 0.45
	_fetch()


func _fetch() -> void:
	_clear_list()
	if _own_row: _own_row.modulate.a = 0.0
	if Leaderboard._cache["weekly" if _weekly else "all_time"].is_empty():
		_show_status("Loading...")
	Leaderboard.get_top_scores(100, _weekly)


func _on_scores_fetched(scores: Array) -> void:
	_clear_list()
	if _status_label: _status_label.visible = false

	if scores.is_empty():
		_show_status("No scores yet!")
		return

	var own_rank: int = -1
	for i: int in scores.size():
		var entry: Dictionary  = scores[i]
		var nick: String       = str(entry.get("nick", "?"))
		var secs: float        = float(entry.get("time_seconds", 0.0))
		var dev_id: String     = str(entry.get("device_id", ""))
		var time_str: String   = "%d:%02d" % [int(secs) / 60, int(secs) % 60]
		var is_own: bool       = dev_id == SaveData.device_id
		if is_own:
			own_rank = i + 1
		var color: Color
		if is_own:
			color = _COLOR_OWN
		elif i == 0:
			color = _COLOR_GOLD
		else:
			color = _COLOR_DIM
		_list_container.add_child(_make_row(i + 1, nick, time_str, color))

	if SaveData.best_time > 0.0 and SaveData.has_nick():
		if own_rank > 0:
			_show_own_row(own_rank)
		else:
			_show_own_row(-1)
			Leaderboard.get_rank(SaveData.best_time)


func _show_own_row(rank: int) -> void:
	if _own_row == null:
		return
	var secs: float      = SaveData.best_time
	var time_str: String = "%d:%02d" % [int(secs) / 60, int(secs) % 60]
	_own_rank_lbl.text   = "#%d" % rank if rank > 0 else "..."
	_own_nick_lbl.text   = SaveData.user_nick
	_own_time_lbl.text   = time_str
	_own_row.modulate.a  = 1.0


func _on_own_rank_fetched(rank: int) -> void:
	if _own_row == null or _own_row.modulate.a < 0.5:
		return
	_own_rank_lbl.text = "#%d" % rank if rank > 0 else "?"


func _make_row(rank: int, nick: String, time_str: String, color: Color) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	var rank_lbl := _make_label("#%d" % rank, 36, Color(0.6, 0.6, 0.6))
	var nick_lbl := _make_label(nick,          42, color)
	var time_lbl := _make_label(time_str,      38, color)
	rank_lbl.custom_minimum_size.x = 40
	nick_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(rank_lbl)
	hbox.add_child(nick_lbl)
	hbox.add_child(time_lbl)
	return hbox


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _on_request_failed(error: String) -> void:
	_clear_list()
	if error == "no_internet":
		_show_status("No connection")
	else:
		_show_status("Failed to load.")


func _clear_list() -> void:
	for child in _list_container.get_children():
		child.queue_free()


func _show_status(text: String) -> void:
	if _status_label:
		_status_label.text    = text
		_status_label.visible = true


func _on_close() -> void:
	AudioManager.play_select()
	queue_free()
