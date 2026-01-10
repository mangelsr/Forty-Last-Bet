extends Control

@onready var lang_button = %LangButton

func _ready():
	_update_lang_button()

func _update_lang_button():
	var locale = TranslationServer.get_locale()
	if locale.begins_with("es"):
		lang_button.text = "ENGLISH"
	else:
		lang_button.text = "ESPAÑOL"

func _on_lang_button_pressed():
	var locale = TranslationServer.get_locale()
	if locale.begins_with("es"):
		TranslationServer.set_locale("en")
	else:
		TranslationServer.set_locale("es")
	_update_lang_button()

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://src/scenes/game_board/GameBoard.tscn")

func _on_how_to_play_button_pressed():
	get_tree().change_scene_to_file("res://src/scenes/menu/HowToPlay.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
