class_name GameBoardAnimator
extends Node

@export var hand_container_path: NodePath
@export var opponent_hand_container_path: NodePath
@export var table_grid_path: NodePath
@export var deck_position_path: NodePath

@onready var hand_container: Control = get_node_or_null(hand_container_path)
@onready var opponent_hand_container: Control = get_node_or_null(opponent_hand_container_path)
@onready var table_grid: Control = get_node_or_null(table_grid_path)
@onready var deck_position: Control = get_node_or_null(deck_position_path)

func spawn_card_to_hand(card_scene: PackedScene, data: CardData, is_player: bool) -> CardUI:
	if not deck_position or not hand_container or not opponent_hand_container:
		return null
	var card_ui = card_scene.instantiate() as CardUI
	card_ui.card_data = data
	card_ui.is_face_up = is_player
	
	var root = get_parent()
	root.add_child(card_ui)
	card_ui.global_position = deck_position.global_position
	
	var target_parent = hand_container if is_player else opponent_hand_container
	var tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	await tween.tween_property(card_ui, "global_position", target_parent.global_position, 0.4).finished
	
	if card_ui.get_parent():
		card_ui.get_parent().remove_child(card_ui)
	target_parent.add_child(card_ui)
	
	await get_tree().process_frame
	card_ui.update_original_position()
	
	return card_ui

func animate_card_to_table(card_ui: CardUI):
	if not table_grid:
		return
	var root = get_parent()
	card_ui.get_parent().remove_child(card_ui)
	root.add_child(card_ui) # Temporary parent for animation
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_ui, "global_position", table_grid.global_position, 0.4)
	tween.tween_property(card_ui, "rotation", randf_range(-0.1, 0.1), 0.4)
	
	if not card_ui.is_face_up:
		card_ui.is_face_up = true # Flip on play
	
	await tween.finished
	root.remove_child(card_ui)

func place_card_on_table(card_ui: CardUI):
	if not table_grid:
		return
	table_grid.add_child(card_ui)
	await get_tree().process_frame # Wait for container layout
	card_ui.update_original_position()
	var offset = table_grid.get_child_count() * 0.5
	card_ui.start_wave_animation(offset)
