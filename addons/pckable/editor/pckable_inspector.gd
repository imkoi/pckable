@tool
class_name PackefierInspector extends VBoxContainer


@onready var key_container: HBoxContainer = $PckableKey
@onready var catalog_container: HBoxContainer = $PckableCatalog
@onready var check_button: CheckButton = $PckableSwitch/CheckButton
@onready var option_button: OptionButton = $PckableCatalog/OptionButton
@onready var line_edit: LineEdit = $PckableKey/LineEdit

var _path: String
var _storage: PckableStorageEditor

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
	var key := line_edit.get_text()
	
	catalog_container.set_visible(enabled)
	key_container.set_visible(enabled)
	
	save_requested.emit(key, catalog_name, enabled)


func _on_catalog_selected(item_index: int) -> void:
	var catalog_name := _get_catalog_name(option_button.selected)
	var key := line_edit.get_text()
	
	save_requested.emit(key, catalog_name, check_button.is_pressed())


func _on_key_submitted(key: String) -> void:
	var catalog_name := _get_catalog_name(option_button.selected)
	save_requested.emit(key, catalog_name, check_button.is_pressed())


func _on_storage_changed() -> void:
	option_button.clear()
	
	var linked := not _storage.get_catalog_name_by_path(_path).is_empty()
	var catalog_names := _storage.get_catalog_names()
	
	check_button.set_pressed(linked)
	key_container.set_visible(linked)
	catalog_container.set_visible(linked)
	
	for catalog_name in catalog_names:
		option_button.add_item(catalog_name)
	
	if not linked:
		return
	
	var key := _storage.get_key_by_path(_path)
	var catalog := _storage.get_catalog_name_by_path(_path)
	
	line_edit.set_text(key)
	
	var selected_index := 0
	
	for item_index in option_button.item_count:
		var catalog_name := option_button.get_item_text(item_index)
		
		if catalog_name == catalog:
			option_button.select(selected_index)
		
		selected_index += 1


func _get_catalog_name(option_index: int) -> String:
	if option_index >= 0:
		return option_button.get_item_text(option_index)
	
	return String()
