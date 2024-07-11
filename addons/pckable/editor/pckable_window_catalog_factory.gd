@tool
class_name PckableWindowCatalogFactory extends Node


@onready var _add_catalog_text: LineEdit = $LineEdit;
@onready var _add_catalog_button: Button = $Button;

signal request_create_item(catalog_name: String)

var _item_catalog_name_dictionary: Dictionary


func setup(item_catalog_name_dictionary: Dictionary) -> void:
	_item_catalog_name_dictionary = item_catalog_name_dictionary


func _ready() -> void:
	_add_catalog_button.pressed.connect(_on_add_catalog_button_pressed)


func _on_add_catalog_button_pressed() -> void:
	var catalog_name := _add_catalog_text.text
	
	if catalog_name.is_empty():
		push_error("catalog name could not be empty")
		return
	
	elif _catalog_exist(catalog_name):
		push_error("catalog %s already exist" % catalog_name)
		return
	
	request_create_item.emit(catalog_name)


func _catalog_exist(catalog_name: String) -> bool:
	for item in _item_catalog_name_dictionary:
		if _item_catalog_name_dictionary[item] == catalog_name:
			return true
	
	return false
