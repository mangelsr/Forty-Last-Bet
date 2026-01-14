extends Control

# GameBoard.gd
# Main arena for "Fourty Last Bet".

const CARD_UI_SCENE = preload("res://src/scenes/cards/CardUI.tscn")
const GAME_OVER_MODAL_SCENE = preload("res://src/scenes/ui/GameOverModal.tscn")

@onready var hand_container = %HandContainer
@onready var opponent_hand_container = %OpponentHandContainer
@onready var table_grid = %TableGrid
@onready var deck_position = %DeckPosition
@onready var player_score_label = %PlayerScore
@onready var opponent_score_label = %OpponentScore
@onready var message_container = %MessageContainer
@onready var sfx_round_start = %SfxRoundStart
@onready var sfx_deal = %SfxDeal
@onready var sfx_card_play = %SfxCardPlay
@onready var sfx_capture = %SfxCapture

var play_shuffle_next_deal: bool = true

func _ready():
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.new_round_requested.connect(_on_new_round_requested)
	GameManager.game_event_occurred.connect(_on_game_event_occurred)
	GameManager.game_over.connect(_on_game_over)
	GameManager.capture_choice_requested.connect(_on_capture_choice_requested)
	GameManager.deck_reshuffled.connect(_on_deck_reshuffled)
	# Wait a frame for layout to settle
	await get_tree().process_frame
	start_game()

func start_game():
	GameManager.load_deck()
	GameManager.shuffle_deck()
	update_scores()
	deal_round()

func _on_game_event_occurred(type: String, team: String, points: int):
	if type in ["CAPTURE", "CAIDA", "LIMPIA"]:
		_play_sfx(sfx_capture)

	var color = Color.WHITE
	# Map type to translation key (e.g. CAIDA -> EVENT_CAIDA, DOBLE RONDA -> EVENT_DOBLE_RONDA)
	var tr_key = "EVENT_" + type.replace(" ", "_")
	var text = tr(tr_key)
	
	if points > 0:
		text += "! +" + str(points)
	else:
		text += "!"
		
	match type:
		"CAIDA":
			color = Color.YELLOW
		"LIMPIA":
			color = Color.CYAN
		"RONDA", "DOBLE RONDA":
			color = Color.MAGENTA
		"CAPTURE":
			color = Color.GREEN_YELLOW
		"CARTON":
			color = Color.SKY_BLUE
	
	# Translate team name using existing keys GAME_PLAYER / GAME_OPPONENT
	var team_key = "GAME_" + team
	var team_text = tr(team_key)
	
	var label_text = "[%s] %s" % [team_text, text]
	show_event_notification(label_text, color)

func _on_game_over(winner_team: String, score_p: int, score_o: int):
	var modal = GAME_OVER_MODAL_SCENE.instantiate()
	add_child(modal)
	modal.setup(winner_team, score_p, score_o)
@onready var capture_choice_scene = preload("res://src/scenes/ui/CaptureChoiceUI.tscn")

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

func show_event_notification(text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	
	# Use VBox for layout if not already
	var vbox = message_container.get_node_or_null("MessageVBox")
	if not vbox:
		vbox = VBoxContainer.new()
		vbox.name = "MessageVBox"
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.anchors_preset = Control.PRESET_CENTER
		vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
		vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
		# Ensure it's centered in the container (which is already centered)
		message_container.add_child(vbox)
		# Force update to ensure it centers
		vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	# Create a slot for the message to reserve space in the VBox
	var slot = Control.new()
	slot.custom_minimum_size = Vector2(0, 60) # Reserve vertical space
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(slot)
	
	slot.add_child(label)
	
	# Wait for a frame to get correct size for centering
	await get_tree().process_frame
	
	# Center label in slot
	label.position = (slot.size - label.size) / 2
	label.pivot_offset = label.size / 2
	
	# Initial Animation State
	label.modulate.a = 0
	label.scale = Vector2(0.5, 0.5)
	
	# Animate
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.4)
	tween.tween_property(label, "modulate:a", 1.0, 0.2)
	# Float up relative to the slot
	tween.tween_property(label, "position:y", label.position.y - 120, 1.5).set_trans(Tween.TRANS_SINE)
	
	# Fade out and cleanup
	var fade_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fade_tween.tween_interval(1.5)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.5)
	# Remove the slot (parent), which removes the label too
	fade_tween.tween_callback(slot.queue_free)
	

func _on_menu_button_pressed():
	get_tree().change_scene_to_file("res://src/scenes/menu/MainMenu.tscn")
	

@onready var player_captured_label = %PlayerCapturedCount
@onready var opponent_captured_label = %OpponentCapturedCount

func update_scores():
	player_score_label.text = tr("GAME_PLAYER") + ": " + str(GameManager.player_score)
	opponent_score_label.text = tr("GAME_OPPONENT") + ": " + str(GameManager.opponent_score)
	
	player_captured_label.text = tr("GAME_MY_CARDS") + ": " + str(GameManager.player_captured.size())
	opponent_captured_label.text = tr("GAME_OPP_CARDS") + ": " + str(GameManager.opponent_captured.size())

func deal_round():
	var p_cards = GameManager.deal_cards(5)
	var o_cards = GameManager.deal_cards(5)

	if play_shuffle_next_deal:
		_play_sfx(sfx_round_start)
		await _wait_for_sfx(sfx_round_start)
		play_shuffle_next_deal = false
	
	GameManager.player_hand.append_array(p_cards)
	GameManager.opponent_hand.append_array(o_cards)
	
	for i in range(5):
		_play_sfx(sfx_deal)
		spawn_card_to_hand(p_cards[i], true)
		await _wait_for_sfx(sfx_deal)		
		_play_sfx(sfx_deal)
		spawn_card_to_hand(o_cards[i], false)
		await _wait_for_sfx(sfx_deal)		

	# Check for Ronda bonus points
	GameManager.check_for_ronda(true)
	GameManager.check_for_ronda(false)
	update_scores()

func _refresh_table_ui():
	for table_card in table_grid.get_children():
		if table_card is CardUI and table_card.card_data not in GameManager.cards_on_table:
			table_card.queue_free()

func spawn_card_to_hand(data: CardData, is_player: bool):
	var card_ui = CARD_UI_SCENE.instantiate() as CardUI
	card_ui.card_data = data
	card_ui.is_face_up = is_player
	
	add_child(card_ui)
	card_ui.global_position = deck_position.global_position
	
	var target_parent = hand_container if is_player else opponent_hand_container
	var tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	await tween.tween_property(card_ui, "global_position", target_parent.global_position, 0.4).finished
	
	if card_ui.get_parent():
		card_ui.get_parent().remove_child(card_ui)
	target_parent.add_child(card_ui)
	
	await get_tree().process_frame
	card_ui.update_original_position()

func _on_new_round_requested():
	# Small delay to let the last play settle visually
	await get_tree().create_timer(1.0).timeout
	deal_round()

func _on_deck_reshuffled():
	play_shuffle_next_deal = true

func _on_turn_changed(new_state):
	update_scores()
	if new_state == GameManager.GameState.OPPONENT_TURN:
		run_opponent_ai()

func run_opponent_ai():
	await get_tree().create_timer(1.5).timeout
	if opponent_hand_container.get_child_count() > 0:
		var card_ui = opponent_hand_container.get_child(0) as CardUI
		play_card_to_table(card_ui, false)

func play_card_to_table(card_ui: CardUI, is_player: bool):
	_play_sfx(sfx_card_play)
	card_ui.get_parent().remove_child(card_ui)
	add_child(card_ui) # Temporary parent for animation
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_ui, "global_position", table_grid.global_position, 0.4)
	tween.tween_property(card_ui, "rotation", randf_range(-0.1, 0.1), 0.4)
	
	if not card_ui.is_face_up:
		card_ui.is_face_up = true # Flip on play
	
	await tween.finished
	remove_child(card_ui)

	# Update logic first so we know if it was captured
	GameManager.play_card_to_table(card_ui.card_data, is_player)
	
	# Now check if it stayed on table or was a Caida/Capture
	if card_ui.card_data in GameManager.cards_on_table:
		table_grid.add_child(card_ui)
		await get_tree().process_frame # Wait for container layout
		card_ui.update_original_position()
		var offset = table_grid.get_child_count() * 0.5
		card_ui.start_wave_animation(offset)
	else:
		# It was captured or it's a Caida
		card_ui.queue_free()
	
	# Refresh rest of table UI
	for table_card in table_grid.get_children():
		if table_card is CardUI and table_card.card_data not in GameManager.cards_on_table:
			table_card.queue_free()
	
	update_scores()

func _play_sfx(player: AudioStreamPlayer):
	if not player:
		return
	player.stop()
	player.play()

func _wait_for_sfx(player: AudioStreamPlayer):
	if not player or not player.stream:
		return
	var length = player.stream.get_length()
	if length <= 0.0:
		return
	await get_tree().create_timer(length).timeout

func _get_sfx_length(player: AudioStreamPlayer) -> float:
	if not player or not player.stream:
		return 0.0
	return player.stream.get_length()
