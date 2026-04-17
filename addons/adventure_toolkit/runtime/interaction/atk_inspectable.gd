class_name ATKInspectable
extends ATKAdventureObject

## Designer-first inspect-focused object.
## Uses ATKAdventureObject interaction pipeline and defaults.

@export var inspect_only := false


func interact_default(actor: Node) -> void:
	if inspect_only:
		super._run_legacy_inspect(actor)
		return
	await super.interact_default(actor)
