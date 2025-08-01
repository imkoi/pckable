GDPC                @                                                                      
   P   res://.godot/exported/133200997/export-2fe0e77a8e65763482bf1ed9bff95482-main.scn        �      �1W�u�*Fl���2ԟ    ,   res://.godot/global_script_class_cache.cfg  �       
      h`�py��=�\?g<       res://.godot/uid_cache.bin  �.      �      7���&�T�q�x    (   res://addons/pckable/runtime/pckable.gd �      �      �Ac�l~QD��J@b       res://icon.svg  �*      �      k����X3Y���f       res://project.binary@1      �      ��\A/�y�m���,       res://sample/Cell.gd0      C       G}'��e�;u�Q��       res://sample/Field.gd   �      �       �������j�M�jEȖ       res://sample/main.gdp      �       ���^�*�&X�%�d       res://sample/main.tscn.remapP       a       �umU<��)�K��)H                RSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name 	   _bundled    script       Script    res://sample/main.gd ��������   Script    res://sample/Field.gd ��������   Script    res://sample/Cell.gd ��������      local://PackedScene_2vlx8 e         PackedScene          	         names "         Node    script 	   Camera2D    Field    width    height    bombs_count    TopPart    Node2D    MiddlePart    Cell    FrontContainer 	   Sprite2D    BackContainer    Front    BottomPart    	   variants                                                     node_count             nodes     Y   ��������        ����                            ����                       ����                                            ����                  	   ����                  
   ����                          ����                     ����                     ����                     ����                     ����              conn_count              conns               node_paths              editable_instances              version             RSRC      extends Node

@export var width: int
@export var height: int
@export var bombs_count: int


func _ready():
	pass


func _process(_delta):
	pass
extends Node


func _ready() -> void:
	pass


func set_texture(tex: Texture2D) -> void:
	var sprite := get_node("Field/MiddlePart/Cell/FrontContainer/Sprite2D")
	sprite.set_texture(tex)
      extends Node


func _ready():
	pass


func _process(_delta):
	pass
             extends Node


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
     [remap]

path="res://.godot/exported/133200997/export-2fe0e77a8e65763482bf1ed9bff95482-main.scn"
               list=Array[Dictionary]([{
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