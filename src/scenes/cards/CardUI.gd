class_name CardUI
extends PanelContainer

# CardUI.gd
# Procedural visual representation of a card.

@export var card_data: CardData: set = set_card_data

@export var is_face_up: bool = true: set = set_face_up

@onready var top_value_label = %TopValue
@onready var bottom_value_label = %BottomValue
@onready var suit_icon_label = %SuitIcon
@onready var margin_container = $MarginContainer
@onready var sfx_hover = $SfxHover

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
var target_rotation: float = 0.0

var is_waving: bool = false
var wave_offset: float = 0.0
static var last_hover_sfx_ms_global: int = 0

const HOVER_SFX_COOLDOWN_MS = 450

func _ready():
	if card_data:
		update_ui()
	
	original_position = global_position
	
	# Connect signals for interactions
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func _process(_delta):
	if is_dragging:
		var target_pos = get_global_mouse_position() - drag_offset
		global_position = global_position.lerp(target_pos, 0.2)
		
		# Dynamic tilt based on movement velocity
		var velocity = (target_pos - global_position).x
		target_rotation = clamp(velocity * 0.05, -0.2, 0.2)
		rotation = lerp_angle(rotation, target_rotation, 0.1)
	elif is_waving:
		# Synchronized up and down movement with offset
		var time = Time.get_ticks_msec() / 1000.0
		var wave = sin(time * 3.0 + wave_offset) * 4.0 # Speed 3.0, Amplitude 4px
		global_position.y = original_position.y + wave
		rotation = lerp_angle(rotation, 0, 0.1)
	else:
		rotation = lerp_angle(rotation, 0, 0.1)

func set_card_data(value: CardData):
	card_data = value
	if is_inside_tree():
		update_ui()

func set_face_up(value: bool):
	is_face_up = value
	if is_inside_tree():
		update_ui()

func update_ui():
	if not card_data:
		return
	
	margin_container.visible = is_face_up
	
	var stylebox = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if is_face_up:
		stylebox.bg_color = Color.WHITE
	else:
		stylebox.bg_color = Color(0.1, 0.1, 0.3) # Dark blue back
	add_theme_stylebox_override("panel", stylebox)

	if not is_face_up:
		return
	
	var display_val = str(card_data.value)
	if card_data.value == 1: display_val = "A"
	elif card_data.value == 11: display_val = "J"
	elif card_data.value == 12: display_val = "Q"
	elif card_data.value == 13: display_val = "K"
	
	top_value_label.text = display_val
	bottom_value_label.text = display_val
	
	var suit_path = "res://assets/textures/suits/"
	var suit_color = Color.BLACK
	
	match card_data.suit:
		"Spades": suit_path += "spades.svg"
		"Hearts":
			suit_path += "hearts.svg"
			suit_color = Color.RED
		"Diamonds":
			suit_path += "diamonds.svg"
			suit_color = Color.RED
		"Clubs": suit_path += "clubs.svg"
	
	suit_icon_label.texture = load(suit_path)
	suit_icon_label.modulate = suit_color
	
	top_value_label.add_theme_color_override("font_color", suit_color)
	bottom_value_label.add_theme_color_override("font_color", suit_color)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag()
			else:
				stop_drag()

func start_drag():
	# Only allow dragging if the card is in the player's hand container
	var game_board = get_tree().current_scene
	if game_board:
		var hand = game_board.get_node("%HandContainer")
		if get_parent() != hand:
			return

	is_dragging = true
	drag_offset = get_global_mouse_position() - global_position
	z_index = 100 # Ensure it's on top
	scale = Vector2(1.1, 1.1)
	original_position = global_position # Update in case it moved in hand

func stop_drag():
	if not is_dragging:
		return
		
	is_dragging = false
	z_index = 0
	
	# Check if dropped in table area
	var game_board = get_tree().current_scene
	if game_board and game_board.has_method("play_card_to_table") and GameManager.current_state == GameManager.GameState.PLAYER_TURN:
		var table_rect = game_board.get_node("%TableArea").get_global_rect()
		if table_rect.has_point(get_global_mouse_position()):
			game_board.play_card_to_table(self, true)
			return

	# Drop effect: return home or snap (logic for board later)
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", original_position, 0.3)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_property(self, "rotation", 0.0, 0.2)

func _on_mouse_entered():
	if not is_dragging:
		# Only hover if in player's hand
		var game_board = get_tree().current_scene
		if game_board:
			var hand = game_board.get_node("%HandContainer")
			if get_parent() != hand:
				return

		_play_hover_sfx()
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2)
		z_index = 10

func _on_mouse_exited():
	if not is_dragging:
		var game_board = get_tree().current_scene
		if game_board:
			var hand = game_board.get_node("%HandContainer")
			if get_parent() != hand:
				return

		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
		z_index = 0

func update_original_position():
	original_position = global_position

func start_wave_animation(offset: float = 0.0):
	is_waving = true
	wave_offset = offset

func stop_wave_animation():
	is_waving = false

func _play_hover_sfx():
	if not sfx_hover:
		return
	var now_ms = Time.get_ticks_msec()
	if now_ms - last_hover_sfx_ms_global < HOVER_SFX_COOLDOWN_MS:
		return
	last_hover_sfx_ms_global = now_ms
	sfx_hover.stop()
	sfx_hover.play()
