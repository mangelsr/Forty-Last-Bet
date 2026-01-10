class_name CardData
extends Resource

# CardData.gd
# Base resource for all cards in "Fourty Last Bet".

@export var card_name: String = ""
@export var suit: String = ""
@export var value: int = 0
@export var texture: Texture2D
@export var description: String = ""

func _to_string() -> String:
	var val_str := str(value)
	match value:
		1: val_str = "A"
		11: val_str = "J"
		12: val_str = "Q"
		13: val_str = "K"
	return "[%s %s]" % [val_str, suit.left(1)]
