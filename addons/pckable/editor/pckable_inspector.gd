@tool
class_name PackefierInspector extends VBoxContainer


@onready var key_container: HBoxContainer = $PckableKey
@onready var catalog_container: HBoxContainer = $PckableCatalog
@onready var check_button: CheckButton = $PckableSwitch/CheckButton
@onready var option_button: OptionButton = $PckableCatalog/OptionButton
@onready var line_edit: LineEdit = $PckableKey/LineEdit

var _path: String
var _storage: PckableStorageEditor
var _previous_catalog_index := -1
var _previous_key := String()

signal save_requested(key, catalog_name, enabled)


func setup(path: String, storage: PckableStorageEditor) -> void:
	_path = path
	_storage = storage


func _ready() -> void:
	_on_storage_changed()
	
	check_button.toggled.connect(_on_toggled)
	option_button.item_selected.connect(_on_catalog_selected)
	line_edit.text_submitted.connect(_on_key_submitted)
	_storage.changed.connect(_on_storage_changed)


func _on_toggled(enabled : bool) -> void:
	var catalog_name := _get_catalog_name(option_button.selected)

	catalog_container.set_visible(enabled)
	key_container.set_visible(enabled)
	
	if not _previous_key.is_empty():
		save_requested.emit(_previous_key, catalog_name, enabled)


func _on_catalog_selected(item_index: int) -> void:
	var catalog_name := String()
	
	if _previous_catalog_index >= 0:
		catalog_name = _get_catalog_name(_previous_catalog_index)
		save_requested.emit(_previous_key, catalog_name, false)
	
	catalog_name = _get_catalog_name(option_button.selected)
	save_requested.emit(_previous_key, catalog_name, check_button.is_pressed())
	
	_previous_catalog_index = option_button.selected


func _on_key_submitted(key: String) -> void:
	var catalog_name := _get_catalog_name(option_button.selected)
	save_requested.emit(_previous_key, catalog_name, false)
	save_requested.emit(key, catalog_name, check_button.is_pressed())


func _on_storage_changed():
	option_button.clear()
	
	var linked := not _storage.get_catalog_name_by_path(_path).is_empty()
	_previous_key = _storage.get_key_by_path(_path)
	var catalog := _storage.get_catalog_name_by_path(_path)
	var catalog_names := _storage.get_catalog_names()
	
	check_button.set_pressed(linked)
	key_container.set_visible(linked)
	catalog_container.set_visible(linked)
	
	var selected_index := 0
	
	for catalog_name in catalog_names:
		option_button.add_item(catalog_name)
		
		if catalog_name == catalog:
			_previous_catalog_index = selected_index
		selected_index += 1
	
	if _previous_catalog_index >= 0:
		option_button.select(_previous_catalog_index)
	
	line_edit.set_text(_previous_key)


func _get_catalog_name(option_index: int) -> String:
	return option_button.get_item_text(option_index)
