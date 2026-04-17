class_name ATKInventoryItemDefinition
extends Resource


@export var item_id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
@export var category := "general"
@export var stackable := false
## If [code]true[/code], only one instance of this item can exist for the player at a time: it cannot be
## granted again while held, and after it is fully removed (e.g. consumed on a door) it will not respawn or be re-granted.
@export var unique := false
