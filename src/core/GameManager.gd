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
	# Reset Caida state on new deal
	last_card_played = null
	
	var dealt: Array[CardData] = []
	for i in range(amount):
		if deck.size() > 0:
			dealt.append(deck.pop_back())
	return dealt

signal capture_choice_requested(options: Array)

var pending_card_played: CardData = null
var pending_from_player: bool = false

func play_card_to_table(card: CardData, from_player: bool):
	if is_game_over: return
	
	# Temporarily remove from hand (visual only, logic finalized on resolve)
	if from_player:
		player_hand.erase(card)
	else:
		opponent_hand.erase(card)
		
	# Identify all possible captures
	var options = find_all_captures(card, cards_on_table)
	
	if options.is_empty():
		# No capture, simple play
		cards_on_table.append(card)
		last_card_played = card
		check_caida_on_play(card, from_player, false) # Checks if this PLAY was a Caida (unlikely if empty options, but technically if Match existed we'd have an option. Caida logic is usually tied to capture.)
		# Actually in Cuarenta, Caida IS a capture. So if options empty, no Caida.
		finalize_turn(from_player)
		
	elif options.size() == 1:
		# Single option, execute immediately
		execute_capture(card, options[0], from_player)
		
	else:
		# Multiple options, ask for choice
		pending_card_played = card
		pending_from_player = from_player
		
		# If AI, choose random
		if not from_player:
			var choice = options.pick_random()
			execute_capture(card, choice, from_player)
		else:
			print("Ambiguous capture! Requesting user choice...")
			current_state = GameState.WAITING
			turn_changed.emit(current_state) # Lock input
			capture_choice_requested.emit(options)

func execute_capture(card: CardData, captured_cards: Array, from_player: bool):
	var is_caida = false
	
	# Check Caida: captured 1 card, matching value, and it was the last played
	# We check value equality and ensure last_card_played is valid.
	if captured_cards.size() == 1 and last_card_played != null and card.value == last_card_played.value and captured_cards[0].value == last_card_played.value:
		is_caida = true
		if from_player:
			player_score += 2
			game_event_occurred.emit("CAIDA", "PLAYER", 2)
		else:
			opponent_score += 2
			game_event_occurred.emit("CAIDA", "OPPONENT", 2)
		
		if check_for_winner(): return
	
	# Process capture
	last_capture_player = from_player
	for c in captured_cards:
		cards_on_table.erase(c)
		if from_player:
			player_captured.append(c)
		else:
			opponent_captured.append(c)
	
	# The played card is also captured
	if from_player:
		player_captured.append(card)
	else:
		opponent_captured.append(card)
		
	# Sequence Logic (Stair/Escalera)
	# After the primary capture, check for sequential cards (J, Q, K...) remaining
	# The sequence starts from the card VALUE
	var next_val = get_next_in_sequence(card.value)
	while next_val != -1:
		var found_sequence_card = null
		for table_card in cards_on_table:
			if table_card.value == next_val:
				found_sequence_card = table_card
				break
		
		if found_sequence_card:
			cards_on_table.erase(found_sequence_card)
			if from_player:
				player_captured.append(found_sequence_card)
			else:
				opponent_captured.append(found_sequence_card)
			# print("Sequence capture: ", found_sequence_card.value)
			next_val = get_next_in_sequence(next_val)
		else:
			break
			
	# Limpia Check (Performed AFTER sequence logic to ensure table is truly empty)
	if cards_on_table.is_empty():
		# Rule: No Limpia on the very last play of the entire deck (standard Cuarenta rule, optional but good to have)
		# For now, we'll keep it simple: if table empty, Limpia.
		# Note: If deck is empty and hands are empty, it's the last play. 
		# We can check deck.size() == 0 and hands size == 0 before this? 
		# Actually, this method runs before finalize_turn, so card is already out of hand.
		# If deck is empty and (player_hand + opponent_hand) is empty... 
		# But let's just stick to "Empty Table = Limpia" for now unless user asked for the exception.
		if from_player:
			player_score += 2
			game_event_occurred.emit("LIMPIA", "PLAYER", 2)
		else:
			opponent_score += 2
			game_event_occurred.emit("LIMPIA", "OPPONENT", 2)
		
		if check_for_winner(): return
	else:
		if not is_caida:
			var team = "PLAYER" if from_player else "OPPONENT"
			game_event_occurred.emit("CAPTURE", team, 0)
			
	last_card_played = null # Reset Caida buffer after any capture
	check_for_winner() # Check again
	finalize_turn(from_player)

func finalize_turn(from_player: bool):
	if from_player:
		change_turn(GameState.OPPONENT_TURN)
	else:
		change_turn(GameState.PLAYER_TURN)
	
	if player_hand.is_empty() and opponent_hand.is_empty():
		if not deck.is_empty():
			new_round_requested.emit()
		else:
			calculate_round_end_points()

func check_caida_on_play(card, from_player, is_capture):
	pass # Helper placeholder if needed

# --- Helper Methods for Cuarenta Rules ---

# This function finds all possible sets of cards that can be captured by the played card.
# It returns an Array of Arrays (each inner array is a valid capture option).
func find_all_captures(played_card: CardData, table_cards: Array[CardData]) -> Array:
	var options: Array = []
	
	# Option 1: Direct match (Caida or regular match)
	for c in table_cards:
		if c.value == played_card.value:
			options.append([c])
	
	# Option 2: Sum match (only if played_card is not a face card)
	if played_card.value <= 7: # Face cards (J, Q, K) cannot capture by Sum
		var sum_matches = _find_all_subset_sums_recursive(played_card.value, table_cards, 0, [])
		for match_set in sum_matches:
			if match_set.size() > 1:
				options.append(match_set)
	
	# Remove duplicates
	var unique_options: Array = []
	for opt in options:
		var is_unique = true
		for existing_opt in unique_options:
			if opt.size() == existing_opt.size():
				var all_match = true
				for card in opt:
					if not existing_opt.has(card):
						all_match = false
						break
				if all_match:
					is_unique = false
					break
		if is_unique:
			unique_options.append(opt)
			
	return unique_options

# Helper for find_all_captures to get all subset sums
func _find_all_subset_sums_recursive(target: int, cards: Array[CardData], index: int, current_subset: Array[CardData]) -> Array:
	var results: Array = []
	var current_sum = 0
	for c in current_subset:
		current_sum += c.value

	if current_sum == target:
		results.append(current_subset.duplicate())
		# Continue to find other combinations
	
	if index >= cards.size():
		return results

	# Try including cards[index]
	var next_subset_with = current_subset.duplicate()
	next_subset_with.append(cards[index])
	if current_sum + cards[index].value <= target:
		results.append_array(_find_all_subset_sums_recursive(target, cards, index + 1, next_subset_with))
	
	# Try excluding cards[index]
	results.append_array(_find_all_subset_sums_recursive(target, cards, index + 1, current_subset))
	
	return results

func resolve_pending_capture(option_index: int):
	if not pending_card_played:
		return
		
	# Re-calculate options to be safe (or we could cache them, but this is safer against state drift)
	# Though waiting state means state shouldn't drift.
	var options = find_all_captures(pending_card_played, cards_on_table)
	
	if option_index >= 0 and option_index < options.size():
		execute_capture(pending_card_played, options[option_index], pending_from_player)
	else:
		print("Invalid capture choice index!")
		# Fallback?
		if options.size() > 0:
			execute_capture(pending_card_played, options[0], pending_from_player)
			
	pending_card_played = null

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
	
	# Rule change: Face cards (J, Q, K) cannot capture by Sum, only by match.
	# If we didn't find a match above, and value is > 7, return empty.
	if target > 7:
		return []
			
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
