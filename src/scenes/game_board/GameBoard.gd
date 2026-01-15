extends Control

# GameBoard.gd
# Main arena for "Fourty Last Bet".

const CARD_UI_SCENE = preload("res://src/scenes/cards/CardUI.tscn")
const GAME_OVER_MODAL_SCENE = preload("res://src/scenes/ui/GameOverModal.tscn")

@onready var hand_container = %HandContainer
@onready var opponent_hand_container = %OpponentHandContainer
@onready var table_grid = %TableGrid
@onready var capture_choice_scene = preload("res://src/scenes/ui/CaptureChoiceUI.tscn")
@onready var sfx_round_start = %SfxRoundStart
@onready var sfx_deal = %SfxDeal
@onready var sfx_card_play = %SfxCardPlay
@onready var sfx_capture = %SfxCapture
@onready var ui = $GameBoardUI
@onready var audio = $GameBoardAudio
@onready var animator = $GameBoardAnimator

var play_shuffle_next_deal: bool = true

func _ready():
	_connect_signals()
	# Wait a frame for layout to settle
	await get_tree().process_frame
	start_game()

func start_game():
	GameManager.load_deck()
	GameManager.shuffle_deck()
	ui.update_scores()
	deal_round()

func _connect_signals():
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.new_round_requested.connect(_on_new_round_requested)
	GameManager.game_event_occurred.connect(_on_game_event_occurred)
	GameManager.game_over.connect(_on_game_over)
	GameManager.capture_choice_requested.connect(_on_capture_choice_requested)
	GameManager.deck_reshuffled.connect(_on_deck_reshuffled)

func _on_game_event_occurred(type: String, team: String, points: int):
	if type in ["CAPTURE", "CAIDA", "LIMPIA"]:
		audio.play_sfx(sfx_capture)
	var label_text = _build_event_text(type, team, points)
	var color = _event_color(type)
	ui.show_event_notification(label_text, color)

func _on_game_over(winner_team: String, score_p: int, score_o: int):
	var modal = GAME_OVER_MODAL_SCENE.instantiate()
	add_child(modal)
	modal.setup(winner_team, score_p, score_o)

func _on_capture_choice_requested(options: Array):
	var choice_ui = capture_choice_scene.instantiate()
	add_child(choice_ui)
	
	# Pass data
	choice_ui.setup(options)
	
	# Listen for selection
	choice_ui.option_selected.connect(func(index):
		GameManager.resolve_pending_capture(index)
		_refresh_table_ui()
		# UI handles its own destruction
	)

func _on_menu_button_pressed():
	get_tree().change_scene_to_file("res://src/scenes/menu/MainMenu.tscn")
	
func deal_round():
	var p_cards = GameManager.deal_cards(5)
	var o_cards = GameManager.deal_cards(5)

	if play_shuffle_next_deal:
		audio.play_sfx(sfx_round_start)
		await audio.wait_for_sfx(sfx_round_start)
		play_shuffle_next_deal = false
	
	GameManager.player_hand.append_array(p_cards)
	GameManager.opponent_hand.append_array(o_cards)
	
	for i in range(5):
		await _deal_one_to_hand(p_cards[i], true)
		await _deal_one_to_hand(o_cards[i], false)

	# Check for Ronda bonus points
	GameManager.check_for_ronda(true)
	GameManager.check_for_ronda(false)
	ui.update_scores()

func _refresh_table_ui():
	for table_card in table_grid.get_children():
		if table_card is CardUI and table_card.card_data not in GameManager.cards_on_table:
			table_card.queue_free()

func spawn_card_to_hand(data: CardData, is_player: bool):
	await animator.spawn_card_to_hand(CARD_UI_SCENE, data, is_player)

func _deal_one_to_hand(data: CardData, is_player: bool):
	audio.play_sfx(sfx_deal)
	await spawn_card_to_hand(data, is_player)
	await audio.wait_for_sfx(sfx_deal)

func _on_new_round_requested():
	# Small delay to let the last play settle visually
	await get_tree().create_timer(1.0).timeout
	deal_round()

func _on_deck_reshuffled():
	play_shuffle_next_deal = true

func _on_turn_changed(new_state):
	ui.update_scores()
	if new_state == GameManager.GameState.OPPONENT_TURN:
		run_opponent_ai()

func run_opponent_ai():
	await get_tree().create_timer(1.5).timeout
	if opponent_hand_container.get_child_count() > 0:
		var card_ui = opponent_hand_container.get_child(0) as CardUI
		play_card_to_table(card_ui, false)

func play_card_to_table(card_ui: CardUI, is_player: bool):
	audio.play_sfx(sfx_card_play)
	await animator.animate_card_to_table(card_ui)

	# Update logic first so we know if it was captured
	GameManager.play_card_to_table(card_ui.card_data, is_player)
	
	# Now check if it stayed on table or was a Caida/Capture
	if card_ui.card_data in GameManager.cards_on_table:
		animator.place_card_on_table(card_ui)
	else:
		# It was captured or it's a Caida
		card_ui.queue_free()
	
	# Refresh rest of table UI
	_refresh_table_ui()
	ui.update_scores()

func _build_event_text(type: String, team: String, points: int) -> String:
	return ui.build_event_text(type, team, points)

func _event_color(type: String) -> Color:
	return ui.event_color(type)
