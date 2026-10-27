class_name StatModifier
extends Resource
## One stat change granted by an upgrade.
## FLAT adds to the base value, PERCENT scales it (0.2 = +20%).
## Final stat = (base + sum(flat)) * (1 + sum(percent)).

enum Mode { FLAT, PERCENT }

@export var stat: Stats.Stat = Stats.Stat.DAMAGE
@export var mode: Mode = Mode.PERCENT
@export var value := 0.1
