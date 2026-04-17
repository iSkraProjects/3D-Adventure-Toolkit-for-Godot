# Adventure Toolkit Foundation Conventions

## Purpose

This document defines the initial directory, naming, and ID conventions for the
Godot 3D Adventure Toolkit. All new Phase 0+ work should follow these rules
unless a later approved architecture update replaces them.

## Directory Responsibilities

- `addons/adventure_toolkit/core`
  - shared constants, helper types, utility code, and signal definitions
- `addons/adventure_toolkit/runtime`
  - runtime gameplay systems, managers, node classes, and interaction flow
- `addons/adventure_toolkit/editor`
  - editor-only tooling, inspectors, validators, and creation helpers
- `addons/adventure_toolkit/resources`
  - reusable authored resource scripts and resource assets
- `addons/adventure_toolkit/ui`
  - runtime UI and debug UI scenes/scripts
- `addons/adventure_toolkit/templates`
  - reusable starter scenes and object templates
- `addons/adventure_toolkit/demo`
  - sample content proving the vertical slice and later integrations
- `addons/adventure_toolkit/docs`
  - implementation and usage documentation

## Runtime Subdirectory Rules

- `runtime/autoload`
  - autoload singleton scripts such as `ATK`, `ATKState`, and `ATKScenes`
- `runtime/managers`
  - non-autoload manager classes used by the autoload facade or runtime scenes
- `runtime/scenes`
  - scene bootstrap and scene-root-related scripts
- `runtime/interaction`
  - base interactable nodes and interaction routing logic
- `runtime/actions`
  - action resources, context objects, and runners
- `runtime/conditions`
  - condition resources and evaluation helpers
- `runtime/inventory`
  - inventory runtime nodes, definitions, and helpers
- `runtime/dialogue`
  - dialogue runtime systems and supporting data flow
- `runtime/quests`
  - quest and progression systems
- `runtime/save`
  - save payload, slot management, and settings persistence
- `runtime/state`
  - state models and state-related helpers
- `runtime/navigation`
  - player navigation integration and movement helpers
- `runtime/audio`
  - music, ambience, and action-level audio hooks
- `runtime/cutscenes`
  - cutscene integration hooks and sequence support

## Naming Conventions

- GDScript filenames use `snake_case.gd`
- Godot scenes use `PascalCase.tscn` for reusable toolkit nodes and templates
- Resource assets use `snake_case.tres` or `snake_case.res`
- Documentation files use `snake_case.md`
- Code symbols use `PascalCase` for classes and `snake_case` for methods,
  variables, signals, and properties
- Public toolkit class names use the `ATK` prefix

## Initial Script Placement Rules

- autoload scripts belong in `runtime/autoload`
- reusable node classes belong in the runtime subfolder closest to behavior
- shared low-level helpers belong in `core/utils`
- editor-only scripts must stay under `editor`
- authored resource scripts belong in `resources` or the relevant runtime folder
  only when tightly coupled to runtime behavior

## Stable ID Conventions

- stable IDs must use readable `snake_case`
- IDs should describe purpose, not implementation details
- persistent scene IDs, spawn IDs, object IDs, item IDs, quest IDs, dialogue IDs,
  and puzzle IDs must be manually authorable
- transient node paths must never be the only persistent identity

## Recommended ID Formats

- scene IDs: `scene_foyer`, `scene_library`
- spawn IDs: `spawn_entry`, `spawn_library_door`
- object IDs: `door_library_main`, `prop_foyer_painting`
- item IDs: `item_brass_key`
- quest IDs: `quest_restore_power`
- puzzle IDs: `puzzle_generator`

## Validation Rules

- each save-critical scene must declare one stable `scene_id`
- spawn IDs must be unique within their scene
- object IDs must be unique within authored content
- new systems should reuse these conventions instead of creating local naming
  schemes
