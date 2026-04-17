class_name ATKIdUtils
extends RefCounted


static func sanitize_id(value: String) -> String:
	var sanitized := value.strip_edges().to_lower()
	sanitized = sanitized.replace(" ", "_")

	var cleaned := ""
	for character in sanitized:
		var is_lower := character >= "a" and character <= "z"
		var is_digit := character >= "0" and character <= "9"
		if is_lower or is_digit or character == "_":
			cleaned += character

	while cleaned.find("__") != -1:
		cleaned = cleaned.replace("__", "_")

	return cleaned.strip_edges().trim_prefix("_").trim_suffix("_")


static func ensure_prefix(id_value: String, prefix: String) -> String:
	if id_value.is_empty():
		return prefix.trim_suffix("_")

	if id_value.begins_with(prefix):
		return id_value

	return "%s%s" % [prefix, id_value]


static func is_valid_stable_id(id_value: String) -> bool:
	if id_value.is_empty():
		return false

	if id_value != sanitize_id(id_value):
		return false

	return true
