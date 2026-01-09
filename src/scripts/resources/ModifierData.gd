class_name ModifierData
extends Resource

# ModifierData.gd
# Roguelike modifiers/relics that affect the run.

@export var modifier_name: String = ""
@export var description: String = ""
@export var rarity: int = 0 # 0: Common, 1: Rare, etc.
