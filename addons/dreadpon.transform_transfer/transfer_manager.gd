tool
extends Reference


enum TransferNodeType {NODE_3D, NODE_2D, NODE_CONTROL, OTHER}
enum TransferScaleHandling {USE_AVERAGE, USE_MIN, USE_MAX, KEEP_ORIGINAL}
# This one uses bitflags since it can have these states at once
enum TransferFlags {TRANSLATION = int(pow(2,0)), ROTATION = int(pow(2,1)), SCALE = int(pow(2,2)), 
	ANCHOR = int(pow(2,3)), MARGIN = int(pow(2,4)), SIZE = int(pow(2,5)), MIN_SIZE = int(pow(2,6)), PIVOT_OFFSET = int(pow(2,7))}

const PRESET_2D_3D_ALL_TRANSFORMS = TransferFlags.TRANSLATION + TransferFlags.ROTATION + TransferFlags.SCALE

const transform_transfer_3d_icon = preload("assets/transform_transfer_3d_icon.svg")
const transform_transfer_2d_icon = preload("assets/transform_transfer_2d_icon.svg")
const transform_transfer_ui_icon = preload("assets/transform_transfer_ui_icon.svg")

var toolbar_spatial:Control = null
var toolbar_canvas:Control = null
var transfer_3d_button:MenuButton = null
var transfer_2d_button:MenuButton = null
var transfer_ui_button:MenuButton = null

# Used to check if we have only 1 type of nodes selected (i.e. only Spatial or only Node2D)
var active_node_types:Array = []
# An ordered selection queue since it seems Godot doesn't care about selection order
var selection_queue:Array = []
var undo_redo:UndoRedo = null





#-------------------------------------------------------------------------------
# Intialization and destruction
#-------------------------------------------------------------------------------


# We just hardcode it since it's easier
# Magic numbers in bind_popup_menu() represent checking_config, preset_config and preset_values respectively
func add_gui():
	toolbar_spatial = HBoxContainer.new()
	toolbar_spatial.add_child(VSeparator.new())
	
	toolbar_canvas = HBoxContainer.new()
	toolbar_canvas.add_child(VSeparator.new())
	
	transfer_3d_button = MenuButton.new()
	var button_3d_popup := transfer_3d_button.get_popup()
	transfer_3d_button.text = "Transfer 3D Transforms"
	transfer_3d_button.set_tooltip("Transfer transformations from LAST SELECTED Spatial scene to ALL OTHER selected Spatial scenes")
	transfer_3d_button.icon = transform_transfer_3d_icon
	button_3d_popup.hide_on_checkable_item_selection = false
	button_3d_popup.add_icon_item(transform_transfer_3d_icon, "Transfer")
	button_3d_popup.add_check_item("Translation")
	button_3d_popup.add_check_item("Rotation")
	button_3d_popup.add_check_item("Scale (uniform only)")
	button_3d_popup.add_separator("Non-uniform scale handling")
	button_3d_popup.add_radio_check_item("Average All Axes")
	button_3d_popup.add_radio_check_item("Use Min Axis")
	button_3d_popup.add_radio_check_item("Use Max Axis")
	bind_popup_menu(button_3d_popup, 
		[-1,0,0,0,-1,1,1,1], [0,1,1,1,0,1,0,0],
		[0, TransferFlags.TRANSLATION, TransferFlags.ROTATION, TransferFlags.SCALE, 0, TransferScaleHandling.USE_AVERAGE, TransferScaleHandling.USE_MIN, TransferScaleHandling.USE_MAX])
	
	transfer_2d_button = MenuButton.new()
	var button_2d_popup := transfer_2d_button.get_popup()
	transfer_2d_button.text = "Transfer 2D Transforms"
	transfer_2d_button.set_tooltip("Transfer transformations from LAST SELECTED NODE2D scene to ALL OTHER selected NODE2D scenes")
	transfer_2d_button.icon = transform_transfer_2d_icon
	button_2d_popup.hide_on_checkable_item_selection = false
	button_2d_popup.add_icon_item(transform_transfer_2d_icon, "Transfer")
	button_2d_popup.add_check_item("Translation")
	button_2d_popup.add_check_item("Rotation")
	button_2d_popup.add_check_item("Scale (uniform only)")
	button_2d_popup.add_separator("Non-uniform scale handling")
	button_2d_popup.add_radio_check_item("Average All Axes")
	button_2d_popup.add_radio_check_item("Use Min Axis")
	button_2d_popup.add_radio_check_item("Use Max Axis")
	bind_popup_menu(button_2d_popup, 
		[-1,0,0,0,-1,1,1,1], [0,1,1,1,0,1,0,0], 
		[0, TransferFlags.TRANSLATION, TransferFlags.ROTATION, TransferFlags.SCALE, 0, TransferScaleHandling.USE_AVERAGE, TransferScaleHandling.USE_MIN, TransferScaleHandling.USE_MAX])
	
	transfer_ui_button = MenuButton.new()
	var button_ui_popup := transfer_ui_button.get_popup()
	transfer_ui_button.text = "Transfer Control Transforms"
	transfer_ui_button.set_tooltip("Transfer transformations from LAST SELECTED Control scene to ALL OTHER selected Control scenes")
	transfer_ui_button.icon = transform_transfer_ui_icon
	button_ui_popup.hide_on_checkable_item_selection = false
	button_ui_popup.add_icon_item(transform_transfer_ui_icon, "Transfer")
	button_ui_popup.add_check_item("Position")
	button_ui_popup.add_separator("All remaining properties will be copied in local space")
	button_ui_popup.add_check_item("Anchor")
	button_ui_popup.add_check_item("Margin")
	button_ui_popup.add_check_item("Size")
	button_ui_popup.add_check_item("Min Size")
	button_ui_popup.add_check_item("Pivot Offset")
	button_ui_popup.add_check_item("Rotation")
	button_ui_popup.add_check_item("Scale (uniform only)")
	button_ui_popup.add_separator("Non-uniform scale handling")
	button_ui_popup.add_radio_check_item("Average All Axes")
	button_ui_popup.add_radio_check_item("Use Min Axis")
	button_ui_popup.add_radio_check_item("Use Max Axis")
	bind_popup_menu(button_ui_popup, 
		[-1,0,-1,0,0,0,0,0,0,0,-1,1,1,1], [0,1,-1,0,0,0,0,0,0,0,0,1,0,0],
		[0, TransferFlags.TRANSLATION, 0, TransferFlags.ANCHOR, TransferFlags.MARGIN, TransferFlags.SIZE, TransferFlags.MIN_SIZE, TransferFlags.PIVOT_OFFSET, TransferFlags.ROTATION, TransferFlags.SCALE, 
			0, TransferScaleHandling.USE_AVERAGE, TransferScaleHandling.USE_MIN, TransferScaleHandling.USE_MAX])
	
	toolbar_spatial.add_child(transfer_3d_button)
	toolbar_canvas.add_child(transfer_2d_button)
	toolbar_canvas.add_child(transfer_ui_button)


# checking_config defines groups for simple mutually exlusive checking (usually radio buttons)
# '< 0'  - group is not checkable
# '== 0' - group can be selected independently
# '> 0'  - is mutually exclusive with other items of the same group

# preset_config defines what items are initialized as pressed
# '== 0' - not pressed
# '> 0'  - pressed

# preset_values defines the values represented by each item
# This is used to configure our transfer based on which options we have selected
func bind_popup_menu(popup_menu:PopupMenu, checking_config:Array, preset_config:Array, preset_values:Array):
	popup_menu.connect("index_pressed", self, "popup_menu_item_pressed", [popup_menu, checking_config, preset_values])
	for i in range(0, preset_config.size()):
		if preset_config[i] > 0:
			popup_menu.emit_signal("index_pressed", i)


func remove_gui():
	toolbar_spatial.queue_free()
	toolbar_canvas.queue_free()
	toolbar_spatial = null
	toolbar_canvas = null




#-------------------------------------------------------------------------------
# UI management
#-------------------------------------------------------------------------------


func popup_menu_item_pressed(idx:int, popup_menu:PopupMenu, checking_config:Array, preset_values:Array):
	update_check_items(idx, popup_menu, checking_config)
	
	if idx == 0:
		var flags := 0
		var scale_handling:int = TransferScaleHandling.USE_AVERAGE
		
		# Take the represented value from preset_values and initialize out transfer settings
		for iterated_idx in range(0, checking_config.size()):
			if !popup_menu.is_item_checked(iterated_idx): continue
			
			if checking_config[iterated_idx] == 0:
				flags += preset_values[iterated_idx]
			elif checking_config[iterated_idx] == 1:
				scale_handling = preset_values[iterated_idx]
		
		proceed_transform_transfer(active_node_types[0], flags, scale_handling)


# Select/deselect items base on their config (mutual exclusivity)
func update_check_items(idx:int, popup_menu:PopupMenu, checking_config:Array):
	if checking_config[idx] < 0: return
	elif checking_config[idx] == 0:
		popup_menu.set_item_checked(idx, !popup_menu.is_item_checked(idx))
	elif checking_config[idx] >= 0:
		for i in range(0, checking_config.size()):
			if checking_config[i] == checking_config[idx]:
				popup_menu.set_item_checked(i, false)
		popup_menu.set_item_checked(idx, true)




#-------------------------------------------------------------------------------
# Selection
#-------------------------------------------------------------------------------


func selection_changed(editor_interface:EditorInterface):
	# Easier to just set them all to invisible instead of conditionally hiding them
	# Since it's not in _process but instead on user click, it's should be fine
	toolbar_spatial.visible = false
	toolbar_canvas.visible = false
	transfer_3d_button.visible = false
	transfer_2d_button.visible = false
	transfer_ui_button.visible = false
	
	if !editor_interface || !editor_interface.get_selection(): return 
	
	update_selection_queue(editor_interface.get_selection().get_selected_nodes())
	
	# Check what node types we have selected
	active_node_types = []
	for node in selection_queue:
		if node is Spatial:
			if !active_node_types.has(TransferNodeType.NODE_3D):
				active_node_types.append(TransferNodeType.NODE_3D)
		elif node is Node2D:
			if !active_node_types.has(TransferNodeType.NODE_2D):
				active_node_types.append(TransferNodeType.NODE_2D)
		elif node is Control:
			if !active_node_types.has(TransferNodeType.NODE_CONTROL):
				active_node_types.append(TransferNodeType.NODE_CONTROL)
		elif !active_node_types.has(TransferNodeType.OTHER):
			active_node_types.append(TransferNodeType.OTHER)
	
	# If we selected 2 or more nodes and they are of the same, acceptable type - show necessary buttons
	if selection_queue.size() >= 2 && active_node_types.size() == 1 && active_node_types[0] <= TransferNodeType.NODE_CONTROL:
		match active_node_types[0]:
			TransferNodeType.NODE_3D:
				toolbar_spatial.visible = true
				transfer_3d_button.visible = true
			TransferNodeType.NODE_2D:
				toolbar_canvas.visible = true
				transfer_2d_button.visible = true
			TransferNodeType.NODE_CONTROL:
				toolbar_canvas.visible = true
				transfer_ui_button.visible = true


# Manual update of selection array. Allows us to keep track of most recently selected node
func update_selection_queue(selected_nodes:Array):
	for node in selection_queue.duplicate():
		if !selected_nodes.has(node):
			selection_queue.erase(node)
	
	for node in selected_nodes:
		if !selection_queue.has(node):
			selection_queue.push_front(node)




#-------------------------------------------------------------------------------
# Transform transfer
#-------------------------------------------------------------------------------


# Make undo_redo action for the current node type and execute
func proceed_transform_transfer(node_type:int, flags:int, scale_handling:int):
	var selection = selection_queue.duplicate()
	var source = selection.pop_front()
	reorder_children_parents(selection, source)
	
	var transfer_node_type_key =  TransferNodeType.keys()[TransferNodeType.values().find(node_type)]
	undo_redo.create_action("Transfer transform %s" % [transfer_node_type_key])
	
	match node_type:
		
		TransferNodeType.NODE_3D:
			for target in selection:
				undo_redo.add_do_method(self, "set_3d_transform_to_flags", target, source.global_transform, flags, scale_handling)
				undo_redo.add_undo_method(self, "reset_3d_transform", target, target.global_transform)
			undo_redo.add_do_method(self, "set_3d_transform_to_flags", source, source.global_transform, PRESET_2D_3D_ALL_TRANSFORMS, TransferScaleHandling.KEEP_ORIGINAL)
			undo_redo.add_undo_method(self, "reset_3d_transform", source, source.global_transform)
		
		TransferNodeType.NODE_2D:
			for target in selection:
				undo_redo.add_do_method(self, "set_2d_transform_to_flags", target, source.global_transform, flags, scale_handling)
				undo_redo.add_undo_method(self, "reset_2d_transform", target, target.global_transform)
			undo_redo.add_do_method(self, "reset_2d_transform", source, source.global_transform)
			undo_redo.add_undo_method(self, "reset_2d_transform", source, source.global_transform)
		
		TransferNodeType.NODE_CONTROL:
			for target in selection:
				undo_redo.add_do_method(self, "set_ui_transform_to_flags", target, TransformUI.new(source), flags, scale_handling)
				undo_redo.add_undo_method(self, "reset_ui_transform", target, TransformUI.new(target))
			undo_redo.add_do_method(self, "reset_ui_transform", source, TransformUI.new(source))
			undo_redo.add_undo_method(self, "reset_ui_transform", source, TransformUI.new(source))
	
	undo_redo.commit_action()
	print("Transform Transfer: successfully transfered transform from '%s' to '%s'" % [source, str(selection)])


# Transfering parent transforms will also transform any children
# If we transfer children first and then the parent, children will become offset (since their parent updates their transforms)
# So we explicitly reorder our selection to transfer parents *first* and children *second*
func reorder_children_parents(selection:Array, source:Node):
	var root_node = null
	if Engine.editor_hint:
		root_node = source.get_tree().edited_scene_root
	else:
		root_node = source.get_tree().current_scene
	reorder_iterate_child(selection, selection.duplicate(), root_node)


func reorder_iterate_child(new_selection:Array, selection:Array, node:Node):
	for child in node.get_children():
		if selection.has(child):
			new_selection.append(child)
		reorder_iterate_child(new_selection, selection, child)





#-------------------------------------------------------------------------------
# Set 3D transform
#-------------------------------------------------------------------------------


func set_3d_transform_to_flags(target_node:Spatial, source_transform:Transform, flags:int, scale_handling:int):
	if flags & TransferFlags.TRANSLATION:
		target_node.global_transform.origin = source_transform.origin
	if flags & TransferFlags.ROTATION:
		var target_scale = target_node.scale
		target_node.global_transform.basis = source_transform.basis.orthonormalized()
		target_node.scale = target_scale
	if flags & TransferFlags.SCALE:
		var source_scale = normalize_3d_scale(source_transform.basis.get_scale(), scale_handling)
		target_node.global_transform.basis = target_node.global_transform.basis.orthonormalized()
		target_node.transform.basis = target_node.transform.basis.scaled(source_scale)


func reset_3d_transform(target_node:Spatial, source_transform:Transform):
	target_node.global_transform = source_transform


# Since it's (probably) impossible to accurately represent non-uniform scaling of differenly oriented nodes
# We normalize the scale, making it uniform
# We also have a few different options for how we choose that uniform value
func normalize_3d_scale(scale:Vector3, scale_handling:int):
	if scale_handling == TransferScaleHandling.KEEP_ORIGINAL: return scale
	
	var scale_axis_val = 0.0
	match scale_handling:
		TransferScaleHandling.USE_AVERAGE:
			scale_axis_val = (scale.x + scale.y + scale.z) / 3.0
		TransferScaleHandling.USE_MIN:
			scale_axis_val = min(min(scale.x, scale.y), scale.z)
		TransferScaleHandling.USE_MAX:
			scale_axis_val = max(max(scale.x, scale.y), scale.z)
	
	# Floating point error forces us to normalize the scale either way
	# But we don't need to warn the user if it is indeed because of precision error
	if !is_equal_approx(scale.x, scale.y) || !is_equal_approx(scale.x, scale.z):
		var scale_handling_key = TransferScaleHandling.keys()[TransferScaleHandling.values().find(scale_handling)]
		push_warning("Transform Transfer: 3D scale is not uniform! Normalized with %s" % [scale_handling_key])
	return Vector3(scale_axis_val, scale_axis_val, scale_axis_val)




#-------------------------------------------------------------------------------
# Set 2D transform
#-------------------------------------------------------------------------------


func set_2d_transform_to_flags(target_node:Node2D, source_transform:Transform2D, flags:int, scale_handling:int):
	if flags & TransferFlags.TRANSLATION:
		target_node.global_transform.origin = source_transform.origin
	if flags & TransferFlags.ROTATION:
		var target_scale = target_node.scale
		var target_position = target_node.position
		target_node.global_transform = source_transform.orthonormalized()
		target_node.scale = target_scale
		target_node.position = target_position
	if flags & TransferFlags.SCALE:
		var source_scale = normalize_2d_scale(source_transform.get_scale(), scale_handling)
		target_node.global_transform = target_node.global_transform.orthonormalized()
		target_node.global_scale = source_scale


func reset_2d_transform(target_node:Node2D, source_transform:Transform2D):
	target_node.global_transform = source_transform


# Since it's (probably) impossible to accurately represent non-uniform scaling of differenly oriented nodes
# We normalize the scale, making it uniform
# We also have a few different options for how we choose that uniform value
func normalize_2d_scale(scale:Vector2, scale_handling:int):
	var scale_axis_val = 0.0
	match scale_handling:
		TransferScaleHandling.USE_AVERAGE:
			scale_axis_val = (scale.x + scale.y) / 2.0
		TransferScaleHandling.USE_MIN:
			scale_axis_val = min(scale.x, scale.y)
		TransferScaleHandling.USE_MAX:
			scale_axis_val = max(scale.x, scale.y)
	
	# Floating point error forces us to normalize the scale either way
	# But we don't need to warn the user if it is indeed because of precision error
	if !is_equal_approx(scale.x, scale.y):
		var scale_handling_key = TransferScaleHandling.keys()[TransferScaleHandling.values().find(scale_handling)]
		push_warning("Transform Transfer: 2D scale is not uniform! Normalized with %s" % [scale_handling_key])
	return Vector2(scale_axis_val, scale_axis_val)




#-------------------------------------------------------------------------------
# Set UI transform
#-------------------------------------------------------------------------------


# Only rect_position has a meaningful global representation (and in terms of Control nodes even that is kind of useless)
# So for the rest, we just copy+paste the properties
# For children of the same Control that should be sufficient anyway
func set_ui_transform_to_flags(target_node:Control, source_transform:TransformUI, flags:int, scale_handling:int):
	if flags & TransferFlags.TRANSLATION:
		target_node.rect_global_position = source_transform.rect_global_position
	if flags & TransferFlags.SIZE:
		target_node.rect_size = source_transform.rect_size
	if flags & TransferFlags.ANCHOR:
		target_node.anchor_left = source_transform.anchor_left
		target_node.anchor_top = source_transform.anchor_top
		target_node.anchor_right = source_transform.anchor_right
		target_node.anchor_bottom = source_transform.anchor_bottom
	if flags & TransferFlags.MARGIN:
		target_node.margin_left = source_transform.margin_left
		target_node.margin_top = source_transform.margin_top
		target_node.margin_right = source_transform.margin_right
		target_node.margin_bottom = source_transform.margin_bottom
	if flags & TransferFlags.MIN_SIZE:
		target_node.rect_min_size = source_transform.rect_min_size
	if flags & TransferFlags.PIVOT_OFFSET:
		target_node.rect_pivot_offset = source_transform.rect_pivot_offset
	if flags & TransferFlags.ROTATION:
		target_node.rect_rotation = source_transform.rect_rotation
	if flags & TransferFlags.SCALE:
		# Since we don't have scale skewing/misrepresentation liek in Spatial and Node2D nodes
		# There's no need for normalization
		# (Not to mention we intentionally copy+paste it anyway)
		target_node.rect_scale = source_transform.rect_scale


func reset_ui_transform(target_node:Control, source_transform:TransformUI):
	target_node.anchor_left = source_transform.anchor_left
	target_node.anchor_top = source_transform.anchor_top
	target_node.anchor_right = source_transform.anchor_right
	target_node.anchor_bottom = source_transform.anchor_bottom
	
	target_node.margin_left = source_transform.margin_left
	target_node.margin_top = source_transform.margin_top
	target_node.margin_right = source_transform.margin_right
	target_node.margin_bottom = source_transform.margin_bottom
	
	target_node.rect_global_position = source_transform.rect_global_position#source_transform.rect_position
	target_node.rect_size = source_transform.rect_size
	target_node.rect_min_size = source_transform.rect_min_size
	target_node.rect_rotation = source_transform.rect_rotation
	target_node.rect_scale = source_transform.rect_scale
	target_node.rect_pivot_offset = source_transform.rect_pivot_offset




#-------------------------------------------------------------------------------
# Helper class to store all relevant Control transformations
#-------------------------------------------------------------------------------


class TransformUI extends Reference:
	export var anchor_left:float = 0.0
	export var anchor_top:float = 0.0
	export var anchor_right:float = 0.0
	export var anchor_bottom:float = 0.0
	
	export var margin_left:float = 0.0
	export var margin_top:float = 0.0
	export var margin_right:float = 0.0
	export var margin_bottom:float = 0.0
	
	export var rect_position:Vector2 = Vector2()
	export var rect_size:Vector2 = Vector2()
	export var rect_min_size:Vector2 = Vector2()
	export var rect_rotation:float = 0.0
	export var rect_scale:Vector2 = Vector2()
	export var rect_pivot_offset:Vector2 = Vector2()
	
	export var rect_global_position:Vector2 = Vector2()
	
	
	func _init(control:Control = null):
		if !control: return
		
		anchor_left = control.anchor_left
		anchor_top = control.anchor_top
		anchor_right = control.anchor_right
		anchor_bottom = control.anchor_bottom
		
		margin_left = control.margin_left
		margin_top = control.margin_top
		margin_right = control.margin_right
		margin_bottom = control.margin_bottom
		
		rect_position = control.rect_position
		rect_size = control.rect_size
		rect_min_size = control.rect_min_size
		rect_rotation = control.rect_rotation
		rect_scale = control.rect_scale
		rect_pivot_offset = control.rect_pivot_offset
		
		rect_global_position = control.rect_global_position
