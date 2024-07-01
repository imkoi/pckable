extends Node


var _main_scene: PackedScene


func _ready() -> void:
	if not await Pckable.load_catalog("default"):
		push_error("failed to load default catalog")
		return
	
	if not await Pckable.load_catalog("new_catalog"):
		push_error("failed to load default catalog")
		return
	
	_main_scene = load("res://main.tscn") as PackedScene
	
	var tex = load("res://Exotic_cat_transparent.png") as Texture2D
	print(tex)
	
	var main = _main_scene.instantiate()
	
	main.set_texture(tex)
	add_child(main)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
