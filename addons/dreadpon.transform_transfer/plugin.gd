tool
extends EditorPlugin


const TransferManager = preload("transfer_manager.gd")

var transfer_manager:TransferManager = TransferManager.new()




#-------------------------------------------------------------------------------
# Intialization and destruction
#-------------------------------------------------------------------------------


func _enter_tree():
	transfer_manager.undo_redo = get_undo_redo()
	transfer_manager.add_gui()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, transfer_manager.toolbar_spatial)
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, transfer_manager.toolbar_canvas)
	get_editor_interface().get_selection().connect("selection_changed", self, "selection_changed")
	# Make initial update to our buttons' visibility
	selection_changed()


func _exit_tree():
	transfer_manager.undo_redo = null
	# Apparently these are freed if we edit the plugin code and then reload 
	# So to no trigger the errors we make a check :/
	if transfer_manager.toolbar_spatial && transfer_manager.toolbar_canvas:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, transfer_manager.toolbar_spatial)
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, transfer_manager.toolbar_canvas)
		transfer_manager.remove_gui()
	get_editor_interface().get_selection().disconnect("selection_changed", self, "selection_changed")


func selection_changed():
	transfer_manager.selection_changed(get_editor_interface())
