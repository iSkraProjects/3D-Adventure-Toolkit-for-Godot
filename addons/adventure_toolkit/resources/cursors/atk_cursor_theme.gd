@tool
class_name ATKCursorTheme
extends Resource

## Designer-facing cursor theme asset.
## Assign this in ATKInteractionHover to override all cursor icons globally.

@export var cursor_normal: Texture2D
@export var cursor_interact: Texture2D
@export var cursor_inspect: Texture2D
@export var cursor_open: Texture2D
@export var cursor_attack: Texture2D
@export var cursor_climb: Texture2D
@export var cursor_descend: Texture2D

@export var hotspot_normal := Vector2.ZERO
@export var hotspot_interact := Vector2.ZERO
@export var hotspot_inspect := Vector2.ZERO
@export var hotspot_open := Vector2.ZERO
@export var hotspot_attack := Vector2.ZERO
@export var hotspot_climb := Vector2.ZERO
@export var hotspot_descend := Vector2.ZERO


func get_texture(kind: String) -> Texture2D:
	match kind:
		"interact":
			return cursor_interact
		"inspect":
			return cursor_inspect
		"open":
			return cursor_open
		"attack":
			return cursor_attack
		"climb":
			return cursor_climb
		"descend":
			return cursor_descend
		_:
			return cursor_normal


func get_hotspot(kind: String) -> Vector2:
	match kind:
		"interact":
			return hotspot_interact
		"inspect":
			return hotspot_inspect
		"open":
			return hotspot_open
		"attack":
			return hotspot_attack
		"climb":
			return hotspot_climb
		"descend":
			return hotspot_descend
		_:
			return hotspot_normal
