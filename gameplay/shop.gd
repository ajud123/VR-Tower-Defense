extends Node3D
## The tower shop tray. Shows the stats of whichever tower is hovered, or
## failing that, the one picked and waiting to be built.

@onready var _info: Label3D = $Info


func _process(_delta: float) -> void:
	var focus: Node = null
	for item in get_children():
		if item.has_method("describe") and item.is_hovered():
			focus = item
	if focus == null:
		for item in get_children():
			if item.has_method("describe") and item.is_picked():
				focus = item
	_info.visible = focus != null
	if focus:
		_info.text = focus.describe()
