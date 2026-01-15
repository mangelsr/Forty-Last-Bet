class_name GameBoardUI
extends Node

@export var message_container_path: NodePath
@export var player_score_label_path: NodePath
@export var opponent_score_label_path: NodePath
@export var player_captured_label_path: NodePath
@export var opponent_captured_label_path: NodePath

@onready var message_container: Control = get_node_or_null(message_container_path)
@onready var player_score_label: Label = get_node_or_null(player_score_label_path)
@onready var opponent_score_label: Label = get_node_or_null(opponent_score_label_path)
@onready var player_captured_label: Label = get_node_or_null(player_captured_label_path)
@onready var opponent_captured_label: Label = get_node_or_null(opponent_captured_label_path)

func update_scores():
	if not player_score_label or not opponent_score_label:
		return
	if not player_captured_label or not opponent_captured_label:
		return
	player_score_label.text = tr("GAME_PLAYER") + ": " + str(GameManager.player_score)
	opponent_score_label.text = tr("GAME_OPPONENT") + ": " + str(GameManager.opponent_score)
	
	player_captured_label.text = tr("GAME_MY_CARDS") + ": " + str(GameManager.player_captured.size())
	opponent_captured_label.text = tr("GAME_OPP_CARDS") + ": " + str(GameManager.opponent_captured.size())

func show_event_notification(text: String, color: Color):
	if not message_container:
		return
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
	await message_container.get_tree().process_frame
	
	# Center label in slot
	label.position = (slot.size - label.size) / 2
	label.pivot_offset = label.size / 2
	
	# Initial Animation State
	label.modulate.a = 0
	label.scale = Vector2(0.5, 0.5)
	
	# Animate
	var tween = message_container.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.4)
	tween.tween_property(label, "modulate:a", 1.0, 0.2)
	# Float up relative to the slot
	tween.tween_property(label, "position:y", label.position.y - 120, 1.5).set_trans(Tween.TRANS_SINE)
	
	# Fade out and cleanup
	var fade_tween = message_container.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fade_tween.tween_interval(1.5)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.5)
	# Remove the slot (parent), which removes the label too
	fade_tween.tween_callback(slot.queue_free)

func build_event_text(type: String, team: String, points: int) -> String:
	# Map type to translation key (e.g. CAIDA -> EVENT_CAIDA, DOBLE RONDA -> EVENT_DOBLE_RONDA)
	var tr_key = "EVENT_" + type.replace(" ", "_")
	var text = tr(tr_key)
	
	if points > 0:
		text += "! +" + str(points)
	else:
		text += "!"
	
	# Translate team name using existing keys GAME_PLAYER / GAME_OPPONENT
	var team_key = "GAME_" + team
	var team_text = tr(team_key)
	
	return "[%s] %s" % [team_text, text]

func event_color(type: String) -> Color:
	match type:
		"CAIDA":
			return Color.YELLOW
		"LIMPIA":
			return Color.CYAN
		"RONDA", "DOBLE RONDA":
			return Color.MAGENTA
		"CAPTURE":
			return Color.GREEN_YELLOW
		"CARTON":
			return Color.SKY_BLUE
		_:
			return Color.WHITE
