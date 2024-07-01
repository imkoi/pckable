@tool
class_name PackefierInspector extends VBoxContainer


@onready var catalog_container: HBoxContainer = $PckableCatalog
@onready var check_button: CheckButton = $PckableSwitch/CheckButton
@onready var option_button: OptionButton = $PckableCatalog/OptionButton

var _catalog_name: String
var _catalogs: Array
var _previous_option_index := -1

signal save_requested(catalog_name, enabled)


func setup(catalog_name: String, catalogs: Array) -> void:
	_catalog_name = catalog_name
	_catalogs = catalogs


func _ready() -> void:
	var has_catalog = not _catalog_name.is_empty()

	check_button.set_pressed(has_catalog)
	catalog_container.set_visible(has_catalog)

	for dictionary in _catalogs:
		option_button.add_item(dictionary[PckableStorage.NAME_KEY])
		
	check_button.toggled.connect(_on_toggled)
	option_button.item_selected.connect(_on_item_selected)


func _on_toggled(enabled : bool) -> void:
	var catalog_name := _get_catalog_name(option_button.selected)
	
	catalog_container.set_visible(enabled)
	save_requested.emit(catalog_name, enabled)


func _on_item_selected(item_index: int) -> void:
	var catalog_name := ""
	
	if _previous_option_index >= 0:
		catalog_name = _get_catalog_name(_previous_option_index)
		save_requested.emit(catalog_name, false)
	
	catalog_name = _get_catalog_name(option_button.selected)
	save_requested.emit(catalog_name, check_button.is_pressed())
	
	_previous_option_index = option_button.selected


func _get_catalog_name(option_index: int) -> String:
	return option_button.get_item_text(option_index)
