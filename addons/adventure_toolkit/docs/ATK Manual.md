# ATK Manual (Private Build Guide)

This manual is for you, the creator of this addon, and focuses only on how to recreate the current demo game step by step using ATK.

It is not a public philosophy document. It is a practical build recipe.

## Goal

Rebuild the demo gameplay loop:

1. Start in main menu.
2. New game enters `scene_test_adventure`.
3. Talk to Quartermaster to get key.
4. Use key to open crate and reveal ball.
5. Pick up ball.
6. Give ball to Courier.
7. West passage unlocks.
8. Use west door to load finale scene.
9. Save/load works throughout.

## Project Baseline

- Main menu scene: `addons/adventure_toolkit/demo/sample_game/scenes/atk_main_menu.tscn`
- First gameplay room: `Scenes/test_adventure.tscn`
- Finale room: `Scenes/demo_scene_finale.tscn` (or your assigned finale scene)

## Part A — Scene Setup

## 1) Create/verify main adventure room

In `Scenes/test_adventure.tscn`:

1. Root node uses `ATKSceneRoot`.
2. Set:
   - `scene_id = scene_test_adventure`
   - scene label as you prefer
3. Add at least one `ATKSpawnPoint`:
   - `spawn_id = spawn_entry`
4. Add floor + navigation region.
5. Add player with `ATKPlayerController`.

## 2) Register scenes

Ensure `ATKScenes` knows both:

- `scene_test_adventure`
- `scene_demo_finale`

If your bootstrap/register nodes already do this, keep them.

## Part B — Build Demo Interactables

Use ATK templates from editor menu (`ATK/Create Template/*`) whenever possible.

## 3) Quartermaster NPC (gives key through dialogue)

1. Place `Template_NPC_Basic`.
2. Rename to `DialogueKeyNPC`.
3. Set:
   - `object_id = npc_dialogue_key_giver`
   - display/inspect text
4. Assign dialogue resource that grants `item_brass_key`.
5. Place `InteractionPoint` in front of NPC.

Result: talking to Quartermaster grants the key.

## 4) Crate Door (locked by key)

1. Place `Template_Door_Locked` (or demo crate door script setup if preserving current demo style).
2. Set:
   - `object_id = prop_crate`
   - `required_item_id = item_brass_key`
   - `consume_item_on_unlock = true` (if desired)
   - locked/wrong/open response text
   - inspect text
3. Add child pickup ball object (initially hidden/interactions off).
4. Configure crate open behavior to show/enable ball pickup.

Result: crate opens only after obtaining key.

## 5) Ball Pickup

1. Place `Template_Pickup` as child/object near crate interior.
2. Set:
   - `item_id = item_demo_ball`
   - `object_id = pickup_rubber_ball`
   - display/inspect text
3. Initial state:
   - hidden + not interactable until crate opened.

Result: player can pick ball after crate unlock.

## 6) Courier NPC (ball handover, no custom logic required)

Use trade NPC flow:

1. Place `Template_NPC_Trade`.
2. Set:
   - `object_id = npc_ball_receiver`
   - `handover_required_item_id = item_demo_ball`
   - `handover_require_selected_item = true`
   - `handover_consume_item = true`
   - `handover_only_once = true`
   - success line / missing item line
   - `handover_success_global_key = demo_ball_delivered`
   - `handover_success_global_value = true`
3. Set inspect text and interaction point.

Result: giving ball sets global flag used by final door.

## 7) West Passage Door (unlocks by global state)

1. Place `Template_Door_Exit`.
2. Set:
   - `object_id = door_west_passage`
   - `required_global_key = demo_ball_delivered`
   - `required_global_value = true`
   - `destination_scene_id = scene_demo_finale`
   - `destination_spawn_id = spawn_finale`
3. Add inspect and locked/open responses.

Result: door unlocks after courier handover and transitions to finale.

## Part C — UI and Menus

## 8) Main menu order

Ensure buttons are:

1. New Game
2. Continue Latest
3. Load Game
4. Options
5. Quit to Desktop

## 9) Pause menu order

Ensure buttons are:

1. Resume
2. Save/Load Game
3. Options
4. Quit to Title
5. Quit to Desktop

Both quit-to-title and quit-to-desktop should use confirm dialogs.

## 10) Options functionality

Verify options are wired and persistent:

- Resolution
- Master/Music/SFX/Ambience/Voice sliders
- Keyboard shortcuts toggle
- Key rebinding

Expected defaults:

- Master 100%
- Music/SFX/Ambience/Voice 50%

## Part D — Interaction Behavior

## 11) Inspect verb

- Right-click should call inspect.
- Every important object should have `inspect_text`.
- If a subclass overrides interaction, inspect must still route to base inspect behavior.

## 12) Cursor feedback

- Keep hover feedback enabled.
- If engine/editor limits cursor rendering in embedded mode, prioritize runtime/exported behavior.

## Part E — Save/Load Checks

## 13) Required save/load test

Run this exact test:

1. Start game.
2. Talk Quartermaster, obtain key.
3. Open crate.
4. Save.
5. Load.
6. Confirm state is identical.
7. Restart game.
8. Load again and confirm persistence.

If this passes, progression persistence is healthy.

## Part F — Recommended Build Workflow for You

When creating new rooms:

1. Duplicate scene shell with `ATKSceneRoot`.
2. Add spawn points first.
3. Lay down interactables from templates.
4. Fill IDs and inspect text immediately.
5. Add conditions/actions/dialogue resources.
6. Run quick playthrough.
7. Run save/load regression.

## Quick Troubleshooting for This Demo

- Ball not visible: crate open state not propagated to pickup visibility/interactable flags.
- Door never opens: `demo_ball_delivered` key/value mismatch.
- Inspect missing on one object: overridden interaction path not delegating inspect.
- Scene transition fails: scene not registered or wrong `scene_id`.

## Final Checklist (Demo Complete)

- Quartermaster gives key.
- Crate opens with key.
- Ball can be picked.
- Courier accepts ball.
- Global state updates.
- West door opens and transitions.
- Save/load survives restart.
- Main/pause/options behavior matches intended UX.
