extends RefCounted
## Poing AdMob 5.1 adapter. Resolve SDK scripts at runtime so offline builds need no addon.

const SDK := "res://addons/admob/gdscript/src/"
const TEST_UNIT := "ca-app-pub-3940256099942544/5224354917"

var _ump: GDScript
var _consent: RefCounted
var _consent_updated := false
var _initialized := false


func available() -> bool:
	# Release builds stay disabled until production IDs and privacy messaging are configured.
	return OS.has_feature("android") and OS.is_debug_build() and \
		Engine.has_singleton("PoingGodotAdMob") and \
		Engine.has_singleton("PoingGodotAdMobRewardedAd") and \
		Engine.has_singleton("PoingGodotAdMobUserMessagingPlatform") and \
		Engine.has_singleton("PoingGodotAdMobConsentInformation") and \
		ResourceLoader.exists(SDK + "ump/api/UserMessagingPlatform.gd")


func load_ad(loaded: Callable, failed: Callable, privacy_changed: Callable) -> void:
	_ump = load(SDK + "ump/api/UserMessagingPlatform.gd")
	_consent = _ump.consent_information
	if _consent_updated:
		_after_consent_update(loaded, failed, privacy_changed)
		return
	var parameters: RefCounted = load(SDK + "ump/core/ConsentRequestParameters.gd").new()
	_consent.update(parameters, func() -> void:
		_consent_updated = true
		_after_consent_update(loaded, failed, privacy_changed)
	, func(_error: Variant) -> void: failed.call())


func _after_consent_update(loaded: Callable, failed: Callable, privacy_changed: Callable) -> void:
	var statuses: Dictionary = _consent.get_script().get_script_constant_map()
	privacy_changed.call(_consent.get_privacy_options_requirement_status() ==
		statuses.PrivacyOptionsRequirementStatus.REQUIRED)
	if _consent.get_consent_status() == statuses.ConsentStatus.REQUIRED:
		_ump.load_consent_form(func(form: RefCounted) -> void:
			form.show(func(error: Variant) -> void:
				if error == null:
					_load_with_consent(loaded, failed)
				else:
					failed.call()
			)
		, func(_error: Variant) -> void: failed.call())
	else:
		_load_with_consent(loaded, failed)


func _load_with_consent(loaded: Callable, failed: Callable) -> void:
	# This plugin exposes UMP status rather than canRequestAds(). Require a successful
	# update in this session and accept only the two UMP states that allow requests.
	var statuses: Dictionary = _consent.get_script().get_script_constant_map().ConsentStatus
	if _consent.get_consent_status() not in [statuses.NOT_REQUIRED, statuses.OBTAINED]:
		failed.call()
		return
	if _initialized:
		_request_ad(loaded, failed)
		return
	var listener: RefCounted = load(SDK + "api/listeners/OnInitializationCompleteListener.gd").new()
	listener.on_initialization_complete = func(_status: Variant) -> void:
		_initialized = true
		_request_ad(loaded, failed)
	var mobile_ads: GDScript = load(SDK + "api/MobileAds.gd")
	mobile_ads.initialize(listener)


func _request_ad(loaded: Callable, failed: Callable) -> void:
	var callbacks: RefCounted = load(SDK + "api/listeners/RewardedAdLoadCallback.gd").new()
	callbacks.on_ad_loaded = loaded
	callbacks.on_ad_failed_to_load = func(_error: Variant) -> void: failed.call()
	var request: RefCounted = load(SDK + "api/core/AdRequest.gd").new()
	load(SDK + "api/RewardedAdLoader.gd").new().load(TEST_UNIT, request, callbacks)


func show_ad(ad: RefCounted, earned: Callable, closed: Callable, failed: Callable) -> void:
	var fullscreen: RefCounted = load(SDK + "api/listeners/FullScreenContentCallback.gd").new()
	fullscreen.on_ad_dismissed_full_screen_content = closed
	fullscreen.on_ad_failed_to_show_full_screen_content = func(_error: Variant) -> void: failed.call()
	ad.full_screen_content_callback = fullscreen
	var reward: RefCounted = load(SDK + "api/listeners/OnUserEarnedRewardListener.gd").new()
	reward.on_user_earned_reward = func(_item: Variant) -> void: earned.call()
	ad.show(reward)


func open_privacy(closed: Callable) -> void:
	_ump.show_privacy_options_form(func(error: Variant) -> void: closed.call(error != null))


func discard_ad(ad: RefCounted) -> void:
	ad.destroy()
