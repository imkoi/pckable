extends Node


var _main_scene: PackedScene


func _ready() -> void:
	# add additional manifest, it will be merged and store in user:// path
	Pckable.load_manifest("manifest_downloaded_from_backend.json")
	
	# load catalog for resource, load resources on backround threads
	var cat_scene = await Pckable.load_resource("my_cat_scene_key", 1000)
	var _cat = cat_scene.instantiate()
	
	# load catalogs for resources, load resources on backround threads simultaniously
	var multiple_scenes = await Pckable.load_resources(
		["shiny_cat_key", "awesome_cat_key"], 1000)
	
	if multiple_scenes.has("shiny_cat_key"):
		var scene = multiple_scenes["shiny_cat_key"]
		var cat = scene.instantiate()
		
		add_child(cat)
	
	if multiple_scenes.has("awesome_cat_key"):
		var scene = multiple_scenes["awesome_cat_key"]
		var cat = scene.instantiate()
		
		add_child(cat)
	
	var _cat_scene := await Pckable.load_resource("my_cat_scene_key", 1000)
	
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
