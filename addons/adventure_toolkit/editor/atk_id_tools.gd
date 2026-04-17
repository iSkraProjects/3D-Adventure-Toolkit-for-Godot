@tool
class_name ATKIdTools
extends RefCounted

## Phase 19.1: stable ID helper utilities for editor tooling.

const _NON_ALNUM := "[^a-z0-9]+"


static func build_stable_id(raw_text: String, prefix: String = "") -> String:
	var value := raw_text.to_lower()
	var rx := RegEx.new()
	rx.compile(_NON_ALNUM)
	value = rx.sub(value, "_", true)
	value = value.strip_edges()
	value = value.trim_prefix("_")
	value = value.trim_suffix("_")
	if value.is_empty():
		value = "unnamed"
	var p := prefix.strip_edges().to_lower()
	if p.is_empty():
		return value
	if value.begins_with(p + "_"):
		return value
	return "%s_%s" % [p, value]
