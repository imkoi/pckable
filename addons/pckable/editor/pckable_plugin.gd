@tool
extends EditorPlugin

const PCKABLE_WINDOW_NAME: String = "Open PCKable Window"
const PCKABLE_SINGLETON_NAME: String = "Pckable"
const PCKABLE_SINGLETON_PATH: String = "res://addons/pckable/runtime/pckable.gd"
const CATALOG_PATH: String = "res://pckable_catalogs.json"
const WINDOW_RESOURCE: Resource = preload("res://addons/pckable/editor/scenes/pckable_window.tscn")
const DOCK_RESOURCE: Resource = preload("res://addons/pckable/editor/scenes/pckable_control.tscn")
const INSPECTOR_PLUGIN_RESOURCE: Resource = preload("res://addons/pckable/editor/pckable_inspector_plugin.gd")
const EXPORT_PLUGIN_RESOURCE: Resource = preload("res://addons/pckable/editor/pckable_export_plugin.gd")

var window: PckableWindow
var dock: PckableControl
var inspector_plugin: PckableInspectorPlugin
var export_plugin: PckableExportPlugin
var storage: PckableStorageEditor
var catalogs: Dictionary


func _enter_tree() -> void:
	storage = PckableStorageEditor.new()
	
	storage.setup()
	
	add_autoload_singleton(PCKABLE_SINGLETON_NAME, PCKABLE_SINGLETON_PATH)
	
	if _exporting_now():
		return
	
	dock = DOCK_RESOURCE.instantiate()
	dock.setup(storage)
	
	inspector_plugin = INSPECTOR_PLUGIN_RESOURCE.new()
	export_plugin = EXPORT_PLUGIN_RESOURCE.new()
	
	inspector_plugin.setup(storage)
	export_plugin.setup(storage)
	
	add_inspector_plugin(inspector_plugin)
	add_export_plugin(export_plugin)
	add_tool_menu_item(PCKABLE_WINDOW_NAME, _open_window)
	add_control_to_dock(2, dock)


func _exit_tree() -> void:
	remove_autoload_singleton(PCKABLE_SINGLETON_NAME)
	
	if _exporting_now():
		return
		
	remove_inspector_plugin(inspector_plugin)
	remove_export_plugin(export_plugin)
	remove_tool_menu_item(PCKABLE_WINDOW_NAME)
	remove_control_from_docks(dock)
	
	storage.force_save_catalogs()
	storage.free()
	
	if window:
		window.queue_free()
		window = null
	if dock:
		dock.queue_free()
		dock = null


func _open_window() -> void:
	if not window:
		var screen_resolution = DisplayServer.screen_get_size();
		var target_resolution = Vector2(
				screen_resolution.x / 2,
				screen_resolution.y / 2)
		
		window = WINDOW_RESOURCE.instantiate()
		window.setup(storage)
		window.size = target_resolution
		
		EditorInterface.popup_dialog_centered(window)
	else:
		window.move_to_foreground()


func _exporting_now() -> bool:
	return OS.get_cmdline_args().has("--export-pack")
