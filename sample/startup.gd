extends Node


#var _main_scene = PackedScene
#var _cat_texture = Texture2D


func _ready() -> void:
	#_main_scene = await Pckable.load_resource("main_scene")
	#_main_scene = await Pckable.load_resource("my_cat")
	
	#var bundle = await Pckable.load_resources(["main_scene", "my_cat"])
	#var main_node = bundle.main_scene.instantiate()
	#
	#main_node.set_texture(bundle.my_cat)
	#add_child(main_node)
	#
	
	var max_retries_count := 3
	var retry_delay := 4.0
	
	var retries := max_retries_count + 1
	
	while retries > 0:
		var request_index := max_retries_count - retries
		
		retries -= 1
		
		if request_index < 0:
			continue
		
		var temp := retry_delay * 2.0 ** request_index
		var delay:= temp / 2.0 + randf_range(0.0, temp / 2)
		
		print(delay)


func api_usage() -> void:
	# add additional manifest, it will be merged and store in user:// path
	Pckable.load_manifest("manifest_downloaded_from_backend.json")
	
	# load catalog for resource, load resources on backround threads
	var cat_scene = await Pckable.load_resource("my_cat_scene_key", 1000)
	var _cat = cat_scene.instantiate()
	
	# load catalogs for resources, load resources on backround threads simultaniously
	var multiple_scenes = await Pckable.load_resources(
		["shiny_cat_key", "awesome_cat_key"], 1000)
	
	# Pckable.load_resources return dictionary with keys and resources
	if multiple_scenes.has("shiny_cat_key"):
		var scene = multiple_scenes["shiny_cat_key"]
		var cat = scene.instantiate()
		
		add_child(cat)
	
	if multiple_scenes.has("awesome_cat_key"):
		var scene = multiple_scenes["awesome_cat_key"]
		var cat = scene.instantiate()
		
		add_child(cat)
