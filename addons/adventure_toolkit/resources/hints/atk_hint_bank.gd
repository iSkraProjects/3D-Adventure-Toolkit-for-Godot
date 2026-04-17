@tool
class_name ATKHintBank
extends Resource

## Layered hint content for a scene or puzzle (Phase 16 / T16.2). Register with [ATKHints] at runtime.


@export var hint_bank_id := ""
@export var display_name := ""
## Shown in order: first request returns index 0, then 1, … until exhausted.
@export var layers: PackedStringArray = []
## Minimum seconds between successful hint deliveries for this bank (0 = no cooldown).
@export_range(0.0, 3600.0, 0.1, "or_greater")
var cooldown_seconds := 0.0
