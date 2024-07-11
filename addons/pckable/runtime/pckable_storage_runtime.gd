class_name PckableStorageRuntime extends PckableStorageBase


const USER_MANIFEST_PATH: String = "user://pckable_manifest.json"


func add_manifest(catalogs: Array) -> bool:
	load_resources_from_manifest(catalogs)
	
	var user_catalogs = load_manifest_by_path(USER_MANIFEST_PATH)
	if not user_catalogs:
		user_catalogs = save_catalogs(USER_MANIFEST_PATH, [])
	
	var merged_catalogs := []
	return true
