class_name BaseHazard extends Node2D

signal hazard_hit_player

var active: bool = false


func activate(params: Dictionary) -> void:
	active = true
	show()


func deactivate() -> void:
	active = false
	hide()


func update_params(params: Dictionary) -> void:
	pass
