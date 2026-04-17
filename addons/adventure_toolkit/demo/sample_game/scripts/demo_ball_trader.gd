extends ATKNPC

## Demo: blue character — with the rubber ball selected in inventory, click to hand it over and unlock the side passage.


@export var ball_item_id := "item_demo_ball"
@export_multiline var hint_no_ball := "Select the rubber ball in your bag, then talk to me again."
@export_multiline var thank_you_line := "Thank you! I've opened the passage on the west side. Step through the doorway when you're ready."


func _ready() -> void:
	# Keep demo compatibility while routing behavior through reusable ATKNPC no-code handover flow.
	handover_enabled = true
	handover_required_item_id = ball_item_id
	handover_require_selected_item = true
	handover_consume_item = true
	handover_only_once = true
	handover_success_line = thank_you_line
	handover_missing_item_line = hint_no_ball
	handover_success_global_key = "demo_ball_delivered"
	handover_success_global_value = true
	super._ready()
