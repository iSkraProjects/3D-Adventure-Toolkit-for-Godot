extends Node

## Ensures [code]scene_demo_finale[/code] is registered when this scene runs without the main menu (e.g. Run Current Scene).


func _ready() -> void:
	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes != null and scenes.has_method("register_scene"):
		scenes.register_scene("scene_demo_finale", "res://Scenes/demo_scene_finale.tscn")
