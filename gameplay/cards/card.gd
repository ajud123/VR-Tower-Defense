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
## The card's face is drawn from these: an icon for the target, one for the
## stat, and the amount (see gameplay/icons/).

@export var title: String = "Card"
## Printed on the back of the card.
@export_multiline var description: String = ""
@export var color: Color = Color(0.4, 0.4, 0.45)
## e.g. {"mage.fire_rate": 2.0} makes mage towers fire twice as fast.
@export var multipliers: Dictionary[String, float] = {}
## e.g. {"archer.damage": 1.0} gives archers +1 damage.
@export var bonuses: Dictionary[String, float] = {}


## One entry per modifier, for drawing the card:
## {"target": "archer", "stat": "burn_dps", "text": "+1.5/s"}.
func effects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in multipliers:
		result.append(_effect(key, _multiplier_text(multipliers[key])))
	for key in bonuses:
		result.append(_effect(key, _bonus_text(key.get_slice(".", 1), bonuses[key])))
	return result


func _effect(key: String, text: String) -> Dictionary:
	return {"target": key.get_slice(".", 0), "stat": key.get_slice(".", 1), "text": text}


func _multiplier_text(value: float) -> String:
	if value >= 2.0 and is_equal_approx(value, roundf(value)):
		return "x%d" % roundi(value)
	var percent := roundi((value - 1.0) * 100.0)
	return "%+d%%" % percent


func _bonus_text(stat: String, value: float) -> String:
	var amount := str(snappedf(value, 0.1)).trim_suffix(".0")
	match stat:
		"burn_dps":
			return "+%s/s" % amount
		"slow":
			return "-%d%%" % roundi(value * 100.0)
	return "+" + amount
