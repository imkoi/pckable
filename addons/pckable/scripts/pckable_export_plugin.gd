class_name PckableExportPlugin extends EditorExportPlugin


var _storage: PckableStorage


func setup(storage: PckableStorage):
	_storage = storage;


func _get_name():
	return "_export_begin"


func _export_begin(features, is_debug, path, flags):
	if OS.get_cmdline_args().has("--export-pack"):
		return
	
	var preset_name = get_preset_name()
	
	var full_path = PckablePathUtility.get_project_path() + path
	var catalog_names = _storage.get_catalog_names()
	
	PckableExporter.export(full_path, catalog_names, preset_name, _storage, null)
