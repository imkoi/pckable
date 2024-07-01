@tool
class_name PckableExportProgressPopup extends PopupPanel


@export var _label: Label


func set_text(text: String) -> void:
	_label.set_text(text)
