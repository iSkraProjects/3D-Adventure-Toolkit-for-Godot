class_name ATKSerialize
extends RefCounted


static func duplicate_dictionary(value: Dictionary) -> Dictionary:
	return value.duplicate(true)


static func duplicate_array(value: Array) -> Array:
	return value.duplicate(true)


static func get_dictionary_value(source: Dictionary, key: Variant, default_value: Variant = null) -> Variant:
	if source.has(key):
		return source[key]

	return default_value


static func set_dictionary_value(source: Dictionary, key: Variant, value: Variant) -> Dictionary:
	var result := source.duplicate(true)
	result[key] = make_serializable(value)
	return result


static func vec3_to_dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


static func vec3_from_dict(value: Variant, default_value: Vector3 = Vector3.ZERO) -> Vector3:
	if value is Dictionary:
		var d: Dictionary = value
		return Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0)))
	return default_value


static func make_serializable(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return value
		TYPE_ARRAY:
			var serialized_array: Array = []
			for item in value:
				serialized_array.append(make_serializable(item))
			return serialized_array
		TYPE_DICTIONARY:
			var serialized_dictionary := {}
			for key in value.keys():
				serialized_dictionary[key] = make_serializable(value[key])
			return serialized_dictionary
		_:
			return str(value)
