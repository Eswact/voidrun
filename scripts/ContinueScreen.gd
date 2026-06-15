class_name ContinueScreen
extends CanvasLayer

const _Secrets := preload("res://scripts/Secrets.gd")

signal ad_completed
signal expired

@export var _countdown_label: Label      = null
@export var _watch_ad_btn:    BaseButton = null
@export var _status_label:    Label      = null
@export var _close_btn:       BaseButton = null

const COUNTDOWN := 5.0

var _time_left:       float                    = COUNTDOWN
var _ad_watching:     bool                     = false
var _reward_earned:   bool                     = false
var _finished:        bool                     = false
var _rewarded_ad:     RewardedAd               = null
var _reward_listener: OnUserEarnedRewardListener = null


func _ready() -> void:
	layer = 12
	if _status_label: _status_label.visible = false
	_watch_ad_btn.pressed.connect(_on_watch_ad_pressed)
	if _close_btn: _close_btn.pressed.connect(func() -> void:
		AudioManager.play_select()
		set_process(false)
		_emit_expired()
	)
	_update_countdown_label()


func _process(delta: float) -> void:
	if _ad_watching:
		return
	_time_left -= delta
	_update_countdown_label()
	if _time_left <= 0.0:
		set_process(false)
		_emit_expired()


func _on_watch_ad_pressed() -> void:
	_ad_watching = true
	_watch_ad_btn.disabled = true
	if _close_btn: _close_btn.disabled = true
	AudioManager.play_select()
	if _status_label:
		_status_label.text    = "Loading ad..."
		_status_label.visible = true

	if OS.get_name() == "Android":
		_load_rewarded_ad()
	else:
		# Editörde / PC'de mock
		await get_tree().create_timer(1.5).timeout
		if _finished: return
		_finished = true
		ad_completed.emit()


func _load_rewarded_ad() -> void:
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded          = _on_ad_loaded
	callback.on_ad_failed_to_load  = _on_ad_failed_to_load
	var ad_unit_id: String = "ca-app-pub-3940256099942544/5224354917"
	RewardedAdLoader.new().load(ad_unit_id, AdRequest.new(), callback)


func _on_ad_loaded(ad: RewardedAd) -> void:
	_rewarded_ad = ad
	_reward_listener = OnUserEarnedRewardListener.new()
	_reward_listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		_reward_earned = true
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = _on_ad_dismissed
	ad.show(_reward_listener)


func _on_ad_dismissed() -> void:
	if _finished: return
	_finished = true
	if _reward_earned:
		ad_completed.emit()
	else:
		expired.emit()


func _on_ad_failed_to_load(_error: LoadAdError) -> void:
	_ad_watching = false
	_watch_ad_btn.disabled = false
	if _close_btn: _close_btn.disabled = false
	if _status_label:
		_status_label.text = "Ad unavailable. Try again."


func _emit_expired() -> void:
	if _finished: return
	_finished = true
	expired.emit()


func _update_countdown_label() -> void:
	if _countdown_label:
		_countdown_label.text = str(maxi(ceili(_time_left), 0))
