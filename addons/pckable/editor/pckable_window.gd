@tool
class_name PckableWindow extends Window


@export var control: PckableControl


func setup(storage: PckableStorageEditor) -> void:
	control.setup(storage)


func _ready() -> void:
	close_requested.connect(_on_close_requested)


func _on_close_requested() -> void:
	hide();
	queue_free();
