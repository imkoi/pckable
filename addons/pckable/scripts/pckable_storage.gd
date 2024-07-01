class_name PckableStorage extends Object

const CATALOG_PATH: String = "res://pckable_catalogs.json"
const NAME_KEY: StringName = "name"
const REMOTE_ADDRESS_KEY: StringName = "remote_address"
const RESOURCES_KEY: StringName = "resources"

var _catalogs: Array
var _path_to_catalog_name: Dictionary

func setup() -> bool:
	print("pckable storage setup")
	
	if FileAccess.file_exists(CATALOG_PATH):
		var file = FileAccess.open(CATALOG_PATH, FileAccess.READ)
		var file_content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(file_content)
		
		if error == OK:
			_catalogs = json.data
			
			if _catalogs.size() == 0:
				_create_catalogs()
		else:
			push_error(error)
			
			return false
	else:
		push_warning("pckable_catalogs.json was not found, creating default one")
		_create_catalogs()
		
	for catalog in _catalogs:
		var catalog_name = catalog[NAME_KEY]
		var resources = catalog[RESOURCES_KEY]
		
		for resource in resources:
			_path_to_catalog_name[resource] = catalog_name;
		
		print(catalog)
	
	return true


func add_catalog(catalog_name: String) -> void:
	var new_catalog = _create_catalog(catalog_name);
	
	_catalogs.push_back(new_catalog)
	force_save_catalogs()


func remove_catalog(catalog_name: String) -> bool:
	var remove_index := 0
	
	for catalog in _catalogs:
		var suspect_catalog_name = catalog[NAME_KEY]
		
		if suspect_catalog_name == catalog_name:
			for resource in catalog[RESOURCES_KEY]:
				_path_to_catalog_name.erase(resource)
			
			_catalogs.remove_at(remove_index)
			force_save_catalogs()
			
			print(catalog_name)
			
			return true
		
		remove_index += 1
	
	return false


func add_resource_to_catalog(resource_path: String, catalog_name: String, force_save: bool = false) -> bool:
	if _path_to_catalog_name.has(resource_path):
		var previous_catalog = _path_to_catalog_name[resource_path]
		
		remove_resource_from_catalog(resource_path, previous_catalog)
	
	for catalog in _catalogs:
		var suspect_catalog_name = catalog[NAME_KEY]
		
		if suspect_catalog_name == catalog_name:
			catalog[RESOURCES_KEY].push_back(resource_path)
			_path_to_catalog_name[resource_path] = suspect_catalog_name
			
			if force_save:
				force_save_catalogs()
			
			return true
	
	return false


func remove_resource_from_catalog(resource_path: String, catalog_name: String, force_save: bool = false) -> bool:
	for catalog in _catalogs:
		var suspect_catalog_name = catalog[NAME_KEY]
		
		if suspect_catalog_name == catalog_name:
			catalog[RESOURCES_KEY].erase(resource_path)
			_path_to_catalog_name.erase(resource_path)
			
			if force_save:
				force_save_catalogs()
			
			return true
	
	return false


func get_catalog_name(resource_path: String) -> String:
	if _path_to_catalog_name:
		var catalog_name = _path_to_catalog_name.get(resource_path)
		
		return catalog_name if catalog_name else String()
	
	return String()
	
func get_catalog_names() -> PackedStringArray:
	var catalog_names = PackedStringArray()
	
	for catalog in _catalogs:
		var catalog_name = catalog[NAME_KEY]
		
		catalog_names.push_back(catalog_name)
	
	return catalog_names


func get_resources(catalog_name: String) -> PackedStringArray:
	var resources = PackedStringArray()
	
	for catalog in _catalogs:
		var suspect_catalog_name = catalog[NAME_KEY]
		var suspect_resources = catalog[RESOURCES_KEY]
		
		if catalog_name == suspect_catalog_name:
			for resource in suspect_resources:
				resources.push_back(resource)
			break
	
	return resources


func get_catalog_address(catalog_name: String) -> String:
	for catalog in _catalogs:
		if catalog_name == catalog[NAME_KEY]:
			return catalog[REMOTE_ADDRESS_KEY]
	
	return String()


func set_catalog_address(catalog_name: String, address: String,
 force_save: bool) -> void:
	for catalog in _catalogs:
		var suspect_catalog_name = catalog[NAME_KEY]
		
		if catalog_name == suspect_catalog_name:
			catalog[REMOTE_ADDRESS_KEY] = address
			break
	
	if force_save:
		force_save_catalogs()


func get_catalogs() -> Array:
	return _catalogs


func force_save_catalogs():
	var json_string = JSON.stringify(_catalogs)
	
	print(json_string)
	
	var file = FileAccess.open(CATALOG_PATH, FileAccess.WRITE)
	
	file.store_string(json_string)
	file.close();


func _create_catalogs() -> void:
	var file = FileAccess.open(CATALOG_PATH, FileAccess.WRITE_READ)
	
	_catalogs = [ _create_catalog("default") ]

	file.store_string(JSON.stringify(_catalogs))
	file.close()


func _create_catalog(catalog_name: String) -> Dictionary:
	return { NAME_KEY : catalog_name, REMOTE_ADDRESS_KEY : "local", RESOURCES_KEY : [] }
