@tool
class_name PckableWindowMenu extends Node


@export var _export_project_button : Button
@export var _export_catalogs_button : Button
@export var _preset_button: OptionButton
@export var _refresh_button : Button
@export var _export_progress_popup_scene: PackedScene

signal request_tree_refresh()

var _file_dialog_resolution: Vector2
var _file_dialog: EditorFileDialog
var _export_progress_popup: PckableExportProgressPopup
var _storage: PckableStorageEditor
var _item_catalog_dictionary: Dictionary
var _viewport_ready: bool


func setup(storage: PckableStorageEditor,
 item_catalog_dictionary: Dictionary) -> void:
	_storage = storage
	_item_catalog_dictionary = item_catalog_dictionary
	
	var presets := PckablePresetProvider.get_preset_names()
	
	for i in presets.size():
		var preset_name := presets[i] as String
		
		_preset_button.add_item(preset_name, i)


func _ready() -> void:
	_export_project_button.pressed.connect(_on_export_project_pressed)
	_export_catalogs_button.pressed.connect(_on_export_catalogs_pressed)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	
	_file_dialog_resolution = Vector2(
			DisplayServer.screen_get_size().x / 2,
			DisplayServer.screen_get_size().y / 2)
	_file_dialog = EditorFileDialog.new()
	_file_dialog.set_meta("_created_by", self)
	_file_dialog.title = "Select export directory"
	_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	
	_export_progress_popup = _export_progress_popup_scene.instantiate()


func _exit_tree() -> void:
	if _file_dialog:
		_file_dialog.queue_free()
		_file_dialog = null
	if _export_progress_popup:
		_export_progress_popup.queue_free()
		_export_progress_popup = null


func _on_export_project_pressed() -> void:
	var catalog_names := PackedStringArray()
	
	for catalog_name in _item_catalog_dictionary.values():
		catalog_names.push_back(catalog_name as String)
	
	var preset_index := _preset_button.get_selected_id()
	var preset_name := _preset_button.get_item_text(preset_index)
	
	_try_setup_viewport()
	
	var executable_path := PckablePresetProvider.get_export_path(
		preset_name)
	var dir_path := PckablePathUtility.get_file_dir(executable_path)
	var absolute_dir_path := ProjectSettings.globalize_path(dir_path)
	
	if not DirAccess.open(absolute_dir_path):
		DirAccess.make_dir_absolute(absolute_dir_path)
	
	_export_progress_popup.popup_centered(_get_popup_resolution())

	await PckableExporter.export_catalogs(absolute_dir_path,
	 catalog_names, preset_name, _storage, _export_progress_popup)
	
	await PckableExporter.export_project(executable_path,
	 dir_path, preset_name, _storage, _export_progress_popup)
	
	_export_progress_popup.hide()


func _on_export_catalogs_pressed() -> void:
	var catalog_names := PackedStringArray()
	
	for tree_item in _item_catalog_dictionary:
		if tree_item.is_selected(0) or tree_item.is_selected(1):
			var catalog_name := _item_catalog_dictionary[tree_item] as String
			
			catalog_names.push_back(catalog_name)
	
	if catalog_names.size() == 0:
		for catalog_name in _item_catalog_dictionary.values():
			catalog_names.push_back(catalog_name as String)
	
	_try_setup_viewport()
	
	_file_dialog.popup_centered(_file_dialog_resolution)
	
	var dir_selected = await _file_dialog.dir_selected
	var preset_index := _preset_button.get_selected_id()
	var preset_name := _preset_button.get_item_text(preset_index)
	
	_export_progress_popup.popup_centered(_get_popup_resolution())

	await PckableExporter.export_catalogs(dir_selected, catalog_names,
	 preset_name, _storage, _export_progress_popup)
	
	_export_progress_popup.hide()


static func _get_popup_resolution() -> Vector2:
	return Vector2(
		DisplayServer.screen_get_size().x / 6,
		DisplayServer.screen_get_size().y / 6)


func _on_refresh_pressed() -> void:
	request_tree_refresh.emit()


func _try_setup_viewport() -> void:
	if not _viewport_ready:
		var viewport := get_viewport()
		
		viewport.add_child(_file_dialog)
		viewport.add_child(_export_progress_popup)
		_viewport_ready = true
