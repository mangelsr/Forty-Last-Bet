extends Node

# GameManager.gd
enum GameState {PLAYER_TURN, OPPONENT_TURN, WAITING}

const WIN_SCORE = 40

var current_state: GameState = GameState.PLAYER_TURN

var player_score: int = 0
var opponent_score: int = 0
var last_capture_player: bool = true # Default to player for first card
var is_game_over: bool = false
var current_run_seed: String = ""

var deck: Array[CardData] = []
var player_hand: Array[CardData] = []
var opponent_hand: Array[CardData] = []
var cards_on_table: Array[CardData] = []
var player_captured: Array[CardData] = []
var opponent_captured: Array[CardData] = []
var last_card_played: CardData = null

signal turn_changed(new_state: GameState)
signal new_round_requested
signal game_event_occurred(type: String, team: String, points: int)
signal game_over(winner_team: String, final_score_p: int, final_score_o: int)

func _ready():
	load_deck()
	shuffle_deck()
	print("GameManager initialized with ", deck.size(), " cards.")

func load_deck():
	deck.clear()
	var path = "res://data/cards/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var card = load(path + file_name) as CardData
				if card:
					deck.append(card)
			file_name = dir.get_next()
	else:
		push_error("Failed to open cards directory")

func shuffle_deck():
	deck.shuffle()

func deal_cards(amount: int) -> Array[CardData]:
	var dealt: Array[CardData] = []
	for i in range(amount):
		if deck.size() > 0:
			dealt.append(deck.pop_back())
	return dealt

func play_card_to_table(card: CardData, from_player: bool):
	if is_game_over: return
	
	if from_player:
		player_hand.erase(card)
	else:
		opponent_hand.erase(card)
	
	var captured_cards: Array[CardData] = []
	var is_caida = false
	
	# 1. Check for Caida (match the last card played)
	if last_card_played and last_card_played.value == card.value:
		is_caida = true
		captured_cards.append(last_card_played)
		if from_player:
			player_score += 2
			game_event_occurred.emit("CAIDA", "PLAYER", 2)
			print("CAIDA! Player +2")
		else:
			opponent_score += 2
			game_event_occurred.emit("CAIDA", "OPPONENT", 2)
			print("CAIDA! Opponent +2")
		
		is_caida = true
		if check_for_winner(): return
	if not is_caida:
		var sum_match = find_subset_sum(card.value, cards_on_table)
		if not sum_match.is_empty():
			captured_cards.append_array(sum_match)
	
	# 3. Handle sequences after initial capture
	if not captured_cards.is_empty():
		# The "base" value for the sequence is the value of the card played
		var next_val = get_next_in_sequence(card.value)
		while next_val != -1:
			var found_sequence_card = null
			for table_card in cards_on_table:
				if table_card.value == next_val and table_card not in captured_cards:
					found_sequence_card = table_card
					break
			
			if found_sequence_card:
				captured_cards.append(found_sequence_card)
				next_val = get_next_in_sequence(next_val)
			else:
				break
	
	# 4. Finalize captures
	if captured_cards.size() > 0:
		last_capture_player = from_player
		for c in captured_cards:
			cards_on_table.erase(c)
			if from_player:
				player_captured.append(c)
			else:
				opponent_captured.append(c)
		
		# Also the card played is "taken" if it captured anything
		if from_player:
			player_captured.append(card)
		else:
			opponent_captured.append(card)
		
		# Check for Limpia
		if cards_on_table.is_empty():
			if from_player:
				player_score += 2
				game_event_occurred.emit("LIMPIA", "PLAYER", 2)
				print("LIMPIA! Player +2")
			else:
				opponent_score += 2
				game_event_occurred.emit("LIMPIA", "OPPONENT", 2)
				print("LIMPIA! Opponent +2")
		else:
			# Just a standard capture
			var team = "PLAYER" if from_player else "OPPONENT"
			game_event_occurred.emit("CAPTURE", team, 0)
		
		last_capture_player = from_player
		if check_for_winner(): return
		
		last_card_played = null # Reset Caida buffer
	else:
		# No capture, stays on table
		cards_on_table.append(card)
		last_card_played = card
	
	if from_player:
		change_turn(GameState.OPPONENT_TURN)
	else:
		change_turn(GameState.PLAYER_TURN)
		
	# Check if round finished (both hands empty)
	if player_hand.is_empty() and opponent_hand.is_empty():
		if not deck.is_empty():
			print("Hands empty. Requesting new round deal...")
			new_round_requested.emit()
		else:
			print("Deck empty! Calculating final points...")
			calculate_round_end_points()

# --- Helper Methods for Cuarenta Rules ---

func get_next_in_sequence(val: int) -> int:
	if val >= 1 and val <= 6: return val + 1
	if val == 7: return 11 # J follows 7
	if val == 11: return 12 # Q follows J
	if val == 12: return 13 # K follows Q
	return -1 # End of sequence

func find_subset_sum(target: int, available_cards: Array[CardData]) -> Array[CardData]:
	# Prioritize single card match if exists
	for c in available_cards:
		if c.value == target:
			var result: Array[CardData] = [c]
			return result
			
	# Recursive search for combination
	var initial_array: Array[CardData] = []
	return _find_subset_recursive(target, available_cards, 0, initial_array)

func _find_subset_recursive(target: int, cards: Array[CardData], index: int, current: Array[CardData]) -> Array[CardData]:
	if target == 0: return current
	if index >= cards.size() or target < 0: return []
	
	# Try including cards[index]
	var next_current = current.duplicate()
	next_current.append(cards[index])
	var with_this = _find_subset_recursive(target - cards[index].value, cards, index + 1, next_current)
	if not with_this.is_empty(): return with_this
	
	# Try excluding cards[index]
	return _find_subset_recursive(target, cards, index + 1, current)

# --- Scoring logic ---

func calculate_round_end_points():
	# Give leftovers to last capturer
	if not cards_on_table.is_empty():
		print("Giving ", cards_on_table.size(), " leftover cards to ", "Player" if last_capture_player else "Opponent")
		if last_capture_player:
			player_captured.append_array(cards_on_table)
		else:
			opponent_captured.append_array(cards_on_table)
		cards_on_table.clear()
	
	var p_count = player_captured.size()
	var o_count = opponent_captured.size()
	
	print("Final Count - Player: ", p_count, " Opponent: ", o_count)
	
	if p_count > 19:
		var cartón_points = 6 + (p_count - 20)
		if cartón_points % 2 != 0:
			cartón_points += 1 # Standard Cuarenta rule: round up to even
		player_score += cartón_points
		print("Player gets ", cartón_points, " points from cards.")
		
	if o_count > 19:
		var cartón_points = 6 + (o_count - 20)
		if cartón_points % 2 != 0:
			cartón_points += 1
		opponent_score += cartón_points
		print("Opponent gets ", cartón_points, " points from cards.")
	
	# Check for Winner
	if check_for_winner():
		return
		
	# Restart another round
	reshuffle_all_cards()
	new_round_requested.emit()
		
	# Update UI
	turn_changed.emit(current_state)

func check_for_winner() -> bool:
	if is_game_over: return true
	
	if player_score >= WIN_SCORE:
		is_game_over = true
		print("PLAYER WINS THE GAME!")
		game_over.emit("PLAYER", player_score, opponent_score)
		current_state = GameState.WAITING
		return true
	elif opponent_score >= WIN_SCORE:
		is_game_over = true
		print("OPPONENT WINS THE GAME!")
		game_over.emit("OPPONENT", player_score, opponent_score)
		current_state = GameState.WAITING
		return true
	return false

func reshuffle_all_cards():
	print("Reshuffling captured cards for new deck...")
	deck.clear()
	deck.append_array(player_captured)
	deck.append_array(opponent_captured)
	
	player_captured.clear()
	opponent_captured.clear()
	# cards_on_table should already be clear from the leftover assignment
	
	deck.shuffle()
	last_card_played = null

func check_for_ronda(is_player: bool):
	var hand = player_hand if is_player else opponent_hand
	var counts = {}
	for card in hand:
		counts[card.value] = counts.get(card.value, 0) + 1
	
	for val in counts:
		if counts[val] == 3:
			if is_player:
				player_score += 2
				game_event_occurred.emit("RONDA", "PLAYER", 2)
				print("RONDA! Player +2")
			else:
				opponent_score += 2
				game_event_occurred.emit("RONDA", "OPPONENT", 2)
				print("RONDA! Opponent +2")
		elif counts[val] == 4:
			if is_player:
				player_score += 4
				game_event_occurred.emit("DOBLE RONDA", "PLAYER", 4)
				print("DOBLE RONDA! Player +4")
			else:
				opponent_score += 4
				game_event_occurred.emit("DOBLE RONDA", "OPPONENT", 4)
				print("DOBLE RONDA! Opponent +4")
	
	# Update UI
	turn_changed.emit(current_state)
	check_for_winner()

func change_turn(new_state: GameState):
	current_state = new_state
	turn_changed.emit(current_state)
