# 3DATK for Godot by USE Web

## Why This Addon Exists

Most adventure game creators are storytellers, designers, artists, or solo makers. Many of them are blocked by code-heavy pipelines, where every small interaction needs a new script.

ATK exists to remove that friction.

The addon is built so you can create story-driven 3D point-and-click adventures in Godot with:

- inspector-driven setup
- reusable templates
- state + save/load systems that work by default
- shared interaction rules instead of one-off logic

The goal is simple: make adventure game creation accessible to people with little or minimal coding skills, while still being robust enough for technical teams.

## What ATK Is

ATK (Adventure Toolkit) is a modular Godot addon for building 3D adventure games.

It provides:

- scene and spawn management
- click-to-move and click-to-interact
- right-click inspect flow
- inventory
- doors, pickups, NPCs, triggers, exits
- conditions + action sequences (data-driven logic)
- dialogue, quests, journal, hints
- settings/options menu
- save/load persistence
- episode progression baseline

## Core Philosophy

ATK follows 3 principles:

- **Designer-first**: Build in the inspector and resources first.
- **State-driven**: Game progression is represented as persistent state.
- **No-code by default**: Prefer templates, actions, and conditions before custom scripts.

If you can express behavior with ATK exports/resources, that is the preferred path.

## Technical Architecture

ATK uses:

- **Autoload singletons** for global runtime services (`ATKScenes`, `ATKState`, `ATKSave`, etc.)
- **Resource assets** for reusable logic (`ATKActionStep*`, `ATKCondition*`, dialogue definitions, episode definitions)
- **Runtime node classes** for world objects (`ATKAdventureObject`, `ATKDoor`, `ATKPickup`, `ATKNPC`, `ATKTrigger`, `ATKExit`)
- **UI scenes/scripts** for inventory, save/load, dialogue, hints, journal, pause/options

This makes content authoring data-oriented and predictable across scenes.

## Feature Overview

### Scene and Navigation

- `ATKSceneRoot` identifies scenes with stable `scene_id`.
- `ATKSpawnPoint` supports deterministic entry points.
- `ATKScenes` handles scene registration and transitions.
- `ATKPlayerController` provides movement and interaction requests.

### Interaction Model

- Left mouse: primary interaction.
- Right mouse: inspect interaction.
- Objects resolve interaction through shared rule pipeline first, then fallback/default behavior.

### World Object Types

- `ATKInspectable`: inspect-first objects.
- `ATKPickup`: world item -> inventory.
- `ATKDoor`: lock/unlock/open and optional scene transition.
- `ATKNPC`: dialogue and optional no-code item handover flow.
- `ATKTrigger`: area trigger with conditions + enter/exit actions.
- `ATKExit`: no-code scene exit object.

### Data-Driven Logic

Conditions and action sequences let you create puzzle and story flow without writing custom behavior code.

Examples:

- If player has item -> unlock door
- If quest stage reached -> show new dialogue
- If object state changed -> run cinematic/action sequence

### Save/Load and Persistence

ATK persistently stores:

- scene/spawn
- global/scene/object/session state
- inventory/selection
- quests/journal/hints
- settings
- active episode metadata

### Settings and UX

Options include:

- resolution
- master/music/sfx/ambience/voice volumes
- keyboard shortcuts enable/disable
- key rebinding

### Editor Tooling

Plugin menu actions help with:

- assigning stable IDs
- creating interaction points
- validation
- direct template instantiation into scenes

## Templates (Ready to Use)

In `addons/adventure_toolkit/templates/objects/`:

- `Template_Door_Locked.tscn`
- `Template_Door_Exit.tscn`
- `Template_Pickup.tscn`
- `Template_Inspectable.tscn`
- `Template_NPC_Basic.tscn`
- `Template_NPC_Trade.tscn`
- `Template_Trigger.tscn`
- `Template_Exit.tscn`
- `Template_Puzzle_Simple.tscn`

These are designed as copy/duplicate starting points for non-coder workflows.

## Full Usage Manual (General + Technical)

## 1) Installation

1. Open project in Godot 4.6.2 (or 4.5.x+).
2. Enable plugin: `Project Settings -> Plugins -> Adventure Toolkit`.
3. Verify ATK autoloads exist and plugin is active.

## 2) Create a Scene

1. Add `ATKSceneRoot` as root.
2. Set `scene_id` (stable, unique).
3. Add at least one `ATKSpawnPoint` with `spawn_id`.
4. Add player controller and navigation.

## 3) Build Interactions Without Code

1. Place template objects using `ATK/Create Template/*` menu.
2. Fill inspector fields (`object_id`, names, inspect text, requirements).
3. Author action sequences and condition resources.
4. Bind object rules to actions/conditions.

## 4) Build Puzzle Flow

1. Create item definitions (key, quest items, etc.).
2. Use pickup templates for acquisition.
3. Use door/NPC/trigger conditions to gate progression.
4. Use action steps to set world state and provide feedback.

## 5) Dialogue and Quest Flow

1. Create dialogue resources.
2. Assign dialogue to `ATKNPC`.
3. Trigger quest/journal updates via action steps.
4. Use quest/stage conditions to branch outcomes.

## 6) Configure UX and Accessibility

1. Use options menu for video/audio/input preferences.
2. Ensure keyboard shortcuts and keybindings are set for intended audience.
3. Validate subtitle scale/text speed behavior with UI.

## 7) Save/Load Validation

Run a basic persistence test:

1. Start new game.
2. Complete a meaningful interaction chain.
3. Save in slot.
4. Load and verify all object states and inventory.
5. Restart game and load again.

## 8) Recommended Quality Gates

- Every interactable has stable ID.
- Every critical object has inspect text.
- No scene/object ID collisions.
- At least one happy-path full playthrough.
- Save/load pass across restart.

## 9) When to Write Custom Code

Write custom scripts only when behavior is truly unique and not expressible through:

- existing ATK node exports
- condition resources
- action resources
- template composition

When coding, prefer extending ATK classes over replacing systems.

## 10) Common Pitfalls

- Missing IDs -> broken persistence mapping.
- Interaction point misplacement -> awkward approach behavior.
- Scene root not ATK-enabled -> missing ATK scene hooks.
- Ad hoc one-off scripts -> hard-to-maintain content logic.

## For Non-Technical Users

You can build full adventure progression with:

- drag-and-drop templates
- inspector setup
- conditions and actions
- dialogue/quest resources

You do not need advanced programming to ship a complete story flow.

## For Technical Users

ATK is intentionally extensible:

- Add new `ATKActionStep` and `ATKCondition` resources.
- Extend runtime nodes conservatively.
- Keep save schema compatibility and stable IDs.
- Reuse shared pipeline for consistency.

## Project Intent Summary

ATK is not just a toolkit of scripts. It is a production philosophy:

- predictable systems over ad hoc behavior
- authored data over duplicated code
- story and design velocity for humans first

If someone asks, “Can I build an adventure game with this without becoming a programmer?”

The intended answer is: **Yes.**
