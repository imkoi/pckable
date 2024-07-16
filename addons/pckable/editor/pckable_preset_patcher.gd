class_name PckablePresetPatcher extends Object


const PRESET_PATH := "res://export_presets.cfg"


static func preprocess_export_preset(preset_name: String,
 files: PackedStringArray):
	var config := PckablePresetProvider.get_preset_config()
	var original_files := PackedStringArray()
	
	for section in config.get_sections():
		if not config.has_section_key(section, "name"):
			continue
		
		if config.get_value(section, "name") != preset_name:
			continue
		
		if not config.has_section_key(section, "export_files"):
			return null
		
		original_files = config.get_value(section, "export_files")
		
		config.set_value(section, "export_files", files)
		break
	
	config.save(PRESET_PATH)
	
	return original_files


static func postprocess_export_preset(preset_name: String,
 original_files) -> void:
	var config := PckablePresetProvider.get_preset_config()
	
	for section in config.get_sections():
		if not config.has_section_key(section, "name"):
			continue
		
		if config.get_value(section, "name") != preset_name:
			continue
		
		if original_files:
			config.set_value(section, "export_files", original_files)
		else:
			config.erase_section_key(section, "export_files")
	
	config.save(PRESET_PATH)
