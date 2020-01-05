tool
extends EditorPlugin

var toolbar = null
var undo_redo = null
var editing_node = null

enum EDIT_MODE { AddNodes, MoveNodes, DeleteNodes, AddEdges, DeleteEdges }
var edit_mode = EDIT_MODE.AddNodes

var mouse_pressed = false # whether the left mouse button is pressed
var cursor_pos_viewport = null
var cursor_pos_local = null # snapped cursor position

var edge_start_node_index = -1 # used when creating an edge
var moving_node_index = -1  # used when moving a node

# TODO(matt): make these configurable somehow?
var selection_radius_sq: float = 100 * 100
var snap_grid_size: float = 8.0


func _enter_tree() -> void:  # override
	# init plugin
	add_custom_type('DiGraph2D', 'Node2D', preload('DiGraph2D.gd'), preload('../assets/icon.png'))

	toolbar = preload('GraphEditToolbar.tscn').instance()
	toolbar.get_node('AddNodes').connect('pressed', self, 'on_toolbar_clicked', [EDIT_MODE.AddNodes])
	toolbar.get_node('MoveNodes').connect('pressed', self, 'on_toolbar_clicked', [EDIT_MODE.MoveNodes])
	toolbar.get_node('DeleteNodes').connect('pressed', self, 'on_toolbar_clicked', [EDIT_MODE.DeleteNodes])
	toolbar.get_node('AddEdges').connect('pressed', self, 'on_toolbar_clicked', [EDIT_MODE.AddEdges])
	toolbar.get_node('DeleteEdges').connect('pressed', self, 'on_toolbar_clicked', [EDIT_MODE.DeleteEdges])
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, toolbar)
	undo_redo = get_undo_redo()
	print('loaded graph plugin')
	make_visible(false)

func _exit_tree() -> void:  # override
	# clean up plugin
	remove_custom_type('DiGraph2D')
	remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, toolbar)
	toolbar.free()
	toolbar = null
	editing_node = null
	print('removed graph plugin')

# when a node is selected in the editor, this gets called. If the function returns true then make_visible and edit are called.
func handles(object: Object) -> bool:  # override
	return object.is_class('DiGraph2D')

# called when a DiGraph2D node is selected in the editor
func make_visible(visible: bool) -> void:  # override
	if visible:
		toolbar.show()
	else:
		toolbar.hide()
		editing_node = null

# called when a DiGraph2D node is selected in the editor
func edit(object: Object) -> void:  # override
	assert(handles(object))
	editing_node = object

func is_editing() -> bool:
	return editing_node != null and editing_node.is_inside_tree()

func forward_canvas_gui_input(event: InputEvent) -> bool:  # override
	var handled = false

	if !is_editing():
		return handled

	if event is InputEventMouseButton:
		var b = event.button_index

		if b == BUTTON_LEFT:
			mouse_pressed = event.pressed

		if event.pressed and b == BUTTON_LEFT:

			var closest_index = -1
			if cursor_pos_local != null:
				closest_index = editing_node.closest_node_to(cursor_pos_local, selection_radius_sq)

			if edit_mode == EDIT_MODE.AddNodes and cursor_pos_local != null:
				undo_redo.create_action('add_node')
				undo_redo.add_do_method(editing_node, 'add_node', cursor_pos_local)
				undo_redo.commit_action()
				handled = true

			elif edit_mode == EDIT_MODE.MoveNodes:
				if closest_index != -1:
					moving_node_index = closest_index
					handled = true

			elif edit_mode == EDIT_MODE.DeleteNodes:
				if closest_index != -1:
					undo_redo.create_action('remove_node')
					undo_redo.add_do_method(editing_node, 'remove_node', closest_index)
					undo_redo.commit_action()
					handled = true

			elif edit_mode == EDIT_MODE.AddEdges or edit_mode == EDIT_MODE.DeleteEdges:
				if closest_index != -1:
					if edge_start_node_index == -1:
						edge_start_node_index = closest_index
					else:
						var bidirectional = toolbar.get_node('Bidirectional').is_pressed()
						if edit_mode == EDIT_MODE.AddEdges:
							undo_redo.create_action('add_edge')
							undo_redo.add_do_method(editing_node, 'add_edge', edge_start_node_index, closest_index, bidirectional)
						elif edit_mode == EDIT_MODE.DeleteEdges:
							undo_redo.create_action('delete_edge')
							undo_redo.add_do_method(editing_node, 'remove_edge', edge_start_node_index, closest_index, bidirectional)
						undo_redo.commit_action()
						edge_start_node_index = -1
					handled = true

		if not event.pressed and b == BUTTON_LEFT:
			if edit_mode == EDIT_MODE.MoveNodes:
				if moving_node_index != -1:
					undo_redo.create_action('move_node')
					undo_redo.commit_action()
					moving_node_index = -1
					handled = true

		if event.pressed and b == BUTTON_RIGHT and cursor_pos_local != null:
			var closest = editing_node.get_closest_point_on_graph(cursor_pos_local, INF)
			set_cursor_pos(local_to_viewport_transform() * closest.point, false)
			update_overlays()

	elif event is InputEventMouseMotion:
		# position: origin at top left of viewport. global_position: origin at top left of window
		on_mouse_moved(event.position)

	return handled

func forward_canvas_draw_over_viewport(overlay: Control) -> void:  # override
	if !is_editing():
		return

	if cursor_pos_viewport != null:
		overlay.draw_circle(cursor_pos_viewport, 5.0, Color('#55000000'))

	if edge_start_node_index != -1 and cursor_pos_viewport != null:
		var start_pos = local_to_viewport_transform() * editing_node.get_node_pos(edge_start_node_index);
		overlay.draw_line(start_pos, cursor_pos_viewport, Color('#55ffffff'), 2.0, true)


func on_toolbar_clicked(new_mode: int) -> void:
	edit_mode = new_mode

func set_cursor_pos(viewport_pos, snap: bool = true) -> void:
	if viewport_pos == null:
		cursor_pos_viewport = null
		cursor_pos_local = null
	else:
		var t = local_to_viewport_transform()
		var new_pos_local = t.affine_inverse() * viewport_pos
		if snap:
			new_pos_local = snap_to_grid(new_pos_local)
		if new_pos_local != cursor_pos_local:
			cursor_pos_viewport = t * new_pos_local
			cursor_pos_local = new_pos_local
			update_overlays()

func on_mouse_moved(new_pos: Vector2) -> void:
	if !is_editing():
		return

	set_cursor_pos(new_pos)

	if edit_mode == EDIT_MODE.MoveNodes and mouse_pressed and moving_node_index != -1:
		editing_node.move_node(moving_node_index, cursor_pos_local)
		update_overlays()

	elif [EDIT_MODE.MoveNodes, EDIT_MODE.DeleteNodes, EDIT_MODE.AddEdges, EDIT_MODE.DeleteEdges].has(edit_mode):
		if cursor_pos_local != null:
			var closest_index = editing_node.closest_node_to(cursor_pos_local, selection_radius_sq)
			if closest_index != -1:
				set_cursor_pos(local_to_viewport_transform() * editing_node.get_node_pos(closest_index))
			else:
				set_cursor_pos(null)
		update_overlays()



# ---



func snap_to(v: float, step: float) -> float:
	return round(v / step) * step

func snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(snap_to(pos.x, snap_grid_size), snap_to(pos.y, snap_grid_size))

func local_to_viewport_transform() -> Transform2D:
	if !is_editing():
		return Transform2D()
	else:
		# https://docs.godotengine.org/en/3.1/tutorials/2d/2d_transforms.html
		return editing_node.get_viewport_transform() * editing_node.get_global_transform()

func viewport_to_local_transform() -> Transform2D:
	# note: affine_transform because the matrices may perform scaling
	return local_to_viewport_transform().affine_inverse()
