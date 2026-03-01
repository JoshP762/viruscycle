extends Control

@onready var icon1 = $Key
@onready var icon2 = $Key2

func _process(delta):
	icon1.visible = Global.has_key1
	icon2.visible = Global.has_key2
