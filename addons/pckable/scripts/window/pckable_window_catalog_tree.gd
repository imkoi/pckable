@tool
class_name PckableWindowCatalogTree extends Tree


@export var _remove_texture: Texture2D

var _storage: PckableStorage
var _item_catalog_dictionary: Dictionary


func setup(storage: PckableStorage, item_catalog_dictionary: Dictionary) -> void:
	_storage = storage
	_item_catalog_dictionary = item_catalog_dictionary


func _ready() -> void:
	item_edited.connect(_on_item_edited)
	button_clicked.connect(_on_item_clicked)


func build_tree() -> void:
	var catalogs = _storage.get_catalogs()
	
	var root = create_item()
	root.set_text(0, "catalogs")
	
	var button_index := 0
	
	for catalog in catalogs:
		var catalog_name = catalog[PckableStorage.NAME_KEY]
		var catalog_address = catalog[PckableStorage.REMOTE_ADDRESS_KEY]
		var catalog_resources = catalog[PckableStorage.RESOURCES_KEY]
		var catalog_item = create_item()
		var editable = false if catalog_name == "default" else true
		
		_item_catalog_dictionary[catalog_item] = catalog_name
		
		catalog_item.set_text(0, catalog_name)
		catalog_item.get_text(1)
		catalog_item.set_editable(1, editable)
		catalog_item.set_text(1, catalog_address)
		
		if editable:
			catalog_item.add_button(1, _remove_texture, 0)
			catalog_item.set_button_color(1, 0, Color.RED)
		
		for resource_path in catalog_resources:
			var resource_item = create_item(catalog_item)
			
			resource_item.set_text(0, resource_path)
			resource_item.set_checked(1, true)
			
			resource_item.set_selectable(0, false)
			resource_item.set_selectable(1, false)


func create_catalog(catalog_name: String):
	var root = create_item();
	var editable = false if catalog_name == "default" else true
	
	root.set_text(0, catalog_name);
	root.get_text(1);
	root.set_editable(1, editable);
	root.set_text(1, "local");
	
	_item_catalog_dictionary[root] = catalog_name


func _on_item_clicked(item: TreeItem, column: int, id: int, mouse_button: int) -> void:
	var catalog_name = _item_catalog_dictionary[item]
	if _storage.remove_catalog(catalog_name):
		clear()
		_item_catalog_dictionary.clear()
		
		build_tree()


func _on_item_edited() -> void:
	var index := 0
	var count := 0
	
	for item in _item_catalog_dictionary:
		var catalog_name = _item_catalog_dictionary[item]
		var address = item.get_text(1)
		
		index += 1
		
		_storage.set_catalog_address(catalog_name, address, index == count)
