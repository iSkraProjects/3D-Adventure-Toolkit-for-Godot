extends Node

## Phase 17.2: scene ambience/music hooks.
## Listens for scene transitions and applies scene-authored ambient/music streams.

signal scene_audio_applied(scene_id: String, has_music: bool, has_ambience: bool)

var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _dialogue_voice_player: AudioStreamPlayer
var _master_linear := 1.0
var _music_linear := 1.0
var _sfx_linear := 1.0
var _ambience_linear := 1.0
var _voice_linear := 1.0


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Master"
	_music_player.autoplay = false
	add_child(_music_player)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	_ambience_player.bus = "Master"
	_ambience_player.autoplay = false
	add_child(_ambience_player)

	_dialogue_voice_player = AudioStreamPlayer.new()
	_dialogue_voice_player.name = "DialogueVoicePlayer"
	_dialogue_voice_player.bus = "Master"
	_dialogue_voice_player.autoplay = false
	add_child(_dialogue_voice_player)

	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes != null:
		if scenes.has_signal("scene_transition_finished"):
			if not scenes.is_connected("scene_transition_finished", _on_scene_transition_finished):
				scenes.connect("scene_transition_finished", _on_scene_transition_finished)
			ATKLog.info("Connected to ATKScenes.scene_transition_finished.", "ATKAudio")
		else:
			ATKLog.warn("ATKScenes does not expose scene_transition_finished.", "ATKAudio")
	else:
		ATKLog.warn("ATKScenes not found; audio hooks inactive.", "ATKAudio")

	var settings := get_node_or_null("/root/ATKSettings")
	if settings != null and settings.has_signal("audio_settings_changed"):
		if not settings.is_connected("audio_settings_changed", _on_audio_settings_changed):
			settings.connect("audio_settings_changed", _on_audio_settings_changed)
		_on_audio_settings_changed(
			float(settings.get_master_volume()),
			float(settings.get_music_volume()),
			float(settings.get_sfx_volume()),
			float(settings.get_ambience_volume()),
			float(settings.get_voice_volume())
		)

	_apply_current_scene_audio()
	ATKLog.info("ATKAudio ready.", "ATKAudio")


func _on_scene_transition_finished(scene_id: String, _scene_path: String, _spawn_id: String) -> void:
	call_deferred("_apply_scene_audio_after_transition", scene_id)


func _apply_current_scene_audio() -> void:
	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes == null:
		return
	ATKLog.debug("Applying current scene audio for '%s'." % str(scenes.current_scene_id), "ATKAudio")
	call_deferred("_apply_scene_audio_after_transition", str(scenes.current_scene_id))


func _apply_scene_audio(scene_id: String) -> void:
	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes == null:
		return
	var scene_root: Node = scenes.get_current_scene_root()
	if scene_root == null:
		return
	if not scene_root.has_method("get_music_stream"):
		ATKLog.warn("Current scene root has no get_music_stream().", "ATKAudio")
		return
	if not scene_root.has_method("get_ambience_stream"):
		ATKLog.warn("Current scene root has no get_ambience_stream().", "ATKAudio")
		return

	var next_music := scene_root.call("get_music_stream") as AudioStream
	var next_ambience := scene_root.call("get_ambience_stream") as AudioStream

	_set_looped_stream(_music_player, next_music)
	_set_looped_stream(_ambience_player, next_ambience)

	ATKLog.info(
		"Applied scene audio for '%s' (music=%s ambience=%s)." % [
			scene_id,
			"yes" if next_music != null else "no",
			"yes" if next_ambience != null else "no",
		],
		"ATKAudio"
	)
	emit_signal("scene_audio_applied", scene_id, next_music != null, next_ambience != null)


func _apply_scene_audio_after_transition(scene_id: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var requested_scene_id := scene_id.strip_edges()
	if requested_scene_id.is_empty():
		# Startup may run before ATKScenes has a resolved scene id; skip quietly.
		return
	# Scene roots can appear a frame or two after transition finished; retry briefly.
	for _i in range(6):
		var scenes := get_node_or_null("/root/ATKScenes")
		if scenes != null and scenes.get_current_scene_root() != null:
			_apply_scene_audio(requested_scene_id)
			return
		await tree.process_frame
	# Some scenes (e.g. menu overlays) are intentionally not ATKSceneRoot-driven.
	# Avoid noisy warnings in that case.
	ATKLog.debug("No ATKSceneRoot after transition for '%s'; scene may not use scene-root audio hooks." % requested_scene_id, "ATKAudio")


func _set_looped_stream(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if player == null:
		return
	if stream == null:
		player.stop()
		player.stream = null
		return

	var changed_stream := player.stream != stream
	player.stream = stream
	if changed_stream or not player.playing:
		player.play()


func play_dialogue_voice(stream: AudioStream) -> void:
	if _dialogue_voice_player == null:
		return
	if stream == null:
		stop_dialogue_voice()
		return
	_dialogue_voice_player.stop()
	_dialogue_voice_player.stream = stream
	_dialogue_voice_player.volume_db = linear_to_db(clampf(_master_linear * _voice_linear, 0.0, 1.0))
	_dialogue_voice_player.play()
	ATKLog.debug("Dialogue voice started.", "ATKAudio")


func stop_dialogue_voice() -> void:
	if _dialogue_voice_player == null:
		return
	if _dialogue_voice_player.playing:
		_dialogue_voice_player.stop()
	_dialogue_voice_player.stream = null


func _on_audio_settings_changed(master: float, music: float, sfx: float, ambience: float, voice: float) -> void:
	_master_linear = clampf(master, 0.0, 1.0)
	_music_linear = clampf(music, 0.0, 1.0)
	_sfx_linear = clampf(sfx, 0.0, 1.0)
	_ambience_linear = clampf(ambience, 0.0, 1.0)
	_voice_linear = clampf(voice, 0.0, 1.0)
	_apply_player_levels()


func _apply_player_levels() -> void:
	if _music_player != null:
		_music_player.volume_db = linear_to_db(clampf(_master_linear * _music_linear, 0.0, 1.0))
	if _ambience_player != null:
		_ambience_player.volume_db = linear_to_db(clampf(_master_linear * _ambience_linear, 0.0, 1.0))
	if _dialogue_voice_player != null:
		_dialogue_voice_player.volume_db = linear_to_db(clampf(_master_linear * _voice_linear, 0.0, 1.0))
