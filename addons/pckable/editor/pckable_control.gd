@tool
class_name PckableControl extends Control


@export var _catalog_tree: PckableWindowCatalogTree
@export var _catalog_factory: PckableWindowCatalogFactory
@export var _menu: PckableWindowMenu

var _storage: PckableStorageEditor
var _item_catalog_name_dictionary: Dictionary = {}


func setup(storage: PckableStorageEditor) -> void:
	_storage = storage
	
	_catalog_tree.setup(storage, _item_catalog_name_dictionary)
	_menu.setup(storage, _item_catalog_name_dictionary)
	_catalog_factory.setup(_item_catalog_name_dictionary)


func _ready() -> void:
	if not _storage:
		return
	
	_catalog_tree.build_tree()
	
	_catalog_factory.request_create_item.connect(_on_request_create_item)
	_menu.request_tree_refresh.connect(_on_request_tree_refresh)


func _on_request_create_item(catalog_name: String):
	_storage.add_catalog(catalog_name, true)
	_catalog_tree.create_catalog(catalog_name, "local")


func _on_request_tree_refresh():
	_catalog_tree.clear()
	_item_catalog_name_dictionary.clear()
	
	_catalog_tree.build_tree()


func _on_close_requested() -> void:
	hide();
	queue_free();
