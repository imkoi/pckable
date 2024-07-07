@tool
class_name PckableWindowCatalogTree extends Tree


@export var _remove_texture: Texture2D
@export var _file_texture: Texture2D
@export var _catalog_text_color: Color
@export var _resource_text_color: Color

var _storage: PckableStorage
var _item_catalog_dictionary: Dictionary


func setup(storage: PckableStorage,
 item_catalog_dictionary: Dictionary) -> void:
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

		_item_catalog_dictionary[catalog_item] = catalog_name
		
		catalog_item.set_text(0, catalog_name)
		catalog_item.set_editable(1, true)
		catalog_item.set_text(1, catalog_address)
		
		catalog_item.set_custom_color(0, _catalog_text_color)
		catalog_item.set_custom_color(1, _catalog_text_color)
		
		catalog_item.add_button(1, _remove_texture, 0)
		catalog_item.set_button_color(1, 0, _catalog_text_color)
		
		for resource_path in catalog_resources:
			var resource_item = create_item(catalog_item)
			
			resource_item.set_text(0, resource_path)
			resource_item.set_custom_color(0, _resource_text_color)
			resource_item.set_custom_color(1, _resource_text_color)
			
			resource_item.add_button(1, _file_texture, 0)
			resource_item.set_button_color(1, 0, _resource_text_color)
			
			resource_item.add_button(1, _remove_texture, 1)
			resource_item.set_button_color(1, 1, _resource_text_color)


func rebuild_tree() -> void:
	clear()
	_item_catalog_dictionary.clear()
	build_tree()


func create_catalog(catalog_name: String):
	var root := create_item();
	
	root.set_text(0, catalog_name);
	root.get_text(1);
	root.set_editable(1, true);
	root.set_text(1, "local");
	
	_item_catalog_dictionary[root] = catalog_name


func _on_item_clicked(item: TreeItem, column: int, button_id: int,
 mouse_button: int) -> void:
	var text := item.get_text(0)
	
	if button_id == 0:
		var resource = load(text)
		if resource:
			EditorInterface.edit_resource(resource)
		else:
			push_error("found broken resource")
	else:
		if text.begins_with("res://"):
			var catalog_name := item.get_parent().get_text(0)
			
			if _storage.remove_resource_from_catalog(text, catalog_name, true):
				rebuild_tree()
		else:
			var catalog_name = _item_catalog_dictionary[item]
			if _storage.remove_catalog(catalog_name):
				rebuild_tree()


func _on_item_edited() -> void:
	var index := 0
	var count := 0
	
	for item in _item_catalog_dictionary:
		var catalog_name := _item_catalog_dictionary[item] as String
		var address := item.get_text(1) as String
		
		if address.is_empty():
			address = "local"
		
		index += 1
		
		_storage.set_catalog_address(catalog_name, address, index == count)
