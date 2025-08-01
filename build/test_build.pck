GDPC                �                                                                         T   res://.godot/exported/133200997/export-387dc8e492395271b5fee27bd3d5dd24-startup.scn �*      r      Le�R��:
�fl�-    ,   res://.godot/global_script_class_cache.cfg  �2      
      h`�py��=�\?g<       res://.godot/uid_cache.bin  �@      �      7���&�T�q�x    (   res://addons/pckable/runtime/pckable.gd         �      �Ac�l~QD��J@b    4   res://addons/pckable/runtime/pckable_path_utility.gd�      �      �y�;��$L�7�/    4   res://addons/pckable/runtime/pckable_storage_base.gd�      o      ې�=�"�����ǻ�    8   res://addons/pckable/runtime/pckable_storage_runtime.gd  %      :      �"u�D�h8���G�F�    0   res://addons/pckable/runtime/pckable_timer.gd   @'      ]      �~�͉��G�;aJ�       res://icon.svg  �<      �      k����X3Y���f       res://pckable_manifest.json �)            Q�:���fۆ� ��;       res://project.binary0C      �      ��\A/�y�m���,       res://sample/startup.gd @-      �      �3Q�f�� n��LE��        res://sample/startup.tscn.remap @2      d       d����ʫ�g����N            extends Node


const EMPTY_STATUS := 0
const LOADING_STATUS := 1
const LOADED_STATUS := 2
const RESPONSE_BODY_KEY := "body"

var _storage: PckableStorageRuntime
var _catalog_loading := Dictionary()
var _scene_tree: SceneTree
var _initializd: bool

var _http_requests_pool := Dictionary() # http_request to is_free
var max_http_requests_pool := 4
var http_timout := 10.0
var max_retries_count := 3
var retry_delay := 5.0


func _exit_tree() -> void:
	if _storage:
		_storage.free()


func load_manifest(manifest_json: StringName) -> bool:
	var json := JSON.new()
	var error := json.parse(manifest_json)
	
	if error != OK:
		push_error(error)
		
		return false
	
	var catalogs := json.data as Array
	
	return _storage.add_manifest(catalogs)


func load_resource(key: String,
 timeout_msec: int = 60000, use_cached: bool = true) -> Resource:
	_try_init()
	
	var bundle := await load_resources([key], timeout_msec, use_cached)
	
	if bundle.has(key):
		return bundle[key]
	
	return null


func load_resources(keys: PackedStringArray,
 timeout_msec: int = 60000, use_cached: bool = true) -> Dictionary:
	_try_init()
	
	var bundle := Dictionary()
	var timer := PckableTimer.create(timeout_msec)
	var catalog_names := PackedStringArray()
	var resources := PackedStringArray()
	
	resources.resize(keys.size())
	
	for i in keys.size():
		resources[i] = _storage.get_path_by_key(keys[i])
		var catalog_name := _storage.get_catalog_name_by_path(resources[i])
		
		if not catalog_names.has(catalog_name):
			catalog_names.push_back(catalog_name)
	
	for catalog_name in catalog_names:
		await _load_catalog(catalog_name, timer, use_cached)
		
		if timer.is_expired():
			return bundle
	
	return await _load_resources_internal(keys, resources, timer)


func _load_catalog(catalog_name: StringName, timer: PckableTimer, use_cached) -> bool:
	if _catalog_loading.has(catalog_name):
		while _catalog_loading[catalog_name] == LOADING_STATUS:
			await _scene_tree.process_frame
		
		if use_cached:
			if _catalog_loading[catalog_name] == LOADED_STATUS:
				return true
	
	_catalog_loading[catalog_name] = LOADING_STATUS
	
	if catalog_name.is_empty():
		_catalog_loading[catalog_name] = EMPTY_STATUS
		
		push_error("catalog name could not be empty")
		return false
	
	var catalog_address := _storage.get_catalog_address(catalog_name)
	
	if catalog_address.length() > 0 and catalog_address != "local":
		print("start downloading %s" % catalog_name)
		var url := catalog_address + "/" + catalog_name + ".pck"
		var pck_data := await _download_pck_data(url, timer)
		
		if timer.is_expired():
			_catalog_loading[catalog_name] = EMPTY_STATUS
			
			push_error("free request was not found in time")
			return false
		
		if pck_data.size() == 0:
			_catalog_loading[catalog_name] = EMPTY_STATUS
			
			push_error("downloaded empty catalog")
			return false
		
		var file_path := PckablePathUtility.get_executable_dir()
		file_path += catalog_name + ".pck"
		
		var file := FileAccess.open(file_path, FileAccess.WRITE_READ)
		
		file.store_buffer(pck_data)
	
	var pck_path := "user://%s.pck" % catalog_name
	var success := ProjectSettings.load_resource_pack(pck_path)
	
	if success:
		_catalog_loading[catalog_name] = LOADED_STATUS
	else:
		_catalog_loading[catalog_name] = EMPTY_STATUS
	
	return success


func _download_pck_data(url: String, timer: PckableTimer) -> PackedByteArray:
	var request_node := await _pull_http_request_node(timer)
	
	if not request_node:
		return PackedByteArray()
	
	var payload := Dictionary()
	var callback := _on_request_completed.bind(payload)
	var retries := max_retries_count + 1
	
	request_node.request_completed.connect(callback)
	
	while retries > 0 and not timer.is_expired():
		var request_index := max_retries_count - retries
		var delay := 0.0
		
		if request_index >= 0:
			var temp := retry_delay * 2.0 ** request_index
			delay = temp / 2.0 + randf_range(0.0, temp / 2)
		
		if delay > 0:
			await _scene_tree.create_timer(delay).timeout
		
		request_node.timeout = min(timer.get_time_left_sec(), http_timout)
		request_node.request(url)
		
		while not timer.is_expired() and not payload.has(RESPONSE_BODY_KEY):
			await _scene_tree.process_frame
		
		if timer.is_expired() or not payload.has(RESPONSE_BODY_KEY):
			return PackedByteArray()
		
		if not payload.body or payload.body.size() == 0:
			retries -= 1
	
	request_node.request_completed.disconnect(callback)
	
	return payload.body


func _pull_http_request_node(timer: PckableTimer) -> HTTPRequest:
	var free_request := get_free_request()
	
	if free_request:
		return free_request
	
	if _http_requests_pool.size() < max_http_requests_pool:
		free_request = HTTPRequest.new()
		add_child(free_request)
		_http_requests_pool[free_request] = false
	
	while not free_request and not timer.is_expired():
		await _scene_tree.process_frame
		
		free_request = get_free_request()
	
	return free_request


func get_free_request() -> HTTPRequest:
	for request in _http_requests_pool:
		if _http_requests_pool[request]:
			return request
	
	return null


func _load_resources_internal(keys: PackedStringArray,
 resources: PackedStringArray, timer: PckableTimer) -> Dictionary:
	var bundle := Dictionary()
	
	for resource in resources:
		ResourceLoader.load_threaded_request(resource, String(), false, 2)
	
	while not _all_resources_loaded(resources) and not timer.is_expired():
		await _scene_tree.process_frame
	
	if timer.is_expired():
		push_error("resource was not loaded in time")
		
		return bundle
	
	for i in resources.size():
		var resource := resources[i]
		
		match ResourceLoader.load_threaded_get_status(resource):
			0:
				push_error("invalid path %s" % resource)
			2: 
				push_error("load path failed %s" % resource)
			_:
				bundle[keys[i]] = ResourceLoader.load_threaded_get(resource)
	
	return bundle


func _all_resources_loaded(resources: PackedStringArray) -> bool:
	var loaded_resources := 0
	
	for resource in resources:
		if ResourceLoader.load_threaded_get_status(resource) != LOADING_STATUS:
			loaded_resources += 1
	
	return loaded_resources == resources.size()


func _on_request_completed(result: int, response_code: int,
 headers: PackedStringArray, body: PackedByteArray, status: Dictionary):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("wrong result code received %s" % result)
	
	if response_code < 200 or response_code > 299:
		push_error("wrong response code received %s" % response_code)
	
	status[RESPONSE_BODY_KEY] = body


func _try_init() -> void:
	if not _initializd:
		_storage = PckableStorageRuntime.new()
		_storage.setup()
		_scene_tree = get_tree()
		
		_initializd = true
     class_name PckablePathUtility extends Node


static func get_executable_dir() -> String:
	var path_parts := OS.get_executable_path().split("/")
	var file_path := String()
	
	path_parts.remove_at(path_parts.size() - 1)
	
	for path_part in path_parts:
		file_path += path_part + "/"
	
	return file_path


static func get_project_dir() -> String:
	return ProjectSettings.globalize_path("res://")


static func get_file_dir(file_path: String) -> String:
	var full_path := ProjectSettings.globalize_path("res://") + file_path
	var path_parts := full_path.split("/")
	var dir := String()
	
	path_parts.remove_at(path_parts.size() - 1)
	
	for path_part in path_parts:
		dir += path_part + "/"
	
	return dir
    class_name PckableStorageBase extends Object


const MANIFEST_PATH: String = "res://pckable_manifest.json"
const NAME_KEY: String = "name"
const ADDRESS_KEY: String = "address"
const RESOURCES_KEY: String = "resources"

var _catalogs: Array = []
var _path_to_catalog_name: Dictionary = {}
var _key_to_path: Dictionary = {}


func load_manifest_by_path(path: String):
	if not FileAccess.file_exists(path):
		print("manifest file not found")
		return null
	
	var file := FileAccess.open(path, FileAccess.READ)
	
	if not file:
		print("failed to open manifest file not found")
		return null
	
	var file_content := file.get_as_text()

	var json := JSON.new()
	var error := json.parse(file_content)
	
	if error == OK:
		return json.data as Array
	
	push_error("corrupted json %s" % file_content) 
	
	return null


func load_resources_from_manifest(catalogs: Array) -> void:
	for catalog in catalogs:
		var catalog_name := catalog[NAME_KEY] as String
		
		for resource in catalog[RESOURCES_KEY]:
			var path := resource.path as String
			
			_key_to_path[resource.key] = path
			_path_to_catalog_name[path] = catalog_name


func save_catalogs(path: String, catalogs: Array) -> Array:
	var file := FileAccess.open(path, FileAccess.WRITE_READ)
	
	file.store_string(JSON.stringify(catalogs))
	
	return catalogs


func get_key_by_path(path: String) -> String:
	if not _path_to_catalog_name.has(path):
		return String()
	
	var catalog_name := _path_to_catalog_name[path] as String
	
	for catalog in _catalogs:
		if catalog[NAME_KEY] == catalog_name:
			var resources := catalog[RESOURCES_KEY] as Array
			
			for resource in resources:
				if resource.path == path:
					return resource.key
			
			break
	
	return String()


func get_path_by_key(key: String) -> String:
	if _key_to_path.has(key):
		return _key_to_path[key]
	
	return String()


func get_catalog_name_by_path(path: String) -> String:
	if _path_to_catalog_name.has(path):
		return _path_to_catalog_name[path]
	
	return String()


func get_catalog_address(catalog_name: String) -> String:
	for catalog in _catalogs:
		if catalog_name == catalog[NAME_KEY]:
			return catalog[ADDRESS_KEY]
	
	return String()
 class_name PckableStorageRuntime extends PckableStorageBase


const USER_MANIFEST_PATH: String = "user://pckable_manifest.json"


func setup() -> void:
	var catalogs = load_manifest_by_path(MANIFEST_PATH)
	if not catalogs:
		return
	
	load_resources_from_manifest(catalogs)
	
	_catalogs = catalogs


func add_manifest(catalogs: Array) -> bool:
	load_resources_from_manifest(catalogs)
	
	var user_catalogs = load_manifest_by_path(USER_MANIFEST_PATH)
	if not user_catalogs:
		user_catalogs = save_catalogs(USER_MANIFEST_PATH, [])
	
	var merged_catalogs := []
	return true
      class_name PckableTimer extends RefCounted

var start_time_usec : int
var timeout_usec : int

static func create(timeout_msec: int) -> PckableTimer:
	var timer := PckableTimer.new()
	
	timer.start_time_usec = Time.get_ticks_usec()
	timer.timeout_usec = timeout_msec * 1000
	
	return timer

func is_expired() -> bool:
	return get_time_left_usec() <= 0


func get_time_left_sec() -> float:
	return get_time_left_msec() / 1000.0


func get_time_left_msec() -> float:
	return get_time_left_usec() / 1000.0


func get_time_left_usec() -> float:
	return timeout_usec - (Time.get_ticks_usec() - start_time_usec)
   [{"address":"local","name":"default","resources":[]},{"address":"local","name":"cat_catalog","resources":[{"key":"my_cat","path":"res://sample/Exotic_cat_transparent.png"}]},{"address":"local","name":"main_catalog","resources":[{"key":"main_scene","path":"res://sample/main.tscn"}]}]     RSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name 	   _bundled    script       Script    res://sample/startup.gd ��������      local://PackedScene_c1ome          PackedScene          	         names "         Startup    script    Node    	   variants                       node_count             nodes     	   ��������       ����                    conn_count              conns               node_paths              editable_instances              version             RSRC              extends Node


#var _main_scene = PackedScene
#var _cat_texture = Texture2D


func _ready() -> void:
	#_main_scene = await Pckable.load_resource("main_scene")
	#_main_scene = await Pckable.load_resource("my_cat")
	
	var bundle = await Pckable.load_resources(["main_scene", "my_cat"])
	var main_node = bundle.main_scene.instantiate()
	
	main_node.set_texture(bundle.my_cat)
	add_child(main_node)


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
    [remap]

path="res://.godot/exported/133200997/export-387dc8e492395271b5fee27bd3d5dd24-startup.scn"
            list=Array[Dictionary]([{
"base": &"VBoxContainer",
"class": &"PackefierInspector",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/editor/pckable_inspector.gd"
}, {
"base": &"Control",
"class": &"PckableControl",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/editor/pckable_control.gd"
}, {
"base": &"PopupPanel",
"class": &"PckableExportProgressPopup",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/editor/pckable_export_progress_popup.gd"
}, {
"base": &"Node",
"class": &"PckableExporter",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/editor/pckable_exporter.gd"
}, {
"base": &"EditorInspectorPlugin",
"class": &"PckableInspectorPlugin",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/editor/pckable_inspector_plugin.gd"
}, {
"base": &"Node",
"class": &"PckablePathUtility",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/runtime/pckable_path_utility.gd"
}, {
"base": &"Object",
"class": &"PckablePresetPatcher",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/editor/pckable_preset_patcher.gd"
}, {
"base": &"Object",
"class": &"PckablePresetProvider",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/editor/pckable_preset_provider.gd"
}, {
"base": &"Object",
"class": &"PckableStorageBase",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/runtime/pckable_storage_base.gd"
}, {
"base": &"PckableStorageBase",
"class": &"PckableStorageEditor",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/editor/pckable_storage_editor.gd"
}, {
"base": &"PckableStorageBase",
"class": &"PckableStorageRuntime",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/runtime/pckable_storage_runtime.gd"
}, {
"base": &"RefCounted",
"class": &"PckableTimer",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/runtime/pckable_timer.gd"
}, {
"base": &"Window",
"class": &"PckableWindow",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/editor/pckable_window.gd"
}, {
"base": &"Node",
"class": &"PckableWindowCatalogFactory",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/editor/pckable_window_catalog_factory.gd"
}, {
"base": &"Tree",
"class": &"PckableWindowCatalogTree",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/editor/pckable_window_catalog_tree.gd"
}, {
"base": &"Node",
"class": &"PckableWindowMenu",
"icon": "",
"language": &"GDScript",
"path": "res://addons/pckable/editor/pckable_window_menu.gd"
}])
      <svg height="128" width="128" xmlns="http://www.w3.org/2000/svg"><rect x="2" y="2" width="124" height="124" rx="14" fill="#363d52" stroke="#212532" stroke-width="4"/><g transform="scale(.101) translate(122 122)"><g fill="#fff"><path d="M105 673v33q407 354 814 0v-33z"/><path d="m105 673 152 14q12 1 15 14l4 67 132 10 8-61q2-11 15-15h162q13 4 15 15l8 61 132-10 4-67q3-13 15-14l152-14V427q30-39 56-81-35-59-83-108-43 20-82 47-40-37-88-64 7-51 8-102-59-28-123-42-26 43-46 89-49-7-98 0-20-46-46-89-64 14-123 42 1 51 8 102-48 27-88 64-39-27-82-47-48 49-83 108 26 42 56 81zm0 33v39c0 276 813 276 814 0v-39l-134 12-5 69q-2 10-14 13l-162 11q-12 0-16-11l-10-65H446l-10 65q-4 11-16 11l-162-11q-12-3-14-13l-5-69z" fill="#478cbf"/><path d="M483 600c0 34 58 34 58 0v-86c0-34-58-34-58 0z"/><circle cx="725" cy="526" r="90"/><circle cx="299" cy="526" r="90"/></g><g fill="#414042"><circle cx="307" cy="532" r="60"/><circle cx="717" cy="532" r="60"/></g></g></svg>
              ?1��n<)-   res://addons/pckable/editor/resources/add.svg�*SUj*.   res://addons/pckable/editor/resources/file.svgP���L��?1   res://addons/pckable/editor/resources/refresh.svg�ْ!V�0   res://addons/pckable/editor/resources/remove.svghh�W ,v7   res://addons/pckable/editor/scenes/pckable_control.tscn��;��dE   res://addons/pckable/editor/scenes/pckable_export_progress_popup.tscnWD���W9   res://addons/pckable/editor/scenes/pckable_inspector.tscn]z �1�6   res://addons/pckable/editor/scenes/pckable_window.tscn8~Ǣ��H'   res://sample/Exotic_cat_transparent.pngL�״��:   res://sample/main.tscn+�](�Ν   res://sample/startup.tscn�)+�xi@   res://icon.svg ECFG      application/config/name         PCKable    application/run/main_scene$         res://sample/startup.tscn      application/config/features$   "         4.2    Forward Plus       application/config/icon         res://icon.svg     autoload/Pckable0      (   *res://addons/pckable/runtime/pckable.gd+   debug/gdscript/warnings/unassigned_variable         5   debug/gdscript/warnings/unassigned_variable_op_assign         '   debug/gdscript/warnings/unused_variable         -   debug/gdscript/warnings/unused_local_constant         5   debug/gdscript/warnings/unused_private_class_variable         (   debug/gdscript/warnings/unused_parameter         %   debug/gdscript/warnings/unused_signal         )   debug/gdscript/warnings/shadowed_variable         4   debug/gdscript/warnings/shadowed_variable_base_class         2   debug/gdscript/warnings/shadowed_global_identifier         (   debug/gdscript/warnings/unreachable_code         +   debug/gdscript/warnings/unreachable_pattern         +   debug/gdscript/warnings/untyped_declaration         ,   debug/gdscript/warnings/inferred_declaration         .   debug/gdscript/warnings/unsafe_property_access         ,   debug/gdscript/warnings/unsafe_method_access         #   debug/gdscript/warnings/unsafe_cast         ,   debug/gdscript/warnings/unsafe_call_argument         *   debug/gdscript/warnings/unsafe_void_return         1   debug/gdscript/warnings/static_called_on_instance         *   debug/gdscript/warnings/assert_always_true         +   debug/gdscript/warnings/assert_always_false            editor_plugins/enabled,   "          res://addons/pckable/plugin.cfg            