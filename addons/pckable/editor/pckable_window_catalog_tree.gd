@tool
class_name PckableWindowCatalogTree extends Tree

const REMOVE_BUTTON_ID := 0
const FOCUS_BUTTON_ID := 1

@export var _remove_texture: Texture2D
@export var _file_texture: Texture2D
@export var _catalog_text_color: Color
@export var _resource_text_color: Color

var _storage: PckableStorageEditor
var _item_catalog_name_dictionary: Dictionary


func setup(storage: PckableStorageEditor,
 item_catalog_name_dictionary: Dictionary) -> void:
	_storage = storage
	_item_catalog_name_dictionary = item_catalog_name_dictionary


func _ready() -> void:
	item_edited.connect(_on_item_edited)
	button_clicked.connect(_on_item_clicked)


func _drop_data(at_position: Vector2, data: Variant):
	var dropable_paths := PackedStringArray()
	
	print("_drop_data")
	var file_paths := data["files"] as PackedStringArray
	for path in file_paths:
		print(path)
		#var item_len = get_item_count()
		#add_item(path.get_file().get_basename())
		#set_item_metadata(item_len, path)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var dropable_paths := PackedStringArray()

	var file_paths := data["files"] as PackedStringArray
	for path in file_paths:
		if path.begins_with("res://addons/"):
			return false
		
		if path.ends_with("/"):
			var dir := DirAccess.open(path)
			dir.set_include_hidden(false)
			
			return dir.get_files().size() > 0
	
	return false


func build_tree() -> void:
	var catalog_names := _storage.get_catalog_names()
	
	set_hide_root(true)
	
	var root := create_item()
	root.set_text(0, "catalogs")
	
	var button_index := 0
	
	for catalog_name in catalog_names:
		var catalog_address := _storage.get_catalog_address(catalog_name)
		var catalog_resources := _storage.get_catalog_resources(catalog_name)
		var catalog_item := _create_catalog(catalog_name, catalog_address)
		
		for resource in catalog_resources:
			var resource_item := create_item(catalog_item)
			
			resource_item.set_text(0, resource.path)
			resource_item.set_custom_color(0, _resource_text_color)
			
			resource_item.set_text(1, resource.key)
			resource_item.set_custom_color(1, _resource_text_color)
			
			resource_item.set_editable(1, true)
			
			resource_item.add_button(1, _file_texture, 0)
			resource_item.set_button_color(1, 0, _resource_text_color)
			resource_item.add_button(1, _remove_texture, 1)
			resource_item.set_button_color(1, 1, _resource_text_color)


func rebuild_tree() -> void:
	clear()
	_item_catalog_name_dictionary.clear()
	build_tree()


func _create_catalog(catalog_name: String, catalog_address: String) -> TreeItem:
	var editable := catalog_name != "default"
	var catalog_item := create_item()
	
	catalog_item.set_text(0, catalog_name)
	catalog_item.set_editable(1, editable)
	catalog_item.set_text(1, catalog_address)
	
	catalog_item.set_custom_color(0, _catalog_text_color)
	catalog_item.set_custom_color(1, _catalog_text_color)
	
	if editable:
		catalog_item.add_button(1, _remove_texture, 0)
		catalog_item.set_button_color(1, 0, _catalog_text_color)
	
	_item_catalog_name_dictionary[catalog_item] = catalog_name
	
	return catalog_item


func _on_item_clicked(item: TreeItem, column: int, button_id: int,
 mouse_button: int) -> void:
	var text := item.get_text(0)
	
	if text.begins_with("res://"):
		if button_id == 0:
			var resource := load(text)
			if resource:
				EditorInterface.edit_resource(resource)
		else:
			var catalog_name := item.get_parent().get_text(0)
			
			if _storage.remove_resource_from_catalog(text, catalog_name, true):
				rebuild_tree()
	else:
		var catalog_name = _item_catalog_name_dictionary[item]
		if _storage.remove_catalog(catalog_name, true):
			rebuild_tree()


func _on_item_edited() -> void:
	for item in _item_catalog_name_dictionary:
		var catalog_item := item as TreeItem
		var catalog_name := _item_catalog_name_dictionary[item] as String
		var address := item.get_text(1) as String
		
		if address.is_empty():
			address = "local"
		
		for resource_item in catalog_item.get_children():
			var resource_path := resource_item.get_text(0)
			var resource_key := resource_item.get_text(1)
			
			_storage.add_resource_to_catalog(resource_key, resource_path,
			 catalog_name, false, false)
		
		_storage.set_catalog_address(catalog_name, address, false, false)
	
	_storage.force_save_catalogs()
