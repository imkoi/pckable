class_name PckableInspectorPlugin extends EditorInspectorPlugin


const INSPECTOR_RESOURCE: Resource = \
 preload('res://addons/pckable/editor/scenes/pckable_inspector.tscn')
const EXCLUDED_FILES = [
	"res://project.godot",
	"res://export_presets.cfg",
	"res://pckable_catalogs.json"
	]
const EXCLUDED_DIRS = [
	"res://addons/pckable/"
]

var _path : String
var _storage: PckableStorageEditor
var min_path_lenght := "res://".length()


func setup(storage: PckableStorageEditor) -> void:
	_storage = storage


func _can_handle(object : Object) -> bool:
	if object is Node:
		var node := object as Node
		_path = node.scene_file_path
	
	if object is Resource:
		var resource := object as Resource
		_path = resource.resource_path
	
	if EXCLUDED_DIRS.any(func(dir): return _path.begins_with(dir)):
		_path = String()
	
	if EXCLUDED_FILES.has(_path):
		_path = String()
	
	return _path.length() > min_path_lenght


func _parse_begin(object : Object) -> void:
	var inspector_instance := INSPECTOR_RESOURCE.instantiate() \
	 as PackefierInspector
	
	inspector_instance.setup(_path, _storage)
	inspector_instance.save_requested.connect(on_save_requested)
	
	add_custom_control(inspector_instance)


func on_save_requested(key: String, catalog_name: String,
 enabled: bool) -> void:
	if enabled:
		_storage.add_resource_to_catalog(key, _path, catalog_name, true)
		print("add resource \"%s\" to %s" % [_path, catalog_name])
	else:
		_storage.remove_resource_from_catalog(_path, catalog_name, true)
		print("remove resource \"%s\" from %s" % [_path, catalog_name])
