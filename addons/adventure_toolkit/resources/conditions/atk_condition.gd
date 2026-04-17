@tool
class_name ATKCondition
extends Resource


const RESULT_KEY_PASSED := "passed"
const RESULT_KEY_REASON := "reason"
const RESULT_KEY_METADATA := "metadata"

@export var condition_id := ""
@export_multiline var debug_label := ""


func evaluate(context: Dictionary = {}) -> Dictionary:
	var result := _evaluate_internal(context)
	return _normalize_result(result)


func _evaluate_internal(_context: Dictionary) -> Dictionary:
	return fail("Condition '%s' has no evaluator implementation." % get_debug_name())


func succeed(reason: String = "", metadata: Dictionary = {}) -> Dictionary:
	return {
		RESULT_KEY_PASSED: true,
		RESULT_KEY_REASON: reason,
		RESULT_KEY_METADATA: metadata.duplicate(true),
	}


func fail(reason: String = "", metadata: Dictionary = {}) -> Dictionary:
	return {
		RESULT_KEY_PASSED: false,
		RESULT_KEY_REASON: reason,
		RESULT_KEY_METADATA: metadata.duplicate(true),
	}


func get_debug_name() -> String:
	if not condition_id.is_empty():
		return condition_id
	if not debug_label.is_empty():
		return debug_label
	return resource_name if not resource_name.is_empty() else "unnamed_condition"


func _normalize_result(result: Variant) -> Dictionary:
	if result is Dictionary:
		return {
			RESULT_KEY_PASSED: bool(result.get(RESULT_KEY_PASSED, false)),
			RESULT_KEY_REASON: str(result.get(RESULT_KEY_REASON, "")),
			RESULT_KEY_METADATA: _safe_metadata(result.get(RESULT_KEY_METADATA, {})),
		}

	return fail("Condition '%s' returned an invalid result payload." % get_debug_name())


func _safe_metadata(metadata_value: Variant) -> Dictionary:
	if metadata_value is Dictionary:
		return (metadata_value as Dictionary).duplicate(true)
	return {}
