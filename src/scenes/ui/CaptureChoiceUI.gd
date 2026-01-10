class_name CaptureChoiceUI
extends PanelContainer

signal option_selected(index: int)

@onready var container = %OptionsContainer

func setup(options: Array):
	# Clear existing children if any (though usually this is a fresh instance)
	for child in container.get_children():
		child.queue_free()
		
	for i in range(options.size()):
		var opt = options[i]
		var btn_text = tr("CAPTURE_PREFIX") + ": "
		for c in opt:
			var val_str = str(c.value)
			if c.value == 1: val_str = "A"
			elif c.value == 11: val_str = "J"
			elif c.value == 12: val_str = "Q"
			elif c.value == 13: val_str = "K"
			btn_text += "[%s%s] " % [val_str, c.suit.left(1)]
			
		var btn = Button.new()
		btn.text = btn_text
		btn.custom_minimum_size = Vector2(200, 50)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(func():
			_on_option_pressed(i)
		)
		container.add_child(btn)
		
	# Prepare for animation
	scale = Vector2.ZERO
	
	# Wait for layout to calculate valid size
	await get_tree().process_frame
	pivot_offset = size / 2
	
	# Animate in
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.4)

func _on_option_pressed(index: int):
	option_selected.emit(index)
	
	# Animate out
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
	tween.tween_callback(queue_free)
