class_name PckablePathUtility extends Node


static func get_executable_dir() -> String:
	var path_parts = OS.get_executable_path().split("/")
	var file_path = String()
	
	path_parts.remove_at(path_parts.size() - 1)
	
	for path_part in path_parts:
		file_path += path_part + "/"
	
	return file_path


static func get_project_dir() -> String:
	return ProjectSettings.globalize_path("res://")


static func get_file_dir(file_path: String) -> String:
	var full_path = ProjectSettings.globalize_path("res://") + file_path
	var path_parts = full_path.split("/")
	var dir = String()
	
	path_parts.remove_at(path_parts.size() - 1)
	
	for path_part in path_parts:
		dir += path_part + "/"
	
	return dir
