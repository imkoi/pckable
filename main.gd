extends Node


func _ready() -> void:
	pass


func set_texture(tex: Texture2D):
	var sprite = get_node("Field/MiddlePart/Cell/FrontContainer/Sprite2D")
	sprite.set_texture(tex)
