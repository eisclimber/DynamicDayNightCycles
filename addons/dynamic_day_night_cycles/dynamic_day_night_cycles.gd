@tool
extends EditorPlugin

const NODE_NAME = "CustomEOT"
const INHERITANCE = "Node"
const NODE_SCRIPT = preload("CustomEOT.gd")
const NODE_ICON = preload("res://addons/accurate_daytime_cycles/Icon.svg")


func _enter_tree() -> void:
	# Add CustomEOT-Node to the scene dialog
	add_custom_type(NODE_NAME, INHERITANCE, NODE_SCRIPT, NODE_ICON)


func _exit_tree() -> void:
	# Remove CustomEOT-Node to the scene dialog
	remove_custom_type(NODE_NAME)
