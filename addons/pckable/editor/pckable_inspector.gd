@tool
class_name PackefierInspector extends VBoxContainer


@onready var key_container: HBoxContainer = $PckableKey
@onready var catalog_container: HBoxContainer = $PckableCatalog
@onready var check_button: CheckButton = $PckableSwitch/CheckButton
@onready var option_button: OptionButton = $PckableCatalog/OptionButton
@onready var line_edit: LineEdit = $PckableKey/LineEdit

var _path: String
var _catalog: String
var _key: String
var _catalogs_names: PackedStringArray
var _linked: bool
var _previous_option_index := -1

signal save_requested(key, catalog_name, enabled)


func setup(path: String, catalog: String, key: String,
 catalog_names: PackedStringArray, linked: bool) -> void:
	_path = path
	_catalog = catalog
	_key = key
	_catalogs_names = catalog_names
	_linked = linked


func _ready() -> void:
	check_button.set_pressed(_linked)
	key_container.set_visible(_linked)
	catalog_container.set_visible(_linked)
	
	var selected_index := 0
	
	for catalog_name in _catalogs_names:
		option_button.add_item(catalog_name)
		
		if catalog_name == _catalog:
			_previous_option_index = selected_index
		selected_index += 1
	
	if _previous_option_index >= 0:
		option_button.select(_previous_option_index)
	
	line_edit.set_text(_key)
	
	check_button.toggled.connect(_on_toggled)
	option_button.item_selected.connect(_on_item_selected)
	line_edit.text_submitted.connect(_on_key_submitted)


func _on_toggled(enabled : bool) -> void:
	var catalog_name := _get_catalog_name(option_button.selected)
	
	catalog_container.set_visible(enabled)
	key_container.set_visible(enabled)
	save_requested.emit(_key, catalog_name, enabled)


func _on_item_selected(item_index: int) -> void:
	var catalog_name := String()
	
	if _previous_option_index >= 0:
		catalog_name = _get_catalog_name(_previous_option_index)
		save_requested.emit(_key, catalog_name, false)
	
	catalog_name = _get_catalog_name(option_button.selected)
	save_requested.emit(_key, catalog_name, check_button.is_pressed())
	
	_previous_option_index = option_button.selected


func _on_key_submitted(key: String) -> void:
	var catalog_name := _get_catalog_name(option_button.selected)
	save_requested.emit(_key, catalog_name, false)
	save_requested.emit(key, catalog_name, check_button.is_pressed())
	
	_key = key


func _get_catalog_name(option_index: int) -> String:
	return option_button.get_item_text(option_index)
