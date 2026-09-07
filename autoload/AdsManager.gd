extends Node

signal rewarded_ready_changed(is_ready: bool)

# Official Google Android demo ad units. Replace all four IDs before publishing.
const TEST_BANNER_ID := "ca-app-pub-3940256099942544/9214589741"
const TEST_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"

var _banner: AdView
var _interstitial: InterstitialAd
var _rewarded: RewardedAd
var _rewarded_hint_earned := false
var _rewarded_completion: Callable
var _interstitial_after_close: Callable


func _ready() -> void:
	if OS.get_name() != "Android" or AppSettings.ads_removed:
		return
	_request_consent()


func _request_consent() -> void:
	var parameters := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(
		parameters, _on_consent_update_success, _on_consent_update_failure
	)


func _on_consent_update_success() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		_load_consent_form()
	else:
		_initialize_ads()


func _on_consent_update_failure(error: FormError) -> void:
	push_warning("AdMob consent update failed: %s" % error.message)
	_initialize_ads()


func _load_consent_form() -> void:
	UserMessagingPlatform.load_consent_form(
		_on_consent_form_loaded, _on_consent_form_load_failure
	)


func _on_consent_form_loaded(form: ConsentForm) -> void:
	var status := UserMessagingPlatform.consent_information.get_consent_status()
	if status == ConsentInformation.ConsentStatus.REQUIRED:
		form.show(_on_consent_form_dismissed)
	else:
		_initialize_ads()


func _on_consent_form_load_failure(error: FormError) -> void:
	push_warning("AdMob consent form failed to load: %s" % error.message)
	_initialize_ads()


func _on_consent_form_dismissed(_error: FormError) -> void:
	_initialize_ads()


func _initialize_ads() -> void:
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		_load_banner()
		_load_interstitial()
		_load_rewarded()
	MobileAds.set_request_configuration(RequestConfiguration.new())
	MobileAds.initialize(listener)


func _load_banner() -> void:
	if AppSettings.ads_removed:
		return
	if _banner != null:
		_banner.destroy()
	var size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	_banner = AdView.new(TEST_BANNER_ID, size, AdPosition.BOTTOM)
	var listener := AdListener.new()
	listener.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		push_warning("Banner failed to load: %s" % error.message)
	_banner.ad_listener = listener
	_banner.load_ad(AdRequest.new())


func _load_interstitial() -> void:
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial = ad
		var content := FullScreenContentCallback.new()
		content.on_ad_dismissed_full_screen_content = _finish_interstitial
		content.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
			push_warning("Interstitial failed to show: %s" % error.message)
			_finish_interstitial()
		_interstitial.full_screen_content_callback = content
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		push_warning("Interstitial failed to load: %s" % error.message)
	InterstitialAdLoader.new().load(TEST_INTERSTITIAL_ID, AdRequest.new(), callback)


func show_interstitial(after_close: Callable = Callable()) -> void:
	if OS.get_name() != "Android":
		if after_close.is_valid():
			after_close.call()
		return
	if AppSettings.ads_removed:
		if after_close.is_valid():
			after_close.call()
		return
	if _interstitial == null:
		if after_close.is_valid():
			after_close.call()
		_load_interstitial()
		return
	_interstitial_after_close = after_close
	_interstitial.show()


func _finish_interstitial() -> void:
	if _interstitial != null:
		_interstitial.destroy()
		_interstitial = null
	var callback := _interstitial_after_close
	_interstitial_after_close = Callable()
	_load_interstitial()
	if callback.is_valid():
		callback.call()


func _load_rewarded() -> void:
	rewarded_ready_changed.emit(false)
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded = ad
		var content := FullScreenContentCallback.new()
		content.on_ad_dismissed_full_screen_content = _on_rewarded_dismissed
		content.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
			push_warning("Rewarded ad failed to show: %s" % error.message)
			_rewarded_hint_earned = false
			_finish_rewarded()
		_rewarded.full_screen_content_callback = content
		rewarded_ready_changed.emit(true)
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		push_warning("Rewarded ad failed to load: %s" % error.message)
	RewardedAdLoader.new().load(TEST_REWARDED_ID, AdRequest.new(), callback)


func show_rewarded_hint() -> void:
	_show_rewarded(func() -> void: SignalHub.rewarded_hint_earned.emit.call_deferred())


func show_rewarded_retry(after_reward: Callable) -> void:
	_show_rewarded(after_reward)


func _show_rewarded(after_reward: Callable) -> void:
	if OS.get_name() != "Android":
		if after_reward.is_valid():
			after_reward.call()
		return
	if _rewarded == null:
		if after_reward.is_valid():
			after_reward.call()
		return
	rewarded_ready_changed.emit(false)
	_rewarded_hint_earned = false
	_rewarded_completion = after_reward
	var reward_listener := OnUserEarnedRewardListener.new()
	reward_listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		# Google can award the reward before its full-screen view has closed.
		# Defer revealing the item until the dismissed callback restores the game.
		_rewarded_hint_earned = true
	_rewarded.show(reward_listener)


func set_ads_removed(removed: bool) -> void:
	if not removed:
		return
	if _banner != null:
		_banner.destroy()
		_banner = null
	if _interstitial != null:
		_interstitial.destroy()
		_interstitial = null
	# Rewarded Hint ads remain available after the remove_ads purchase.


func is_rewarded_ready() -> bool:
	return _rewarded != null


func _on_rewarded_dismissed() -> void:
	var should_reveal_hint := _rewarded_hint_earned
	var completion := _rewarded_completion
	_rewarded_hint_earned = false
	_rewarded_completion = Callable()
	_finish_rewarded()
	if should_reveal_hint and completion.is_valid():
		completion.call_deferred()


func _finish_rewarded() -> void:
	if _rewarded != null:
		_rewarded.destroy()
		_rewarded = null
	_load_rewarded()


func _exit_tree() -> void:
	if _banner != null:
		_banner.destroy()
	if _interstitial != null:
		_interstitial.destroy()
	if _rewarded != null:
		_rewarded.destroy()
