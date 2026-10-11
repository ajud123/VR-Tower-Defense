extends StaticBody3D
## A spot on the card station a held card can be put into with a desktop
## click: one of the active slots, or the storage mat.

## 0-2 for the active slots, CardStation.STORAGE (-1) for storage.
@export var slot: int = -1

@onready var _station := owner as CardStation


func accept_card(card: CardView) -> bool:
	return _station.place(card, slot)


# Only here so rays target the zone; clicking it empty-handed does nothing.
func interact(_point: Vector3 = Vector3.ZERO) -> void:
	pass
