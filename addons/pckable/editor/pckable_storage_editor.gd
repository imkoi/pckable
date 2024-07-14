class_name PckableStorageEditor extends PckableStorageBase


signal catalogs_changed()


func setup() -> void:
	var catalogs = load_manifest_by_path(MANIFEST_PATH)
	if not catalogs:
		print("catalogs not found")
		catalogs = save_catalogs(MANIFEST_PATH, [])
	
	load_resources_from_manifest(catalogs)
	
	_catalogs = catalogs


func add_catalog(catalog_name: String, force_save = false) -> void:
	var new_catalog := {
		NAME_KEY : catalog_name,
		ADDRESS_KEY : "local",
		RESOURCES_KEY : [],
	}
	
	_catalogs.push_back(new_catalog)
	
	print("added catalog %s" % catalog_name)
	
	if force_save:
		force_save_catalogs()
	
	catalogs_changed.emit()


func remove_catalog(catalog_name: String, force_save = false) -> bool:
	var remove_index := -1
	
	for catalog in _catalogs:
		remove_index += 1
		
		var suspect_catalog_name = catalog[NAME_KEY]
		
		if suspect_catalog_name != catalog_name:
			continue
		
		for resource in catalog[RESOURCES_KEY]:
			_key_to_path.erase(resource.key)
			_path_to_catalog_name.erase(resource.path)
		
		_catalogs.remove_at(remove_index)
		
		print("removed catalog %s" % catalog_name)
		
		if force_save:
			force_save_catalogs()
		
		catalogs_changed.emit()
		
		return true
	
	return false


func add_resource_to_catalog(key: String, path: String, catalog_name: String, force_save: bool = false) -> bool:
	if _path_to_catalog_name.has(path):
		var previous_catalog = _path_to_catalog_name[path]
		
		remove_resource_from_catalog(path, previous_catalog)
	
	for catalog in _catalogs:
		var suspect_catalog_name = catalog[NAME_KEY]
		
		if suspect_catalog_name == catalog_name:
			catalog[RESOURCES_KEY].push_back({"key": key, "path" : path})
			_path_to_catalog_name[path] = suspect_catalog_name
			_key_to_path[key] = path
			
			if force_save:
				force_save_catalogs()
			
			catalogs_changed.emit()
			
			return true
	
	return false


func remove_resource_from_catalog(path: String, catalog_name: String, force_save: bool = false) -> bool:
	for catalog in _catalogs:
		if catalog[NAME_KEY] == catalog_name:
			var key = get_key_by_path(path)
			catalog[RESOURCES_KEY].erase({"key" : key, "path" : path})
			
			_key_to_path.erase(key)
			_path_to_catalog_name.erase(path)
			
			if force_save:
				force_save_catalogs()
			
			catalogs_changed.emit()
			
			return true
	
	return false


func set_catalog_address(catalog_name: String, address: String,
 force_save: bool) -> void:
	for catalog in _catalogs:
		var suspect_catalog_name = catalog[NAME_KEY]
		
		if catalog_name != suspect_catalog_name:
			continue
			
		catalog[ADDRESS_KEY] = address
		print("catalog %s address setted to %" % [catalog_name, address])
		
		if force_save:
			force_save_catalogs()
		
		return
	
	push_error("catalog %s not founded" % catalog_name)


func get_catalog_names() -> PackedStringArray:
	var catalog_names := PackedStringArray()
	
	for catalog in _catalogs:
		var catalog_name = catalog[NAME_KEY]
		
		catalog_names.push_back(catalog_name)
	
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


func force_save_catalogs():
	var json_string := JSON.stringify(_catalogs)
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	
	file.store_string(json_string)
	file.close();
	
	print("catalogs saved")
