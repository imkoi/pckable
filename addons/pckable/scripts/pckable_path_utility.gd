class_name PckablePathUtility extends Node


static func get_project_path() -> String:
	var path_parts = OS.get_executable_path().split("/")
	var file_path = String()
	
	path_parts.remove_at(path_parts.size() - 1)
	
	for path_part in path_parts:
		file_path += path_part + "/"
	
	return file_path
