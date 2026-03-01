extends Node3D

@export var ambient_music: AudioStreamPlayer
@export var encounter_music: AudioStreamPlayer

var _in_combat: bool = false


func _ready() -> void:
	add_to_group("music_manager")
	print("ambient_music: ", ambient_music)
	print("encounter_music: ", encounter_music)
	
	if not is_instance_valid(ambient_music) or not is_instance_valid(encounter_music):
		push_error("MusicManager: music nodes not set in Inspector")
		return


func enter_combat() -> void:
	if _in_combat:
		return
	_in_combat = true
	_crossfade(ambient_music, encounter_music)


func _check_combat_state() -> void:
	var enemies_alive := get_tree().get_nodes_in_group("enemy").size()
	if enemies_alive == 0 and _in_combat:
		_in_combat = false
		_crossfade(encounter_music, ambient_music)


func _crossfade(from: Node, to: Node) -> void:
	to.volume_db = -40.0
	to.play()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(from, "volume_db", -40.0, 1.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(to, "volume_db", 0.0, 1.5).set_trans(Tween.TRANS_SINE)
	await tween.finished
	from.stop()
