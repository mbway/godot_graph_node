tool
extends Node2D

const PathAlongGraph = preload('PathAlongGraph.gd')

export (String, MULTILINE) var _stored_adjacency = ""

# runtime data
var _nodes := PoolVector2Array()
var _adjacency := Array()

const node_color = Color('#ff9999ff')
const edge_color = Color('#55000000')

# cached data constructed using the above data

var _astar := AStar2D.new()
# the node indices of the line segments that make up the graph (bidirectional lines *not* included twice)
# this is to make projecting points onto the graph faster because each bidirectional edge is only considered once
var _line_segments := PoolIntArray()  # strided: [a, b, a, b, ...]


class Vertex:
	var id: int
	var pos: Vector2

	func _init(set_id: int, set_pos: Vector2):
		id = set_id
		pos = set_pos


class ClosestPointOnGraph:
	var a: int
	var b: int
	var point: Vector2

	func _init(set_a: int, set_b: int, set_point: Vector2):
		a = set_a
		b = set_b
		point = set_point


func _ready(): # override
	if _in_game():
		visible = false
	_load_saved_state()  # exported variables not available until added to the tree


# so that is_class can be used to determine whether a node is a DiGraph2D
func is_class(type):  # override
	return type == 'DiGraph2D' or .is_class(type)

func get_class():  # override
	return 'DiGraph2D'


func _load_saved_state():
	var new_nodes = PoolVector2Array()
	var new_adjacency = Array()
	var lines = _stored_adjacency.split('\n', false) # delimiter, allow_empty
	for line in lines:
		var words = line.split(' ', false)

		assert(words.size() >= 2)
		assert(words[0].is_valid_float())
		assert(words[1].is_valid_float())
		var x = words[0].to_float()
		var y = words[1].to_float()

		var adj = PoolIntArray()
		for i in range(2, words.size()):
			assert(words[i].is_valid_integer())
			adj.append(words[i].to_int())
		new_nodes.append(Vector2(x, y))
		new_adjacency.append(adj)
	_nodes = new_nodes
	_adjacency = new_adjacency
	_on_change(false)

func _save_state() -> void:
	if not is_valid():
		assert(is_valid())
		return
	_stored_adjacency = ""
	for i in range(num_nodes()):
		_stored_adjacency += "%f %f" % [_nodes[i].x, _nodes[i].y]
		for j in _adjacency[i]:
			_stored_adjacency += " %d" % j
		if i != num_nodes() - 1:
			_stored_adjacency += '\n'


# only called after update() is called, since otherwise the content is static
func _draw(): # override
	var num_nodes = _nodes.size()
	for i in range(num_nodes):
		for j in _adjacency[i]:
			var bidirectional = _has_edge(j, i)
			if i < j or not bidirectional:
				_draw_edge(_nodes[i], _nodes[j], bidirectional)

	for n in _nodes:
		draw_circle(n, 7.0, Color('#ff000000'))
		draw_circle(n, 5.0, node_color)

func _has_edge(from: int, to: int) -> bool:
	var adj = _adjacency[from]
	for other in adj:
		if other == to:
			return true
	return false

func _draw_edge(a: Vector2, b: Vector2, bidirectional: bool):
	draw_line(a, b, edge_color, 2.0, true)  # line width, AA
	var ab = b - a
	var v = ab.normalized()
	var arrow_width = 8
	var arrow_length = 0.1 * ab.length()
	if not bidirectional:
		var arrow_top = a + 0.5 * ab
		var arrow_bottom = arrow_top - arrow_length * v
		var arrow_perp_offset = arrow_width * _perpendicular_vector(v)
		draw_line(arrow_top, arrow_bottom + arrow_perp_offset, edge_color, 2, true)
		draw_line(arrow_top, arrow_bottom - arrow_perp_offset, edge_color, 2, true)

func _update_astar():
	_astar = AStar2D.new()

	for i in range(_nodes.size()):
		_astar.add_point(i, _nodes[i], 1.0) # id, position, weight_scale

	# need to add all nodes before adding edges
	for i in range(_nodes.size()):
		for j in _adjacency[i]:
			var bidirectional = _has_edge(j, i)
			if i < j or not bidirectional:
				_astar.connect_points(i, j, bidirectional)

func _update_line_segments():
	_line_segments = PoolIntArray()
	for i in range(_adjacency.size()):
		for j in _adjacency[i]:
			var bidirectional = _has_edge(j, i)
			if i < j or not bidirectional:
				_line_segments.append(i)
				_line_segments.append(j)

func _project_and_add(point: Vector2) -> Object: # Optional<Vertex>
	var point_on_graph = get_closest_point_on_graph(point)
	if point_on_graph == null:
		return null
	var id = _astar.get_available_point_id()
	_astar.add_point(id, point_on_graph.point, 1.0)
	var bidirectional = _has_edge(point_on_graph.b, point_on_graph.a)
	_astar.connect_points(point_on_graph.a, id, bidirectional)
	_astar.connect_points(id, point_on_graph.b, bidirectional)
	return Vertex.new(id, point_on_graph.point)

# whether the 'to_point' lies on any of the outgoing edges from the 'from' vertex in the astar graph
func _point_directly_reachable(from: Vertex, to_point: Vector2, tolerance: float = 1e-3) -> bool:
	for neighbour_id in _astar.get_point_connections(from.id):
		var b = _astar.get_point_position(neighbour_id)
		var projected = Geometry.get_closest_point_to_segment_2d(to_point, from.pos, Vector2(b.x, b.y))
		if projected.distance_squared_to(to_point) < tolerance:
			return true
	return false

func is_valid() -> bool:
	var num_nodes = _nodes.size()
	if num_nodes != _adjacency.size():
		printerr("_nodes and _adjacency have different lengths: ", num_nodes, " != ", _adjacency.size())
		return false
	for i in range(_adjacency.size()):
		var seen = []
		for j in _adjacency[i]:
			if j >= num_nodes:
				printerr("edge to non-existent node: ", i, "->", j, ". num_nodes=", num_nodes())
				return false
			elif j == i:
				printerr("self-loop: ", i, "->", j)
				return false
			elif j in seen:
				printerr("multi-edge: ", i, "->", j)
				return false
			seen.append(j)

	if _astar.get_points() != range(_nodes.size()):
		printerr("astar nodes do not match graph nodes")
		return false
	return true

func num_nodes() -> int:
	return _nodes.size()

func get_node_positions() -> PoolVector2Array:
	return _nodes

func get_node_pos(index: int) -> Vector2:
	return _nodes[index]


# Interface used for path finding


# find the closest point on any of the edges of the graph to the given point
func get_closest_point_on_graph(pos: Vector2, max_distance_sq: float = INF) -> Object: # Optional<ClosestPointOnGraph>
	var closest_point_on_edge = null
	var closest_distance_sq = INF

	for edge in range(0, _line_segments.size(), 2):
		var i = _line_segments[edge]
		var j = _line_segments[edge + 1]
		var point_on_edge = Geometry.get_closest_point_to_segment_2d(pos, _nodes[i], _nodes[j])
		var distance_sq = pos.distance_squared_to(point_on_edge)
		if distance_sq < closest_distance_sq and distance_sq < max_distance_sq:
			closest_point_on_edge = ClosestPointOnGraph.new(i, j, point_on_edge)
			closest_distance_sq = distance_sq

	return closest_point_on_edge


func get_shortest_path(from: Vector2, to: Vector2) -> PathAlongGraph:
	var path = PathAlongGraph.new()

	var from_on_graph = _project_and_add(from)
	if from_on_graph == null:
		return path
	var to_on_graph = _project_and_add(to)
	if to_on_graph == null:
		_astar.remove_point(from_on_graph.id)
		return path

	path.append(from_on_graph.pos)

	if not _point_directly_reachable(from_on_graph, to_on_graph.pos):
		var id_path = _astar.get_id_path(from_on_graph.id, to_on_graph.id)
		for id in id_path:
			if id == from_on_graph.id or id == to_on_graph.id:
				continue
			else:
				path.append(_nodes[id], id)

	path.append(to_on_graph.pos)

	_astar.remove_point(from_on_graph.id)
	_astar.remove_point(to_on_graph.id)
	return path


func get_neighbour_ids(node_id: int) -> PoolIntArray:
	return PoolIntArray() if node_id == -1 else _adjacency[node_id]


# Interface used by the tool for editing

func _valid_id(id: int) -> bool:
	var n = num_nodes()
	return id >= 0 and id < n

func _valid_ids(id_a: int, id_b: int) -> bool:
	var n = num_nodes()
	return id_a >= 0 and id_a < n and id_b >= 0 and id_b < n


func _on_change(save_changes: bool = true) -> void:
	_update_astar()
	_update_line_segments()
	assert(is_valid())
	if save_changes:
		_save_state()
	update()  # redraw if visible

func add_node(pos: Vector2) -> int:
	var new_node_id = _nodes.size()
	_nodes.push_back(pos)
	_adjacency.push_back(PoolIntArray())
	_on_change()
	return new_node_id

func move_node(index: int, pos: Vector2) -> void:
	if not _valid_id(index):
		printerr("invalid id: ", index)
		return
	_nodes.set(index, pos)
	_on_change()

func remove_node(index: int) -> void:
	if not _valid_id(index):
		printerr("invalid id: ", index)
		return
	_nodes.remove(index)
	_adjacency.remove(index)
	for n in range(_adjacency.size()):
		var adj = _adjacency[n]
		var i = 0
		while i < len(adj):  # cannot use for loop since array may change length
			var val = adj[i]
			if val == index:
				adj.remove(i)
				continue  # do not increment i
			elif val > index:
				# shift all the indices above the removed node down
				adj.set(i, val - 1)
			i += 1
		_adjacency[n] = adj
	_on_change()

func _add_edge(from: int, to: int) -> bool:
	if _has_edge(from, to):
		print("edge ", from, "->", to, " already exists")
		return false
	else:
		# appending in place does not take effect and _adjacency[from] would remain unchanged
		var a = _adjacency[from]
		a.push_back(to)
		_adjacency[from] = a
		return true

func add_edge(from: int, to: int, bidirectional: bool) -> void:
	if from == to:
		printerr("cannot add a self loop to the graph")
		return
	elif not _valid_ids(from, to):
		printerr("invalid edge ids: ", from, ", ", to)
		return

	var changed = _add_edge(from, to)
	if bidirectional:
		changed = _add_edge(to, from) or changed

	if changed:
		_on_change()

func remove_edge(from: int, to: int, bidirectional: bool) -> void:
	if not _valid_ids(from, to):
		printerr("invalid edge ids: ", from, ", ", to)
		return
	var adj = _adjacency[from]
	for i in range(len(adj)):
		if adj[i] == to:
			adj.remove(i)
			_adjacency[from] = adj
			break
	if bidirectional:
		remove_edge(to, from, false)
	_on_change()

func closest_node_to(pos: Vector2, max_radius_sq: float = INF) -> int:
	var min_index = -1
	var min_distance_sq = INF
	for i in range(_nodes.size()):
		var distance_sq = _nodes[i].distance_squared_to(pos)
		if distance_sq < min_distance_sq and distance_sq < max_radius_sq:
			min_index = i
			min_distance_sq = distance_sq
	return min_index

# Utils

static func _perpendicular_vector(vec: Vector2) -> Vector2:
	return Vector2(vec.y, -vec.x)

static func _in_game() -> bool:
	return not Engine.editor_hint
