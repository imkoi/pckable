class_name PckableExportPlugin extends EditorExportPlugin


var _storage: PckableStorage


func setup(storage: PckableStorage):
	_storage = storage;


func _get_name():
	return "_export_begin"


func _export_begin(features, is_debug, path, flags):
	#var platform = EditorExportPlatform.get
	#var options = _get_export_options(platform)
	
	#print(options)
	
	if features.has("pckable_export_catalogs"):
		pass
		#var full_path = PckablePathUtility.get_project_path() + path
		#var catalog_names = _storage.get_catalog_names()
		
		#PckableExporter.export(full_path, catalog_names, false, _storage, null)
