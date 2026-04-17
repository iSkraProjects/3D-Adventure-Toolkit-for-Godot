class_name ATKBootstrap
extends Node

## Optional fast path: run this scene from the editor to skip the main menu and load [member start_scene_path] directly.
## The project’s **run/main_scene** is normally [code]atk_main_menu.tscn[/code] (Phase 15).


@export var start_scene_id := ""
@export_file("*.tscn") var start_scene_path := ""
@export var start_spawn_id := ""


func _ready() -> void:
	if start_scene_id.is_empty():
		push_error("ATKBootstrap requires a start_scene_id.")
		return

	if start_scene_path.is_empty():
		push_error("ATKBootstrap requires a start_scene_path.")
		return

	var scene_manager := get_node_or_null("/root/ATKScenes")
	if scene_manager == null:
		push_error("ATKBootstrap requires the ATKScenes autoload.")
		return

	scene_manager.register_scene(start_scene_id, start_scene_path)
	call_deferred("_begin_bootstrap_transition")


func _begin_bootstrap_transition() -> void:
	var scene_manager := get_node_or_null("/root/ATKScenes")
	if scene_manager == null:
		push_error("ATKBootstrap requires the ATKScenes autoload.")
		return

	scene_manager.load_scene(start_scene_id, start_spawn_id)
