class_name PckableStorageEditor extends PckableStorageBase


signal changed()


func setup() -> void:
	var catalogs = load_manifest_by_path(MANIFEST_PATH)
	if not catalogs:
		print("catalogs not found")
		catalogs = save_catalogs(MANIFEST_PATH, [])
	
	var default_catalog_exist := false
	
	for catalog in catalogs:
		if catalog[NAME_KEY] == "default":
			default_catalog_exist = true
			break;
	
	if not default_catalog_exist:
		print("default catalog added")
		var new_catalog := {
		NAME_KEY : "default",
		ADDRESS_KEY : "local",
		RESOURCES_KEY : [],
		}
		
		catalogs.insert(0, new_catalog)
	
	load_resources_from_manifest(catalogs)
	
	_catalogs = catalogs


func add_catalog(catalog_name: String, force_save: bool = false) -> void:
	var new_catalog := {
		NAME_KEY : catalog_name,
		ADDRESS_KEY : "local",
		RESOURCES_KEY : [],
	}
	
	_catalogs.push_back(new_catalog)
	
	print("added catalog %s" % catalog_name)
	
	if force_save:
		force_save_catalogs(false)
	
	changed.emit()


func remove_catalog(catalog_name: String, force_save: bool = false) -> bool:
	var remove_index := -1
	
	for catalog in _catalogs:
		remove_index += 1
		
		if catalog[NAME_KEY] != catalog_name:
			continue
		
		for resource in catalog[RESOURCES_KEY]:
			_key_to_path.erase(resource.key)
			_path_to_catalog_name.erase(resource.path)
		
		_catalogs.remove_at(remove_index)
		
		print("removed catalog %s" % catalog_name)
		
		if force_save:
			force_save_catalogs(false)
		
		changed.emit()
		
		return true
	
	return false


func add_resource_to_catalog(key: String, path: String,
 catalog_name: String, force_save: bool = false,
 emit_changed: bool = true) -> bool:
	if _path_to_catalog_name.has(path):
		var previous_catalog := _path_to_catalog_name[path] as String
		
		remove_resource_from_catalog(path, previous_catalog,
		 false, false)
	
	for catalog in _catalogs:
		var suspect_catalog_name := catalog[NAME_KEY] as String
		
		if suspect_catalog_name == catalog_name:
			catalog[RESOURCES_KEY].push_back({"key": key, "path" : path})
			_path_to_catalog_name[path] = suspect_catalog_name
			_key_to_path[key] = path
			
			if force_save:
				force_save_catalogs(emit_changed)
			
			return true
	
	return false


func remove_resource_from_catalog(path: String, catalog_name: String,
 force_save: bool = false, emit_changed: bool = true) -> bool:
	for catalog in _catalogs:
		if catalog[NAME_KEY] == catalog_name:
			var key := get_key_by_path(path)
			catalog[RESOURCES_KEY].erase({"key" : key, "path" : path})
			
			_key_to_path.erase(key)
			_path_to_catalog_name.erase(path)
			
			if force_save:
				force_save_catalogs(emit_changed)
			
			return true
	
	return false


func set_catalog_address(catalog_name: String, address: String,
 force_save: bool, emit_changed: bool = true) -> void:
	for catalog in _catalogs:
		if catalog_name != catalog[NAME_KEY]:
			continue
			
		catalog[ADDRESS_KEY] = address
		print("catalog %s address setted to %s" % [catalog_name, address])
		
		if force_save:
			force_save_catalogs(emit_changed)
		
		return
	
	push_error("catalog %s not founded" % catalog_name)


func get_catalog_names() -> PackedStringArray:
	var catalog_names := PackedStringArray()
	
	for catalog in _catalogs:
		catalog_names.push_back(catalog[NAME_KEY])
	
	return catalog_names


func get_catalog_resources(catalog_name: String) -> Array:
	var resources := []
	
	for catalog in _catalogs:
		if catalog_name == catalog[NAME_KEY]:
			for resource in catalog[RESOURCES_KEY]:
				resources.push_back(resource)
			break
	
	return resources


func catalog_exist(catalog_name: String) -> bool:
	for catalog in _catalogs:
		if catalog[PckableStorageEditor.NAME_KEY] == catalog_name:
			return true
	
	return false


func force_save_catalogs(emit_changed: bool = true) -> void:
	var json_string := JSON.stringify(_catalogs)
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	
	file.store_string(json_string)
	
	if emit_changed:
		changed.emit()
	
	print("catalogs saved")
