extends Control

# GameBoard.gd
# Main arena for "Fourty Last Bet".

const CARD_UI_SCENE = preload("res://src/scenes/cards/CardUI.tscn")

@onready var hand_container = %HandContainer
@onready var opponent_hand_container = %OpponentHandContainer
@onready var table_grid = %TableGrid
@onready var deck_position = %DeckPosition
@onready var player_score_label = %PlayerScore
@onready var opponent_score_label = %OpponentScore
@onready var message_container = %MessageContainer

func _ready():
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.new_round_requested.connect(_on_new_round_requested)
	GameManager.game_event_occurred.connect(_on_game_event_occurred)
	GameManager.game_over.connect(_on_game_over)
	# Wait a frame for layout to settle
	await get_tree().process_frame
	start_game()

func start_game():
	GameManager.load_deck()
	GameManager.shuffle_deck()
	update_scores()
	deal_round()

func _on_game_event_occurred(type: String, team: String, points: int):
	var color = Color.WHITE
	var text = type
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
	
	var label_text = "[%s] %s" % [team, text]
	show_event_notification(label_text, color)

func _on_game_over(winner_team: String, score_p: int, score_o: int):
	var msg = "VICTORY! %s WINS (%d - %d)" % [winner_team, score_p, score_o]
	var color = Color.GOLD if winner_team == "PLAYER" else Color.TOMATO
	
	# Show a special permanent notification
	var label = Label.new()
	label.text = msg
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 72)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	
	label.anchors_preset = Control.PRESET_CENTER
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	message_container.add_child(label)
	await get_tree().process_frame
	label.pivot_offset = label.size / 2
	
	label.scale = Vector2.ZERO
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 1.0)

func show_event_notification(text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	
	# Centering logic
	label.anchors_preset = Control.PRESET_CENTER
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	message_container.add_child(label)
	
	# Wait for a frame to get correct size for pivot
	await get_tree().process_frame
	label.pivot_offset = label.size / 2
	
	# Offset based on existing messages to prevent overlap
	var active_messages = message_container.get_child_count() - 1
	var vertical_offset = active_messages * 60
	label.position.y += vertical_offset
	
	# Initial state
	label.scale = Vector2.ZERO
	label.modulate.a = 0
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.4)
	tween.tween_property(label, "modulate:a", 1.0, 0.2)
	tween.tween_property(label, "position:y", label.position.y - 120, 1.5).set_trans(Tween.TRANS_SINE)
	
	# Fade out and kill
	var fade_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fade_tween.tween_interval(1.0)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.5)
	fade_tween.tween_callback(label.queue_free)

func update_scores():
	player_score_label.text = "Player: " + str(GameManager.player_score)
	opponent_score_label.text = "Opponent: " + str(GameManager.opponent_score)

func deal_round():
	var p_cards = GameManager.deal_cards(5)
	var o_cards = GameManager.deal_cards(5)
	
	GameManager.player_hand.append_array(p_cards)
	GameManager.opponent_hand.append_array(o_cards)
	
	for i in range(5):
		spawn_card_to_hand(p_cards[i], true)
		await get_tree().create_timer(0.1).timeout
		spawn_card_to_hand(o_cards[i], false)
		await get_tree().create_timer(0.1).timeout
	
	# Check for Ronda bonus points
	GameManager.check_for_ronda(true)
	GameManager.check_for_ronda(false)
	update_scores()

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
		card_ui.update_original_position()
	else:
		# It was captured or it's a Caida
		card_ui.queue_free()
	
	# Refresh rest of table UI
	for table_card in table_grid.get_children():
		if table_card is CardUI and table_card.card_data not in GameManager.cards_on_table:
			table_card.queue_free()
	
	update_scores()
