class_name PckableExportPlugin extends EditorExportPlugin


const PLUGIN_INCLUDES = [
	"res://addons/pckable/scripts/pckable_catalog.gd",
	"res://addons/pckable/scripts/pckable_path_utility.gd",
	"res://addons/pckable/scripts/pckable_storage.gd",
	"res://addons/pckable/pckable.gd",
	"res://pckable_catalogs.json",
]

var _storage: PckableStorage
var _build_path: String
var _original_preset_files: PackedStringArray
var is_building := false


func setup(storage: PckableStorage):
	_storage = storage;


func _get_name():
	return "_export_begin"


func _export_begin(features, is_debug, path, flags) -> void:
	var preset_name = get_preset_name()
	var catalog_names := _storage.get_catalog_names()
	
	_build_path = PckablePathUtility.get_file_dir(path)
	
	PckableExporter.export(_build_path, catalog_names, preset_name, _storage, null)
	
	var files := PckablePresetProvider.get_preset_resources(preset_name)
	var export_files := _get_build_files(catalog_names, files)
	
	print("set main build export files")
	_original_preset_files = PckablePresetPatcher.preprocess_export_preset(
		preset_name, export_files)
	
	is_building = true


func _export_end() -> void:
	var preset_name := get_preset_name()
	var remote_pcks_path := _build_path + "remote/"
	
	PckablePresetPatcher.postprocess_export_preset(preset_name,
	 _original_preset_files)
	
	if DirAccess.open(remote_pcks_path):
		var web_server_path := remote_pcks_path + "run_web_server.bat"
		var file := FileAccess.open(web_server_path, FileAccess.WRITE_READ)
		
		file.store_string("python -m http.server 8000")
		file.close()
	
	print("export ended")


func _should_update_export_options(platform: EditorExportPlatform) -> bool:
	if is_building:
		print("return true")
		is_building = false
		return true
		
	return false


# this api will be added to godot 4.4, but right now preset will be hardcoded
func get_preset_name() -> String:
	return "PCKable"


func _get_build_files(catalog_names: PackedStringArray,
 original_files: PackedStringArray) -> PackedStringArray:
	var excluded_files := PackedStringArray()
	
	for catalog_name in catalog_names:
		var resources = _storage.get_resources(catalog_name)
		excluded_files.append_array(resources)

	var files := original_files.slice(0, original_files.size())
	var file_index := 0
	var removed_file_indices := PackedInt32Array()
	
	for file in files:
		if excluded_files.has(file):
			removed_file_indices.append(file_index)
		elif file.begins_with("res://addons/pckable/"):
			removed_file_indices.append(file_index)
		file_index += 1
	
	removed_file_indices.sort()
	var original_size := files.size();

	for removed_file_index in removed_file_indices:
		var offset := original_size - files.size()
		
		files.remove_at(removed_file_index - offset)
	
	for included_file in PLUGIN_INCLUDES:
		if not files.has(included_file):
			files.append(included_file)

	return files
