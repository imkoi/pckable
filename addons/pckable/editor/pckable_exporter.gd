class_name PckableExporter extends Node

const PLUGIN_INCLUDES : PackedStringArray = [
	"res://addons/pckable/plugin.cfg",
	"res://addons/pckable/runtime/pckable.gd",
	"res://addons/pckable/runtime/pckable_path_utility.gd",
	"res://addons/pckable/runtime/pckable_storage_base.gd",
	"res://addons/pckable/runtime/pckable_storage_runtime.gd",
	"res://addons/pckable/runtime/pckable_timer.gd",
	"res://pckable_manifest.json",
]
const CATALOG_EXPORT := \
 "\"%s\" --headless --path \"%s\" --export-pack \"%s\" \"%s\""
const PROJECT_EXPORT := \
 "\"%s\" --headless --path \"%s\" --export-release \"%s\" \"%s\""

static func export_project(exe_path : String, path: String,
 preset_name: String, storage: PckableStorageEditor,
 progress_popup: PckableExportProgressPopup) -> void:
	progress_popup.set_text("Exporting project...")
	
	var godot_executable_path := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	var build_path := path
	
	var original_files := PckablePresetProvider.get_preset_resources(
		preset_name)
	var files := _get_project_files(
		storage.get_catalog_names(),
		original_files,
		storage)
	
	PckablePresetPatcher.preprocess_export_preset(preset_name, files)
	
	await _execute_command(PROJECT_EXPORT, [
		godot_executable_path,
		project_path,
		preset_name,
		exe_path])
	
	PckablePresetPatcher.postprocess_export_preset(preset_name, original_files)
	
	if progress_popup:
		progress_popup.hide()


static func export_catalogs(path: String, catalog_names: PackedStringArray,
 preset_name: String, storage: PckableStorageEditor,
 progress_popup: PckableExportProgressPopup) -> void:
	for catalog_name in catalog_names:
		var text_template := "Exporting \"%s\" catalog..."
		progress_popup.set_text(text_template % catalog_name)
		
		var godot_executable_path := OS.get_executable_path()
		var project_path := ProjectSettings.globalize_path("res://")
		var build_path := path
		
		if storage.get_catalog_address(catalog_name) != "local":
			build_path += "remote/"
			
			if not DirAccess.open(build_path):
				DirAccess.make_dir_absolute(build_path)
		
		var pck_file_path := "%s/%s.pck" % [build_path, catalog_name]
		var resources := storage.get_catalog_resources(catalog_name)
		var resource_paths := PackedStringArray()
		
		for resource in resources:
			resource_paths.push_back(resource.path)
		
		var original_presets = PckablePresetPatcher.preprocess_export_preset(
			preset_name, resource_paths)
		
		pck_file_path = pck_file_path.replace(project_path, String())
		
		await _execute_command(CATALOG_EXPORT, [
			godot_executable_path,
			project_path,
			preset_name,
			pck_file_path])
		
		PckablePresetPatcher.postprocess_export_preset(preset_name, original_presets)


static func _get_project_files(catalog_names: PackedStringArray,
 original_files: PackedStringArray,
 storage: PckableStorageEditor) -> PackedStringArray:
	var excluded_files := PackedStringArray()
	
	for catalog_name in catalog_names:
		var resources := storage.get_catalog_resources(catalog_name)
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
	var original_size := files.size()
	
	for removed_file_index in removed_file_indices:
		var offset := original_size - files.size()
		
		files.remove_at(removed_file_index - offset)
	
	for i in range(PLUGIN_INCLUDES.size() - 1, 0, -1):
		var included_file := PLUGIN_INCLUDES[i]
		
		if not files.has(included_file):
			files.insert(0, included_file)
	
	return files


static func _execute_command(command: String, args: Array) -> void:
	var arg := command % args
	var outputs := []
	var callable := func(): OS.execute("CMD.exe", ["/C", arg], outputs)
	
	var task_id := WorkerThreadPool.add_task(callable)
	
	while not WorkerThreadPool.is_task_completed(task_id):
		await Engine.get_main_loop().process_frame
	
	for output in outputs:
		print(output)
