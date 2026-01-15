class_name GameBoardAudio
extends Node

func play_sfx(player: AudioStreamPlayer):
	if not player:
		return
	player.stop()
	player.play()

func wait_for_sfx(player: AudioStreamPlayer):
	if not player or not player.stream:
		return
	var length = player.stream.get_length()
	if length <= 0.0:
		return
	await get_tree().create_timer(length).timeout

func get_sfx_length(player: AudioStreamPlayer) -> float:
	if not player or not player.stream:
		return 0.0
	return player.stream.get_length()
