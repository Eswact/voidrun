extends Node2D

const _TEX := preload("res://assets/sprites/mobile_ui/warning.png")

func _ready() -> void:
	z_index = 20
	var spr := Sprite2D.new()
	spr.texture = _TEX
	spr.scale   = Vector2(0.07, 0.07)
	add_child(spr)
	var tween := create_tween().set_loops()
	tween.tween_property(spr, "scale", Vector2(0.09, 0.09), 0.18)
	tween.tween_property(spr, "scale", Vector2(0.07, 0.07), 0.18)
