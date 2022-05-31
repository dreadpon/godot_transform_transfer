tool
extends EditorPlugin


const transform_transfer_icon = preload("transform_transfer_icon.svg")

var toolbar = null
var transfer_button : ToolButton = null

var selection_queue := []




# This is a test comment
func _enter_tree():
	add_gui()
	bind_selection()


func _exit_tree():
	ubbind_selection()
	remove_gui()




func add_gui():
	toolbar = HBoxContainer.new()
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, toolbar)
	toolbar.add_child(VSeparator.new())
	
	transfer_button = ToolButton.new()
	transfer_button.text = "Transfer Transform"
	transfer_button.set_tooltip("Tranfer transformations from LAST SELECTED spatial scene to ALL OTHER selected spatial scenes")
	transfer_button.icon = transform_transfer_icon
	transfer_button.connect("pressed", self, "try_transform_transfer")
	toolbar.add_child(transfer_button)


func remove_gui():
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, toolbar)
	toolbar.queue_free()
	toolbar = null


func bind_selection():
	get_editor_interface().get_selection().connect("selection_changed", self, "selection_changed")
	selection_changed()


func ubbind_selection():
	get_editor_interface().get_selection().disconnect("selection_changed", self, "selection_changed")


func selection_changed():
	if !get_editor_interface() || !get_editor_interface().get_selection(): 
		toolbar.set_visible(false)
		return
	
	update_selection_queue(get_editor_interface().get_selection().get_transformable_selected_nodes())
	
	if selection_queue.size() >= 2:
		toolbar.set_visible(true)
	else:
		toolbar.set_visible(false)


func update_selection_queue(selection:Array):
	for scene in selection_queue:
		if !selection.has(scene):
			selection_queue.erase(scene)
	for scene in selection:
		if !selection_queue.has(scene) && scene as Spatial:
			selection_queue.push_front(scene)


func try_transform_transfer():
	var selection = selection_queue.duplicate()
	
	if selection.size() < 2: 
		push_error("Transform Transfer: Select at least 2 Spatial scenes!")
		return
	
	var source = selection.pop_front()
	
	var _undo_redo := get_undo_redo()
	_undo_redo.create_action("Transfer transform")
	for target in selection:
		_undo_redo.add_undo_property(target, "transform", target.transform)
		target.transform = source.transform
		_undo_redo.add_do_property(target, "transform", target.transform)
	_undo_redo.commit_action()
	
	print("Transform Transfer: Successfully transfered transform from %s to %s" % [source.name, str(selection)])
