extends StaticBody3D
## A pull lever that rotates about its own X axis, from straight up at rest
## to pull_angle_degrees when fully pulled (the knob swings towards +Z and
## down). In VR grab the knob and pull it down; on desktop click it and it
## pulls itself. Emits `pulled` each time it hits the bottom, then springs back.

signal pulled

@export var pull_angle_degrees: float = 100.0
## How far down the hand has to move, in metres, for a full pull.
@export var pull_distance: float = 0.25
## How fast the lever springs back when let go, in full pulls per second.
@export var return_speed: float = 3.0

## 0 at rest, 1 fully pulled.
var _amount: float = 0.0
var _hand: Node3D
var _grab_height: float
var _auto_pulling := false
var _fired := false


func _process(delta: float) -> void:
	if is_instance_valid(_hand):
		_amount = clampf((_grab_height - _hand.global_position.y) / pull_distance, 0.0, 1.0)
	elif not _auto_pulling:
		_amount = move_toward(_amount, 0.0, return_speed * delta)
	rotation.x = deg_to_rad(pull_angle_degrees) * _amount

	if _amount >= 0.97 and not _fired:
		_fired = true
		pulled.emit()
	elif _amount < 0.3:
		_fired = false


func interact(_point: Vector3 = Vector3.ZERO) -> void:
	# Only from rest, so every click is one full pull.
	if _hand or _auto_pulling or _amount > 0.0:
		return
	_auto_pulling = true
	var tween := create_tween()
	tween.tween_property(self, "_amount", 1.0, 0.2)
	tween.tween_callback(func() -> void: _auto_pulling = false)


func grab(hand: Node3D) -> Object:
	if _hand:
		return null
	_hand = hand
	# Keep the lever where it is when grabbed mid-swing.
	_grab_height = hand.global_position.y + _amount * pull_distance
	return self


func release() -> void:
	_hand = null
