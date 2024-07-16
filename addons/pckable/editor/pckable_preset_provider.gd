class_name PckablePresetProvider extends Object


static func get_preset_names() -> PackedStringArray:
	var config := get_preset_config()
	var presets := PackedStringArray()
	
	for section in config.get_sections():
		if not config.has_section_key(section, "name"):
			continue
		
		var preset_name := config.get_value(section, "name")
		presets.push_back(preset_name)
	
	return presets


static func get_preset_resources(preset_name: String) -> PackedStringArray:
	var config := get_preset_config()
	var resources := PackedStringArray()
	
	for section in config.get_sections():
		if not config.has_section_key(section, "name"):
			continue
		
		if preset_name != config.get_value(section, "name"):
			continue
		
		if not config.has_section_key(section, "export_files"):
			return resources
		
		resources = config.get_value(section, "export_files")
		break
		
	return resources


static func get_export_path(preset_name: String) -> String:
	var config := get_preset_config()
	
	for section in config.get_sections():
		if not config.has_section_key(section, "name"):
			continue
		
		if preset_name != config.get_value(section, "name"):
			continue
		
		if not config.has_section_key(section, "export_path"):
			break
		
		return config.get_value(section, "export_path")
	
	return String()


static func get_preset_config() -> ConfigFile:
	var config := ConfigFile.new()
	
	if config.load("res://export_presets.cfg") != OK:
		push_error("failed to load export_presets.cfg")
	
	return config
