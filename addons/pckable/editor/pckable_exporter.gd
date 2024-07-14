class_name PckableExporter extends Node

const PLUGIN_INCLUDES = [
	"res://addons/pckable/scripts/pckable_storage_runtime.gd",
	"res://addons/pckable/scripts/pckable_storage_base.gd",
	"res://addons/pckable/scripts/pckable_path_utility.gd",
	"res://addons/pckable/pckable.gd",
	"res://pckable_manifest.json",
]
const CATALOG_EXPORT_ARGS := \
 "\"%s\" --headless --path \"%s\" --export-pack \"%s\" \"%s\""
const PROJECT_EXPORT_ARGS := \
 "\"%s\" --headless --path \"%s\" --export-release \"%s\" \"%s\""

static func export_project(exe_path : String, path: String,
 preset_name: String, storage: PckableStorageEditor,
 progress_popup: PckableExportProgressPopup) -> void:
	var popup_resolution = Vector2(
		DisplayServer.screen_get_size().x / 6,
		DisplayServer.screen_get_size().y / 6)
	
	if progress_popup:
		var text_template = "Exporting project..."
		progress_popup.set_text(text_template)
		
		progress_popup.popup_centered(popup_resolution)
		await progress_popup.get_tree().create_timer(0.25).timeout
	
	var godot_executable_path = OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")
	var build_path := path
	
	var original_files := PckablePresetProvider.get_preset_resources(
		preset_name)
	var files := _get_project_files(
		storage.get_catalog_names(),
		original_files,
		storage)
	
	push_warning(files)
	
	var original_presets = PckablePresetPatcher.preprocess_export_preset(
		preset_name, files)
	
	var original_files2 := PckablePresetProvider.get_preset_resources(
		preset_name)
	push_warning(original_files2)
	
	var arg = PROJECT_EXPORT_ARGS % [
		godot_executable_path,
		project_path,
		preset_name,
		exe_path]
	
	var outputs = []
	
	OS.execute("CMD.exe", ["/C", arg], outputs)
	
	for output in outputs:
		print(output)
	
	PckablePresetPatcher.postprocess_export_preset(preset_name, original_presets)
	
	if progress_popup:
		progress_popup.hide()


static func export_catalogs(path: String, catalog_names: PackedStringArray,
 preset_name: String, storage: PckableStorageEditor,
 progress_popup: PckableExportProgressPopup) -> void:
	var popup_resolution = Vector2(
		DisplayServer.screen_get_size().x / 6,
		DisplayServer.screen_get_size().y / 6)
	
	if progress_popup:
		progress_popup.popup_centered(popup_resolution)
		await progress_popup.get_tree().create_timer(0.25).timeout
	
	for catalog_name in catalog_names:
		if progress_popup:
			var text_template = "Exporting \"%s\" catalog..."
			var progress_popup_text = text_template % catalog_name
			progress_popup.set_text(progress_popup_text)
			await progress_popup.get_tree().create_timer(0.25).timeout
		
		var godot_executable_path = OS.get_executable_path()
		var project_path := ProjectSettings.globalize_path("res://")
		var build_path := path
		
		if storage.get_catalog_address(catalog_name) != "local":
			build_path += "remote/"
			var build_dir = DirAccess.open(build_path)
			
			if not build_dir:
				DirAccess.make_dir_absolute(build_path)
		
		var pck_file_path := "%s/%s.pck" % [build_path, catalog_name]
		var resources := storage.get_catalog_resources(catalog_name)
		var resource_paths := PackedStringArray()
		
		for resource in resources:
			resource_paths.push_back(resource.path)
		
		var original_presets = PckablePresetPatcher.preprocess_export_preset(
			preset_name, resource_paths)
		
		pck_file_path = pck_file_path.replace(project_path, "")
		
		var arg = CATALOG_EXPORT_ARGS % [
			godot_executable_path,
			project_path,
			preset_name,
			pck_file_path]
		
		var outputs = []
		
		OS.execute("CMD.exe", ["/C", arg], outputs)
		
		for output in outputs:
			print(output)
		
		PckablePresetPatcher.postprocess_export_preset(preset_name, original_presets)
	
	if progress_popup:
		progress_popup.hide()


static func _get_project_files(catalog_names: PackedStringArray,
 original_files: PackedStringArray,
 storage: PckableStorageEditor) -> PackedStringArray:
	var excluded_files := PackedStringArray()
	
	for catalog_name in catalog_names:
		var resources = storage.get_catalog_resources(catalog_name)
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
