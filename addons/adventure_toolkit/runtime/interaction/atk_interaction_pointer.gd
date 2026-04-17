class_name ATKInteractionPointer
extends Object

## Shared screen-space raycast used by [ATKPlayerController] and [ATKInteractionHover].


static func adventure_object_from_screen_pos(
	screen_pos: Vector2,
	viewport: Viewport,
	extra_exclude: Array = []
) -> ATKAdventureObject:
	if viewport == null:
		return null

	var camera := viewport.get_camera_3d()
	if camera == null:
		return null

	var world := viewport.get_world_3d()
	if world == null:
		return null

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_end := ray_origin + camera.project_ray_normal(screen_pos) * 4000.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var exclude: Array = []
	var tree := viewport.get_tree()
	if tree != null:
		for n in tree.get_nodes_in_group("atk_player"):
			if n is CollisionObject3D:
				exclude.append(n)
	for n in extra_exclude:
		if n is CollisionObject3D and not exclude.has(n):
			exclude.append(n)
	query.exclude = exclude

	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var collider: Variant = hit.get("collider")
	if collider is Node:
		return _find_adventure_object(collider as Node)

	return null


static func _find_adventure_object(node: Node) -> ATKAdventureObject:
	var current: Node = node
	while current != null:
		if current is ATKAdventureObject:
			return current as ATKAdventureObject
		current = current.get_parent()
	return null
