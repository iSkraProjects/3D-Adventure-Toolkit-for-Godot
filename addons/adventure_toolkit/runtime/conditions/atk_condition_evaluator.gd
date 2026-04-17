class_name ATKConditionEvaluator
extends RefCounted

## Central entry for evaluating conditions with consistent debug output (T6.5).


static func evaluate(
	condition: ATKCondition,
	context: Dictionary = {},
	log_passes: bool = false
) -> Dictionary:
	if condition == null:
		var null_result := _fail_dict("Condition is null.")
		_log_top(null_result, "<null>", log_passes)
		return null_result

	var result: Dictionary = condition.evaluate(context)
	_log_top(result, condition.get_debug_name(), log_passes)
	_log_child_failures(result)
	return result


static func _log_top(result: Dictionary, label: String, log_passes: bool) -> void:
	var passed := bool(result.get(ATKCondition.RESULT_KEY_PASSED, false))
	var reason := str(result.get(ATKCondition.RESULT_KEY_REASON, ""))
	if passed:
		if log_passes:
			ATKLog.debug("Condition OK [%s]: %s" % [label, reason], "ATKCondition")
		return
	ATKLog.debug("Condition FAIL [%s]: %s" % [label, reason], "ATKCondition")


static func _log_child_failures(result: Dictionary) -> void:
	var meta_value: Variant = result.get(ATKCondition.RESULT_KEY_METADATA, {})
	if not (meta_value is Dictionary):
		return
	var meta: Dictionary = meta_value
	if not meta.has("children"):
		return
	var children: Variant = meta["children"]
	if not (children is Array):
		return
	var index := 0
	for child in children:
		if not (child is Dictionary):
			index += 1
			continue
		var cd: Dictionary = child
		if bool(cd.get(ATKCondition.RESULT_KEY_PASSED, true)):
			index += 1
			continue
		var child_reason := str(cd.get(ATKCondition.RESULT_KEY_REASON, ""))
		ATKLog.debug("  block child[%d]: %s" % [index, child_reason], "ATKCondition")
		index += 1


static func _fail_dict(reason: String) -> Dictionary:
	return {
		ATKCondition.RESULT_KEY_PASSED: false,
		ATKCondition.RESULT_KEY_REASON: reason,
		ATKCondition.RESULT_KEY_METADATA: {},
	}
