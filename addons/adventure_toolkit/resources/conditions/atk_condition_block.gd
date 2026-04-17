@tool
class_name ATKConditionBlock
extends ATKCondition


enum MatchMode {
	ALL,
	ANY,
	NONE,
}

@export var match_mode: MatchMode = MatchMode.ALL
@export var conditions: Array[ATKCondition] = []


func _evaluate_internal(context: Dictionary) -> Dictionary:
	var child_results: Array[Dictionary] = []
	var valid_conditions: Array[ATKCondition] = []

	for condition in conditions:
		if condition == null:
			continue
		valid_conditions.append(condition)

	if valid_conditions.is_empty():
		return fail(
			"Condition block '%s' has no child conditions." % get_debug_name(),
			{"match_mode": _match_mode_name(match_mode)}
		)

	for condition in valid_conditions:
		child_results.append(condition.evaluate(context))

	var passed := _resolve_result(child_results)
	if passed:
		return succeed(
			"Condition block '%s' passed." % get_debug_name(),
			{
				"match_mode": _match_mode_name(match_mode),
				"children": child_results,
			}
		)

	return fail(
		"Condition block '%s' failed in '%s' mode." % [get_debug_name(), _match_mode_name(match_mode)],
		{
			"match_mode": _match_mode_name(match_mode),
			"children": child_results,
		}
	)


func _resolve_result(child_results: Array[Dictionary]) -> bool:
	match match_mode:
		MatchMode.ALL:
			for result in child_results:
				if not bool(result.get(RESULT_KEY_PASSED, false)):
					return false
			return true
		MatchMode.ANY:
			for result in child_results:
				if bool(result.get(RESULT_KEY_PASSED, false)):
					return true
			return false
		MatchMode.NONE:
			for result in child_results:
				if bool(result.get(RESULT_KEY_PASSED, false)):
					return false
			return true
		_:
			return false


func _match_mode_name(value: MatchMode) -> String:
	match value:
		MatchMode.ALL:
			return "all"
		MatchMode.ANY:
			return "any"
		MatchMode.NONE:
			return "none"
		_:
			return "unknown"
