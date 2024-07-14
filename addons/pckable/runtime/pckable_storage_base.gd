class_name PckableStorageBase extends Object


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
			_path_to_catalog_name[path] = catalog_name;


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
