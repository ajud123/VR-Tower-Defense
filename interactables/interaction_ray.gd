class_name InteractionRay
extends RayCast3D
## Finds interactables (bodies on the "interactable" physics layer with an
## interact(point) method), keeps their hover state up to date, and triggers
## them. Used by both the VR hand pointers and the desktop camera.
##
## Optional methods an interactable can have: hover_enter(), hover_exit(),
## and hover_update(point), called every physics frame while hovered.

## The interactable currently under the ray, or null.
var target: Node = null


func _physics_process(_delta: float) -> void:
	var hit: Object = get_collider() if enabled and is_colliding() else null
	_set_target(hit if hit != null and hit.has_method("interact") else null)
	if target != null and target.has_method("hover_update"):
		target.hover_update(get_collision_point())


## Presses whatever the ray is pointing at. Returns true if something was hit.
func interact() -> bool:
	if not is_instance_valid(target):
		return false
	target.interact(get_collision_point())
	return true


func _exit_tree() -> void:
	_set_target(null)


func _set_target(new_target: Node) -> void:
	if new_target == target:
		return
	if is_instance_valid(target) and target.has_method("hover_exit"):
		target.hover_exit()
	target = new_target
	if target != null and target.has_method("hover_enter"):
		target.hover_enter()
