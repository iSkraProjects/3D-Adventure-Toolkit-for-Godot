@tool
class_name ATKActionStepPlayAnimation
extends ATKActionStep

## Placeholder: calls `AnimationPlayer.play(animation_name)` if resolved.


@export var animation_player_path: NodePath
@export var animation_name := ""


func run(context: ATKActionContext) -> void:
	if animation_name.is_empty():
		ATKLog.warn("Play-animation step '%s' has empty animation_name." % _debug_name(), "ATKAction")
		return
	var base: Node = context.actor
	if base == null:
		ATKLog.warn("Play-animation step '%s' needs actor for path resolution." % _debug_name(), "ATKAction")
		return
	var player := base.get_node_or_null(animation_player_path)
	if player is AnimationPlayer:
		(player as AnimationPlayer).play(animation_name)
		ATKLog.debug("Playing animation '%s'." % animation_name, "ATKAction")
	else:
		ATKLog.warn(
			"Play-animation step '%s' could not resolve AnimationPlayer at %s."
			% [_debug_name(), animation_player_path],
			"ATKAction"
		)
