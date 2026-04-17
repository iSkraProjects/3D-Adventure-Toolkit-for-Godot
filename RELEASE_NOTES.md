# Release Notes

## v0.5 Initial Public Upload

3DATK for Godot by use<web/> is now publicly uploaded as a designer-first 3D adventure toolkit for Godot.

### Highlights

- Core runtime systems for scenes, state, save/load, inventory, dialogue, quests, hints, audio, settings, and episodes.
- Data-driven condition/action pipeline for low-code and no-code interaction authoring.
- Right-click inspect flow and shared interaction fallback behavior.
- Main menu and pause menu with integrated options menu and confirmation dialogs.
- Settings for resolution, audio channels, keyboard-shortcut toggle, and key rebinding.
- Template library for common adventure objects:
  - doors
  - exits
  - inspectables
  - pickups
  - NPCs (basic and trade)
  - triggers
  - simple puzzle controller
- Editor tooling for:
  - stable ID assignment
  - interaction point creation
  - validation helpers
  - one-click template instantiation in scene
- Demo game flow included for reference and reuse.

### Documentation Included

- `README.md` (public-facing overview, purpose, architecture, and usage philosophy)
- `addons/adventure_toolkit/docs/foundation_conventions.md`

### Packaging Notes

- Repository is prepared for GitHub distribution.
- Editor cache/generated directories are excluded through `.gitignore`.
- Root launcher scene (`ATK_Demo_Start.tscn`) is included for quick demo entry.

### Compatibility

- Target: Godot `4.6.2`
- Designed to remain compatible with Godot `4.5.x+`

## v0.5 Documentation and UX Sync

### Documentation Updates

- Refreshed all Markdown docs to match current runtime behavior.
- Clarified naming: brand is `3DATK`, runtime code symbols remain `ATK`.
- Updated creator manual with current demo workflow and validation checkpoints.

### UX/System Updates Covered in Docs

- Global cursor theme resource workflow (`ATKCursorTheme` + `default_cursor_theme.tres`).
- Cursor intents/capability flags for interactables (`open`, `attack`, `climb`, `descend`).
- Icon-first inventory workflow:
  - item definition icon
  - pickup icon override
  - action-based icon override for non-scene item grants
- Classic inventory tile behavior:
  - fixed icon tile sizing
  - quantity badges
  - right-click inspect
  - selected-item preview icon
  - auto-close on selection
