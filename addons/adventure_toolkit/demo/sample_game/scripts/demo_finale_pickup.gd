extends ATKPickup

## Demo: picking this up ends the playthrough with a short thank-you message.

@export_multiline var finale_message := "You found the golden orb. Thanks for playing the AGToolkit demo!"
@export var finale_title := "Demo complete"
@export_file("*.tscn") var main_menu_scene_path := "res://addons/adventure_toolkit/demo/sample_game/scenes/atk_main_menu.tscn"


func _ready() -> void:
	show_pickup_feedback = false
	super._ready()


func interact_default(actor: Node) -> void:
	super.interact_default(actor)
	_run_finale()


func _run_finale() -> void:
	var bus := get_node_or_null("/root/ATKInteractionFeedback")
	var msg := finale_message.strip_edges()
	if bus != null and bus.has_method("show_message") and not msg.is_empty():
		bus.show_message(msg, finale_title, object_id)
		if bus.has_signal("message_dismissed"):
			await bus.message_dismissed
	elif bus == null or not bus.has_method("show_message"):
		await get_tree().create_timer(0.5, true).timeout
	await _go_to_main_menu()


func _go_to_main_menu() -> void:
	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes == null or not scenes.has_method("load_scene"):
		push_warning("demo_finale_pickup: ATKScenes missing; cannot return to main menu.")
		get_tree().quit()
		return
	var path := main_menu_scene_path.strip_edges()
	if path.is_empty():
		get_tree().quit()
		return
	var err: Error = await scenes.load_scene(path, "")
	if err != OK:
		push_warning("demo_finale_pickup: failed to load main menu (%d)." % err)
		get_tree().quit()
