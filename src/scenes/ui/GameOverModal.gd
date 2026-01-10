extends Control

@onready var panel_container = $CenterContainer/PanelContainer
@onready var title_label = %TitleLabel
@onready var score_label = %ScoreLabel

func setup(winner_team: String, score_p: int, score_o: int):
	if winner_team == "PLAYER":
		title_label.text = tr("EVENT_VICTORY")
		title_label.add_theme_color_override("font_color", Color.GOLD)
	else:
		title_label.text = tr("GAME_OVER_LOST")
		title_label.add_theme_color_override("font_color", Color.TOMATO)
	
	score_label.text = "%d - %d" % [score_p, score_o]
	
	# Intro animation
	panel_container.scale = Vector2.ZERO
	await get_tree().process_frame
	panel_container.pivot_offset = panel_container.size / 2
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_container, "scale", Vector2.ONE, 0.4)

func _on_play_again_pressed():
	_animate_out(func():
		GameManager.reset_game()
		get_tree().reload_current_scene()
	)

func _on_main_menu_pressed():
	_animate_out(func():
		get_tree().change_scene_to_file("res://src/scenes/menu/MainMenu.tscn")
	)

func _animate_out(callback: Callable):
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(panel_container, "scale", Vector2.ZERO, 0.3)
	tween.tween_callback(callback)
