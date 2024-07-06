class_name PckableExporter extends Node


const ARGS := "\"%s\" --headless --path \"%s\" --export-pack \"%s\" \"%s\""


static func export(path: String, catalog_names: PackedStringArray,
 preset_name: String, storage: PckableStorage,
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
		var resources = storage.get_resources(catalog_name)
		
		var original_presets = PckablePresetPatcher.preprocess_export_preset(preset_name, resources)
		
		pck_file_path = pck_file_path.replace(project_path, "")
		
		var arg = ARGS % [
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
	print("all catalogs exported")
