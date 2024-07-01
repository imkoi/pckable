class_name PckableExporter extends Node

const ARGS := "\"%s\" --headless --path \"%s\" --export-pack \"%s\" \"%s\""
const PRESET_PATH := "res://export_presets.cfg"


static func export(path: String, catalog_names: PackedStringArray,
 preset_name: String, exprot_from_window: bool,
 storage: PckableStorage, progress_popup: PckableExportProgressPopup) -> void:
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
		var pck_file_path := "%s/%s.pck" % [path, catalog_name]
		var resources = storage.get_resources(catalog_name)
		
		var old_resources = preprocess_export_preset(preset_name, resources)
		
		pck_file_path = pck_file_path.replace(project_path, "")

		var arg = ARGS % [
			godot_executable_path,
			project_path,
			preset_name,
			pck_file_path]
		
		OS.execute("CMD.exe", ["/C", arg])
		
		for res in resources:
			print("export %s" % res)
		
		postprocess_export_preset(preset_name, old_resources)
		
		print("finish exporting %s catalog" % catalog_name)
	
	if progress_popup:
		progress_popup.hide()
	print("all catalogs exported")


static func preprocess_export_preset(preset_name: String, files: PackedStringArray) -> PackedStringArray:
	var config = PckablePresetProvider.get_preset_config()
	var old_files := PackedStringArray()
	
	for section in config.get_sections():
		if not config.has_section_key(section, "name"):
			continue
		
		if config.get_value(section, "name") != preset_name:
			continue
		
		old_files = config.get_value(section, "export_files") as PackedStringArray
		config.set_value(section, "export_files", files)
	
	config.save(PRESET_PATH)
	
	return old_files


static func postprocess_export_preset(preset_name: String, files: PackedStringArray) -> void:
	var config = PckablePresetProvider.get_preset_config()
	
	for section in config.get_sections():
		if not config.has_section_key(section, "name"):
			continue
		
		if config.get_value(section, "name") != preset_name:
			continue
		
		if files.size() == 0:
			config.erase_section_key(section, "export_files")
		else:
			config.set_value(section, "export_files", files)
	
	config.save(PRESET_PATH)
