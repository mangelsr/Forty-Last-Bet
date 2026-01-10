extends Control

@onready var capture_choice_scene = preload("res://src/scenes/ui/CaptureChoiceUI.tscn")

func _on_test_button_pressed():
	var ui = capture_choice_scene.instantiate()
	add_child(ui)
	
	# Mock Data
	var option1 = [create_card(5, "Spades")]
	var option2 = [create_card(2, "Hearts"), create_card(3, "Diamonds")]
	var option3 = [create_card(1, "Clubs"), create_card(4, "Spades")]
	var option4 = [create_card(5, "Diamonds"), create_card(6, "Hearts"), create_card(7, "Clubs")] # Stair
	
	var options = [option1, option2, option3, option4]
	
	ui.setup(options)
	ui.option_selected.connect(func(index):
		print("Selected Option Index: ", index)
		# In a real game, this would call GameManager.resolve_pending_capture(index)
	)

func create_card(value: int, suit: String) -> CardData:
	var c = CardData.new()
	c.value = value
	c.suit = suit
	return c
