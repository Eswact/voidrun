extends Node

const _TABLE := "leaderboard"

var _headers_read:   Array[String]
var _headers_upsert: Array[String]

signal score_submitted
signal scores_fetched(scores: Array)
signal rank_fetched(rank: int)
signal request_failed(error: String)

var _submit_req:        HTTPRequest
var _fetch_req:         HTTPRequest
var _fetch_weekly_req:  HTTPRequest
var _rank_req:          HTTPRequest

var _cache: Dictionary = { "all_time": [], "weekly": [] }
var _fetching_all_time: bool = false
var _fetching_weekly:   bool = false
var has_internet:       bool = true


func _ready() -> void:
	_headers_read = [
		"apikey: " + Secrets.SUPABASE_KEY,
		"Authorization: Bearer " + Secrets.SUPABASE_KEY
	]
	_headers_upsert = [
		"Content-Type: application/json",
		"apikey: " + Secrets.SUPABASE_KEY,
		"Authorization: Bearer " + Secrets.SUPABASE_KEY,
		"Prefer: resolution=merge-duplicates,return=minimal"
	]
	_submit_req = HTTPRequest.new()
	add_child(_submit_req)
	_submit_req.request_completed.connect(_on_submit_done)

	_fetch_req = HTTPRequest.new()
	add_child(_fetch_req)
	_fetch_req.request_completed.connect(_on_fetch_all_time_done)

	_fetch_weekly_req = HTTPRequest.new()
	add_child(_fetch_weekly_req)
	_fetch_weekly_req.request_completed.connect(_on_fetch_weekly_done)

	_rank_req = HTTPRequest.new()
	add_child(_rank_req)
	_rank_req.request_completed.connect(_on_rank_done)


func submit_score(nick: String, time_seconds: float) -> void:
	var url  := Secrets.SUPABASE_URL + "/rest/v1/" + _TABLE + "?on_conflict=device_id"
	var body := JSON.stringify({
		"device_id":    SaveData.device_id,
		"nick":         nick.strip_edges(),
		"time_seconds": time_seconds
	})
	_submit_req.request(url, _headers_upsert, HTTPClient.METHOD_POST, body)


func get_top_scores(limit: int = 100, weekly: bool = false) -> void:
	var key: String = "weekly" if weekly else "all_time"
	if not _cache[key].is_empty():
		scores_fetched.emit(_cache[key])
	var url := "%s/rest/v1/%s?select=nick,time_seconds,device_id&order=time_seconds.desc&limit=%d" \
		% [Secrets.SUPABASE_URL, _TABLE, limit]
	if weekly:
		if _fetching_weekly: return
		_fetching_weekly = true
		var since := Time.get_unix_time_from_system() - 7 * 24 * 3600
		url += "&created_at=gte." + Time.get_datetime_string_from_unix_time(int(since)) + "Z"
		_fetch_weekly_req.request(url, _headers_read)
	else:
		if _fetching_all_time: return
		_fetching_all_time = true
		_fetch_req.request(url, _headers_read)


func _on_submit_done(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		has_internet = false
		request_failed.emit("submit error: %d" % code)
		return
	has_internet = true
	if code not in [200, 201, 204]:
		request_failed.emit("submit error: %d" % code)
		return
	score_submitted.emit()


func get_rank(time_seconds: float) -> void:
	var url     := "%s/rest/v1/%s?select=id&time_seconds=gt.%s" \
		% [Secrets.SUPABASE_URL, _TABLE, str(time_seconds)]
	var headers := _headers_read + ["Prefer: count=exact"]
	_rank_req.request(url, headers)


func _on_rank_done(result: int, code: int, headers: PackedStringArray, _b: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		rank_fetched.emit(-1)
		return
	var count: int = 0
	for h: String in headers:
		if h.to_lower().begins_with("content-range:"):
			var slash: int = h.find("/")
			if slash != -1:
				count = h.substr(slash + 1).strip_edges().to_int()
			break
	rank_fetched.emit(count + 1)


func _on_fetch_all_time_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_fetching_all_time = false
	var scores: Array = _parse_scores(result, code, body)
	if scores.is_empty() and result != HTTPRequest.RESULT_SUCCESS:
		return
	_cache["all_time"] = scores
	scores_fetched.emit(scores)


func _on_fetch_weekly_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_fetching_weekly = false
	var scores: Array = _parse_scores(result, code, body)
	if scores.is_empty() and result != HTTPRequest.RESULT_SUCCESS:
		return
	_cache["weekly"] = scores
	scores_fetched.emit(scores)


func _parse_scores(result: int, code: int, body: PackedByteArray) -> Array:
	if result != HTTPRequest.RESULT_SUCCESS:
		has_internet = false
		request_failed.emit("no_internet")
		return []
	has_internet = true
	if code != 200:
		request_failed.emit("server_error")
		return []
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		request_failed.emit("parse_error")
		return []
	return json.data as Array
