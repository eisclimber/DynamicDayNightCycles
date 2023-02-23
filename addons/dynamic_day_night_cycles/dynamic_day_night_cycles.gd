@tool
extends EditorPlugin

const NODE_NAME = "CustomEOT"
const INHERITANCE = "Node"
const NODE_SCRIPT = preload("res://addons/dynamic_day_night_cycles/custom_eot.gd")
const NODE_ICON = preload("res://addons/dynamic_day_night_cycles/node_icon.svg")


func _enter_tree() -> void:
	# Add CustomEOT-Node to the scene dialog
	add_custom_type(NODE_NAME, INHERITANCE, NODE_SCRIPT, NODE_ICON)


func _exit_tree() -> void:
	# Remove CustomEOT-Node to the scene dialog
	remove_custom_type(NODE_NAME)
