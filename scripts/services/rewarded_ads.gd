extends Node
## Owns the single-use rewarded ad and credits only the SDK's earned callback.

signal changed
signal reward_saved

const Progress = preload("res://scripts/services/player_progress.gd")
const Rewards = preload("res://scripts/services/rewards.gd")
const Provider = preload("res://scripts/services/poing_ads.gd")
enum State { HIDDEN, IDLE, LOADING, READY, SHOWING, PRIVACY }

var state := State.HIDDEN
var message := ""
var privacy_required := false
var _progress: Progress
var _provider: RefCounted
var _ad: RefCounted
var _attempt := 0
var _earned := false
var _loaded_at := 0


func setup(progress: Progress, provider: RefCounted = null) -> void:
	_progress = progress
	_provider = provider if provider != null else Provider.new()
	if _provider.available():
		_set_state(State.IDLE)


func press() -> void:
	if state == State.READY and Time.get_ticks_msec() - _loaded_at < 3_300_000:
		_earned = false
		_set_state(State.SHOWING)
		_provider.show_ad(_ad, _on_earned.bind(_attempt), _on_closed.bind(_attempt),
			_on_show_failed.bind(_attempt))
	elif state == State.IDLE or state == State.READY:
		_discard_ad()
		_attempt += 1
		_set_state(State.LOADING)
		_provider.load_ad(_on_loaded.bind(_attempt), _on_load_failed.bind(_attempt), _update_privacy)


func open_privacy() -> void:
	if not privacy_required or state not in [State.IDLE, State.READY]:
		return
	_discard_ad()
	_set_state(State.PRIVACY)
	_provider.open_privacy(_on_privacy_closed)


func _on_loaded(ad: RefCounted, attempt: int) -> void:
	if attempt != _attempt or state != State.LOADING:
		_provider.discard_ad(ad)
		return
	_ad = ad
	_loaded_at = Time.get_ticks_msec()
	_set_state(State.READY)


func _on_load_failed(attempt: int) -> void:
	if attempt == _attempt and state == State.LOADING:
		_set_state(State.IDLE, "No ad is available right now. Try again later.")


func _on_earned(attempt: int) -> void:
	if attempt != _attempt or state != State.SHOWING or _earned:
		return
	_earned = true
	if _progress.record_video_reward():
		message = "+%d coins added." % Rewards.VIDEO_REWARD
		reward_saved.emit()
	else:
		message = "Your ad reward could not be saved."
	changed.emit()


func _on_closed(attempt: int) -> void:
	if attempt != _attempt or state != State.SHOWING:
		return
	_discard_ad()
	_set_state(State.IDLE, message if _earned else "Ad closed before the reward was earned.")


func _on_show_failed(attempt: int) -> void:
	if attempt != _attempt or state != State.SHOWING:
		return
	_discard_ad()
	_set_state(State.IDLE, message if _earned else "The ad could not open. Try again later.")


func _update_privacy(required: bool) -> void:
	privacy_required = required
	changed.emit()


func _on_privacy_closed(failed: bool) -> void:
	_set_state(State.IDLE, "Privacy options could not open. Try again later." if failed else "")


func _set_state(next: State, status: String = "") -> void:
	state = next
	message = status
	changed.emit()


func _discard_ad() -> void:
	if _ad != null:
		_provider.discard_ad(_ad)
		_ad = null


func _exit_tree() -> void:
	_discard_ad()
