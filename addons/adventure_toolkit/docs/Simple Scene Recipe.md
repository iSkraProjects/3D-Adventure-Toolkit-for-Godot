# Simple Scene Recipe

How to recreate a small 3DATK scene with:

- a player spawn
- a room the player can walk around
- one inventory item (a key)
- a locked door the player can walk through into another room

No custom gameplay scripts are required. You place templates, give them stable IDs, and fill in Inspector fields.

---

## What you are building

Two rooms:

1. **Start room** — player spawn, floor to walk on, a key on the ground, a locked door.
2. **Exit room** — another spawn so the door has somewhere to send the player.

Loop: click-walk around → click the key (it goes into inventory) → click the door → the door unlocks and loads the next scene.

---

## 0. Plugin on

**Project → Project Settings → Plugins → enable Adventure Toolkit.**

That adds the `ATK/` menu and the autoloads (`ATKScenes`, `ATKInventory`, and the rest).

---

## 1. Make the start room

**Scene → New Scene → Node3D.** Attach `ATKSceneRoot`:

`addons/adventure_toolkit/runtime/scenes/atk_scene_root.gd`

On the root, set:

- `scene_id` = `scene_simple_room`
- `scene_label` = whatever you like

Then add the walkable room:

| Node | What to do |
|---|---|
| Floor | `MeshInstance3D` (PlaneMesh) + `StaticBody3D` with a box collider |
| `NavigationRegion3D` | Bake a navmesh over the floor (a simple quad covering the plane is enough) |
| Camera | `Camera3D`, angled down at the room, **Current** on |
| Light | `DirectionalLight3D` |

Without a baked navmesh, click-to-move will not work.

---

## 2. Player spawn

Add a `Marker3D`, attach `ATKSpawnPoint`, set `spawn_id` = `spawn_entry`. Place it where the player should appear.

Add the player as a `CharacterBody3D` with `ATKPlayerController`, and these children:

- `NavigationAgent3D`
- `CollisionShape3D` (capsule)
- a capsule mesh so you can see them

The controller already joins the `atk_player` / `atk_player_start` groups. When a scene loads with a spawn id, `ATKSceneRoot` teleports that player to the matching `ATKSpawnPoint`.

You can copy this setup from `Scenes/test_adventure.tscn` if you do not want to rebuild it by hand.

---

## 3. Key (one inventory item)

Reuse the built-in brass key: `item_brass_key` in

`addons/adventure_toolkit/resources/inventory/items/item_brass_key.tres`

In the start room:

1. **ATK → Create Template → Pickup** (or instance `Template_Pickup.tscn`).
2. Inspector:
   - `object_id` = `pickup_brass_key`
   - `display_name` = `Brass key`
   - `inspect_text` = `A small brass key.`
   - `item_id` = `item_brass_key`
   - `consume_on_pickup` = on
3. Select the pickup → **ATK → Create Interaction Point Child**. Move that marker to the front of the key so the player walks up to it instead of into it.
4. Add a small mesh + `StaticBody3D` collider as children. The template is logic-only; it has no visuals.

Click the key in play: it is added to inventory and the world object hides. **F** opens inventory.

To make your own key instead: New Resource → `ATKInventoryItemDefinition`, set `item_id` (for example `item_house_key`), display name, icon, and `unique` if there should only be one.

---

## 4. Door they can walk out of

1. **ATK → Create Template → Door Locked**.
2. Inspector:
   - `object_id` = `door_exit`
   - `display_name` = `Exit door`
   - `inspect_text` = `A locked door.`
   - `is_locked` = on
   - `required_item_id` = `item_brass_key` (must match the pickup)
   - `consume_item_on_unlock` = on if the key should be used up
   - `door_transition_mode` = **Change Scene On Open**
   - `destination_scene_id` = `scene_simple_exit`
   - `destination_spawn_id` = `spawn_entry`
3. Select the door → **ATK → Create Interaction Point Child**. Put the marker in front of the door.
4. Add a mesh + collider so it is visible and clickable.
5. Set `is_openable` if you want the open-cursor on hover.

Having the key in inventory is enough. If a *different* item is selected, the door says the wrong-item line instead.

---

## 5. Exit room (the other side)

Second scene, same shell: `ATKSceneRoot` + floor + navmesh + camera + player + `ATKSpawnPoint`.

- `scene_id` = `scene_simple_exit`
- spawn `spawn_id` = `spawn_entry` (must match the door’s `destination_spawn_id`)

You can skip rebuilding the player by duplicating the start room and deleting the key and door.

---

## 6. Register both rooms so the door can load the next one

`ATKScenes` only loads IDs it has registered.

Easiest path: duplicate

`addons/adventure_toolkit/demo/sample_game/scenes/bootstrap.tscn`

and set:

- `start_scene_id` = `scene_simple_room`
- `start_scene_path` = path to your start `.tscn`
- `start_spawn_id` = `spawn_entry`

Bootstrap registers the *start* scene. The exit scene still needs a register. Add a tiny node on the start room (same idea as the demo’s finale register):

```gdscript
func _ready() -> void:
	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes:
		scenes.register_scene("scene_simple_room", "res://Scenes/simple_room.tscn")
		scenes.register_scene("scene_simple_exit", "res://Scenes/simple_exit.tscn")
```

Run the **bootstrap** scene (not the room directly). Playing a room `.tscn` as main scene skips registration and spawn teleport.

---

## Playtest

1. Run bootstrap → you spawn in the room.
2. Left-click floor → player walks.
3. Left-click key → it goes into inventory (**F** to check).
4. Left-click door → it unlocks and loads the exit room at `spawn_entry`.
5. Right-click anything → inspect text.

---

## If something does not work

- **Cannot walk** — navmesh not baked, or no `NavigationAgent3D` on the player.
- **Click does nothing on key/door** — missing `StaticBody3D` collider and/or interaction point.
- **Door always “locked”** — `required_item_id` does not match the pickup `item_id`, or you never picked the key up.
- **Door opens but stays in the same room** — `door_transition_mode` is not Change Scene On Open, or `destination_scene_id` is not registered.
- **Spawn ignored** — empty `spawn_id`, or you ran the room scene instead of bootstrap.

The existing demo (`Scenes/test_adventure.tscn`) is the same pattern with extra NPCs. This recipe is that shell stripped down to spawn + pickup + locked exit door.
