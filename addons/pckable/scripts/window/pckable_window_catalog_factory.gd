@tool
class_name PckableWindowCatalogFactory extends Node


@onready var _add_catalog_text: LineEdit = $LineEdit;
@onready var _add_catalog_button: Button = $Button;

signal request_create_item(catalog_name: String)

var _storage: PckableStorage


func setup(storage: PckableStorage) -> void:
	_storage = storage


func _ready() -> void:
	_add_catalog_button.pressed.connect(_on_add_catalog_button_pressed)


func _on_add_catalog_button_pressed() -> void:
	var catalog_name := _add_catalog_text.text
	
	if catalog_name.is_empty():
		push_error("catalog name could not be empty")
		return
	
	elif _has_catalog(catalog_name):
		push_error("catalog %s already exist" % catalog_name)
		return
	
	_storage.add_catalog(catalog_name)
	
	request_create_item.emit(catalog_name)


func _has_catalog(catalog_name: String) -> bool:
	var catalogs := _storage.get_catalogs()
	
	for catalog in catalogs:
		var suspect_catalog_name := catalog[PckableStorage.NAME_KEY] as String
		
		if suspect_catalog_name == catalog_name:
			return true
	return false
