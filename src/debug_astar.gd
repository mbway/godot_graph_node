var astar: AStar

func _init():
    print('New AStar instance')
    astar = AStar.new()

func get_points():
    print('get_points()')
    return astar.get_points()

func add_point(id, position, weight_scale = 1.0):
    print('add_point(', id, ', Vector3', position, ', ', weight_scale, ')')
    return astar.add_point(id, position, weight_scale)

func remove_point(id):
    print('remove_point(', id, ')')
    return astar.remove_point(id)

func get_point_position(id):
    print('get_point_position(', id, ')')
    return astar.get_point_position(id)

func connect_points(id, to_id, bidirectional = true):
    print('connect_points(', id, ', ', to_id, ', ', ('true' if bidirectional else 'false'), ')')
    return astar.connect_points(id, to_id, bidirectional)

func get_available_point_id():
    print('get_available_point_id()')
    return astar.get_available_point_id()

func get_point_connections(id):
    print('get_point_connections(', id, ')')
    return astar.get_point_connections(id)

func get_id_path(from_id, to_id):
    print('get_id_path(', from_id, ', ', to_id, ')')
    return astar.get_id_path(from_id, to_id)


static func astar_adjacency(astar: AStar) -> Dictionary:
	var out = {}
	for i in range(astar.get_available_point_id()):
		if(astar.has_point(i)):
			out[i] = {
				"pos": astar.get_point_position(i),
				"adj": Array(astar.get_point_connections(i))
			}
	return out

static func astar_from_adjacency(adjacency: Dictionary) -> AStar:
	var astar = AStar.new()
	for id in adjacency.keys():
		var node = adjacency[id]
		astar.add_point(id, node['pos'], 1.0)
	# add all nodes before adding edges
	for id in adjacency.keys():
		var node = adjacency[id]
		for other_id in node['adj']:
			astar.connect_points(id, other_id, false)
	return astar
