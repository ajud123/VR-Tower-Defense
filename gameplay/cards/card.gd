class_name Card
extends Resource
## An upgrade card. Drop a new .tres using this script into
## res://gameplay/cards/pool/ and the vending machine will start selling it.
##
## A card's effect is a set of stat modifiers, applied while it sits in one
## of the active slots. Keys are "<target>.<stat>", where target is either a
## group or a specific type:
##   Towers  - "tower" (all), "archer", "cannon", "mage"
##             damage, fire_rate, range, splash_radius, cost,
##             burn_dps (fire damage per second on hit), slow (0-1 on hit)
##   Enemies - "enemy" (all), "blob", "tank"
##             health, speed, reward, damage_taken
## Multipliers from every active card multiply together; bonuses add up.

@export var title: String = "Card"
@export_multiline var description: String = ""
@export var color: Color = Color(0.4, 0.4, 0.45)
## e.g. {"mage.fire_rate": 2.0} makes mage towers fire twice as fast.
@export var multipliers: Dictionary[String, float] = {}
## e.g. {"archer.damage": 1.0} gives archers +1 damage.
@export var bonuses: Dictionary[String, float] = {}
