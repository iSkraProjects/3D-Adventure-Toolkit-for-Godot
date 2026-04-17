@tool
class_name ATKActionStepPlaySound
extends ATKActionStep

## Placeholder: plays `stream` on a transient AudioStreamPlayer3D at the actor (T7.4).


@export var stream: AudioStream


func run(context: ATKActionContext) -> void:
	if stream == null:
		ATKLog.debug("Play-sound step '%s': no stream assigned (placeholder)." % _debug_name(), "ATKAction")
		return
	var parent: Node = context.actor
	if parent == null:
		var tree := Engine.get_main_loop() as SceneTree
		parent = tree.current_scene if tree != null else null
	if parent == null:
		ATKLog.warn("Play-sound step '%s' has no parent node." % _debug_name(), "ATKAction")
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = _resolve_sfx_volume_db()
	parent.add_child(player)
	player.play()
	ATKLog.debug("Play-sound step '%s' started." % _debug_name(), "ATKAction")
	player.finished.connect(player.queue_free)


func _resolve_sfx_volume_db() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 0.0
	var settings := tree.root.get_node_or_null("ATKSettings")
	if settings == null:
		return 0.0
	if not settings.has_method("get_master_volume") or not settings.has_method("get_sfx_volume"):
		return 0.0
	var master := float(settings.call("get_master_volume"))
	var sfx := float(settings.call("get_sfx_volume"))
	return linear_to_db(clampf(master * sfx, 0.0, 1.0))
