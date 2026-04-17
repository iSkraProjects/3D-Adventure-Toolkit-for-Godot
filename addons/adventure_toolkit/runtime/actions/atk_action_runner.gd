class_name ATKActionRunner
extends RefCounted

## Runs `ATKActionSequence` in order with `await` (T7.5).


static func run_sequence(
	sequence: ATKActionSequence,
	context: ATKActionContext,
	on_finished: Callable = Callable()
) -> bool:
	if sequence == null:
		ATKLog.warn("ActionRunner: null sequence.", "ATKAction")
		if on_finished.is_valid():
			on_finished.call(false)
		return false

	var label := sequence.sequence_id if not sequence.sequence_id.is_empty() else sequence.resource_name
	ATKLog.debug("Sequence '%s' start (%d steps)." % [label, sequence.steps.size()], "ATKAction")

	for step in sequence.steps:
		if step == null:
			continue
		await step.run(context)

	ATKLog.debug("Sequence '%s' finished." % label, "ATKAction")
	if on_finished.is_valid():
		on_finished.call(true)
	return true
