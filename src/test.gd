extends SceneTree

var DiGraph2D = preload("DiGraph2D.gd")

func _init():
    print('testing graph node')

    test_bug()
    #quit()
    #return

    #test_instances_independent()
    #test_basics()
    #test_editing()
    #test_loading_and_saving()
    #test_path_finding()

    quit()

func _heading(message: String):
    print("\n# TESTING: %s" % message)

func test_instances_independent():
    _heading('separate instances')
    # godot has a very stupid design decision whereby exported arrays are shared between all instances!!!

    var graph1 = DiGraph2D.new()
    var graph2 = DiGraph2D.new()

    assert(graph1.num_nodes() == 0)
    assert(graph2.num_nodes() == 0)
    assert(graph1._adjacency.size() == 0)
    assert(graph2._adjacency.size() == 0)

    var id_a = graph1.add_node(Vector2(0, 0))

    assert(graph1.num_nodes() == 1)
    assert(graph2.num_nodes() == 0)
    assert(graph1._adjacency.size() == 1)
    assert(graph2._adjacency.size() == 0)

    var id_b = graph1.add_node(Vector2(1, 0))
    graph1.add_edge(id_a, id_b, false)

    assert(graph1.num_nodes() == 2)
    assert(graph2.num_nodes() == 0)
    assert(graph1._adjacency.size() == 2)
    assert(graph1._adjacency[0].size() == 1)
    assert(graph1._adjacency[1].size() == 0)
    assert(graph2._adjacency.size() == 0)

    graph1.queue_free()
    graph2.queue_free()


func test_basics():
    _heading("basics")
    var graph = DiGraph2D.new()
    assert(graph._in_game())
    assert(graph.is_class("DiGraph2D"))
    assert(graph.get_class() == "DiGraph2D")

    assert(graph.closest_node_to(Vector2(100, 100)) == -1)
    assert(graph.num_nodes() == 0)
    assert(graph.is_valid())

    assert(graph.get_neighbour_ids(-1) == PoolIntArray())

    var id = graph.add_node(Vector2(0, 0))
    assert(graph.is_valid())
    assert(graph.get_node_pos(id) == Vector2(0, 0))
    assert(graph.num_nodes() == 1)

    assert(graph.closest_node_to(Vector2(100, 100)) == id)

    assert(graph.get_closest_point_on_graph(Vector2(0, 0)) == null)
    var path = graph.get_shortest_path(Vector2(0, 0), Vector2(1, 1))
    assert(path.points == [])
    assert(path.ids == [])

    assert(graph.get_neighbour_ids(id) == PoolIntArray())

    graph.queue_free()  # currently required to avoid 'ObjectDB Instances still exist' (which could be a Godot bug)


func test_editing():
    _heading("editing")
    var graph = DiGraph2D.new()

    var id_a = graph.add_node(Vector2(1, 2))
    assert(graph.is_valid())
    assert(graph.get_node_pos(id_a) == Vector2(1, 2))
    assert(graph.num_nodes() == 1)

    graph.move_node(id_a, Vector2(0, 0))
    assert(graph.is_valid())
    assert(graph.get_node_pos(id_a) == Vector2(0, 0))

    var id_b = graph.add_node(Vector2(1, 0))
    assert(graph.is_valid())
    assert(graph.get_neighbour_ids(id_a) == PoolIntArray())

    graph.add_edge(id_a, id_b, false)
    assert(graph.is_valid())
    assert(graph.get_neighbour_ids(id_a) == PoolIntArray([id_b]))
    assert(graph.get_neighbour_ids(id_b) == PoolIntArray([]))

    # multi-edges are ignored
    print("expected: message about the edge ", id_a, "->", id_b, " already existing {")
    graph.add_edge(id_a, id_b, false)
    print("}")
    assert(graph.is_valid())
    assert(graph.get_neighbour_ids(id_a) == PoolIntArray([id_b]))
    assert(graph.get_neighbour_ids(id_b) == PoolIntArray([]))

    print("expected: message about the edge ", id_a, "->", id_b, " already existing {")
    graph.add_edge(id_b, id_a, true)
    print("}")
    assert(graph.is_valid())
    assert(graph.get_neighbour_ids(id_a) == PoolIntArray([id_b]))
    assert(graph.get_neighbour_ids(id_b) == PoolIntArray([id_a]))
    graph.remove_edge(id_b, id_a, false)
    assert(graph.is_valid())
    assert(graph.get_neighbour_ids(id_a) == PoolIntArray([id_b]))
    assert(graph.get_neighbour_ids(id_b) == PoolIntArray([]))

    print("expected: message about invalid ids {")
    graph.add_edge(99, 0, true)
    graph.add_edge(-1, 0, true)
    graph.remove_edge(100, 0, true)
    graph.move_node(100, Vector2(0, 0))
    graph.remove_node(100)
    print("}")
    assert(graph.is_valid())
    assert(graph.num_nodes() == 2)
    assert(graph.get_neighbour_ids(id_a) == PoolIntArray([id_b]))
    assert(graph.get_neighbour_ids(id_b) == PoolIntArray([]))


    var id_c = graph.add_node(Vector2(2, 0))
    graph.add_edge(id_a, id_c, true)
    assert(graph.is_valid())
    assert(graph.get_neighbour_ids(id_a) == PoolIntArray([id_b, id_c]))
    assert(graph.get_neighbour_ids(id_b) == PoolIntArray([]))
    assert(graph.get_neighbour_ids(id_c) == PoolIntArray([id_a]))

    graph.remove_edge(id_c, id_a, false)
    assert(graph.is_valid())
    assert(graph.get_neighbour_ids(id_a) == PoolIntArray([id_b, id_c]))
    assert(graph.get_neighbour_ids(id_b) == PoolIntArray([]))
    assert(graph.get_neighbour_ids(id_c) == PoolIntArray([]))

    assert(graph.closest_node_to(Vector2(1, 2)) == id_b)
    assert(graph.closest_node_to(Vector2(1, 2), 1) == -1)

    graph.remove_node(id_b)

    assert(graph.is_valid())
    # ids do not persist across node removals
    assert(graph.get_neighbour_ids(0) == PoolIntArray([1]))
    assert(graph.get_neighbour_ids(1) == PoolIntArray([]))
    assert(graph.num_nodes() == 2)
    assert(graph.get_node_pos(0) == Vector2(0, 0))
    assert(graph.get_node_pos(1) == Vector2(2, 0))

    graph.queue_free()  # currently required to avoid 'ObjectDB Instances still exist' (which could be a Godot bug)


func test_loading_and_saving():
    _heading("loading and saving")
    var graph = DiGraph2D.new()

    assert(graph._stored_adjacency == "")
    graph._load_saved_state()
    assert(graph.is_valid())
    graph._save_state()
    assert(graph._stored_adjacency == "")

    graph.add_node(Vector2(1, 3))
    graph.add_node(Vector2(2, 2))
    graph.add_node(Vector2(3, 1))
    graph.add_edge(0, 1, true)
    graph.add_edge(2, 0, false)
    assert(graph._stored_adjacency == "1.000000 3.000000 1\n2.000000 2.000000 0\n3.000000 1.000000 0")

    var stored_data ="1 2 1\n3 2\n4 4 0"
    graph._stored_adjacency = stored_data
    graph._load_saved_state()
    assert(graph.is_valid())
    assert(Array(graph._nodes) == [Vector2(1, 2), Vector2(3, 2), Vector2(4, 4)])
    assert(Array(graph._adjacency[0]) == [1])
    assert(Array(graph._adjacency[1]) == [])
    assert(Array(graph._adjacency[2]) == [0])
    assert(graph._stored_adjacency == stored_data)
    graph._save_state()
    var stored_data_generated = "1.000000 2.000000 1\n3.000000 2.000000\n4.000000 4.000000 0"
    assert(graph._stored_adjacency == stored_data_generated)

    # if the stored data is invalid then the runtime data is unchanged
    graph._stored_adjacency = "a b"  # invalid
    print("expected: assertion error {")
    graph._load_saved_state()
    print("}")
    assert(graph.is_valid())
    graph._save_state()
    assert(graph._stored_adjacency == stored_data_generated)

    # if the graph is invalid then the stored data is unchanged
    graph._nodes = PoolVector2Array()
    print("expected: problems {")
    assert(not graph.is_valid())
    graph._save_state()
    print("}")
    assert(graph._stored_adjacency == stored_data_generated)

    graph.queue_free()  # currently required to avoid 'ObjectDB Instances still exist' (which could be a Godot bug)

func vectors_equal(a: Array, b: Array, tolerance: float = 1e-3) -> bool:
    if a.size() != b.size():
        return false
    for i in range(a.size()):
        if a[i].distance_squared_to(b[i]) >= tolerance:
            return false
    return true

func test_bug():
    var graph = DiGraph2D.new()
    var path

    graph.add_node(Vector2(0, 0))
    graph.add_node(Vector2(1, 0))
    graph.add_edge(1, 0, false)

    path = graph.get_shortest_path(Vector2(0.1, 0.1), Vector2(0.9, 0.1))
    path = graph.get_shortest_path(Vector2(0.1, 0.1), Vector2(0.9, 0.1))

    graph.queue_free()

func test_path_finding():
    _heading("path finding")
    var graph = DiGraph2D.new()
    var path

    # if there are no edges then the points cannot be projected and so 
    path = graph.get_shortest_path(Vector2(0, 1), Vector2(2, 3))
    assert(path.points == [])
    assert(path.ids == [])

    graph.add_node(Vector2(0, 0))
    graph.add_node(Vector2(1, 0))
    graph.add_node(Vector2(2, 0))
    graph.add_node(Vector2(0.5, -0.5))
    graph.add_node(Vector2(1, 1))
    graph.add_edge(0, 1, true)
    graph.add_edge(2, 1, false)
    graph.add_edge(1, 3, false)
    graph.add_edge(3, 0, false)
    graph.add_edge(4, 1, false)

    assert(Array(graph.get_neighbour_ids(0)) == [1])
    assert(Array(graph.get_neighbour_ids(1)) == [0, 3])
    assert(Array(graph.get_neighbour_ids(3)) == [0])

    assert(graph.get_closest_point_on_graph(Vector2(10, 10), 1) == null)
    var closest = graph.get_closest_point_on_graph(Vector2(1.1, 0.5), 1)
    assert(closest.point == Vector2(1.0, 0.5))
    assert(closest.a == 4)
    assert(closest.b == 1)

    closest = graph.get_closest_point_on_graph(Vector2(0.5, 0.1))
    assert(closest.point == Vector2(0.5, 0.0))
    assert((closest.a == 0 and closest.b == 1) or (closest.a == 1 and closest.b == 0))

    # if directly connected: go straight for the destination
    path = graph.get_shortest_path(Vector2(0.4, -0.4), Vector2(0.1, -0.1))
    assert(graph.is_valid())
    assert(vectors_equal(path.points, [Vector2(0.4, -0.4), Vector2(0.1, -0.1)]))
    assert(path.ids == [-1, -1])

    # if on the same edge but not directly connected: have to go the long way round
    path = graph.get_shortest_path(Vector2(0.1, -0.1), Vector2(0.4, -0.4))
    assert(graph.is_valid())
    var expected = [Vector2(0.1, -0.1), Vector2(0, 0), Vector2(1, 0), Vector2(0.5, -0.5), Vector2(0.4, -0.4)]
    assert(vectors_equal(path.points, expected))
    assert(path.ids == [-1, 0, 1, 3, -1])
    #print(graph._astar_adjacency(graph._astar))

    # directly connected (bidirectional edge)
    path = graph.get_shortest_path(Vector2(0.1, 0.1), Vector2(0.9, 0.1))
    assert(graph.is_valid())
    assert(path.points == [Vector2(0.1, 0), Vector2(0.9, 0)])
    assert(path.ids == [-1, -1])
    path = graph.get_shortest_path(Vector2(0.9, 0.1), Vector2(0.1, 0.1))
    assert(graph.is_valid())
    assert(path.points == [Vector2(0.9, 0), Vector2(0.1, 0)])
    assert(path.ids == [-1, -1])

    # if there is no path then return the two projected points
    path = graph.get_shortest_path(Vector2(1.1, 0.2), Vector2(1.1, 0.9))
    assert(graph.is_valid())
    assert(vectors_equal(path.points, [Vector2(1, 0.2), Vector2(1, 0.9)]))
    assert(path.ids == [-1, -1])

    print('bad search')
    print('stuff')
    path = graph.get_shortest_path(Vector2(1.1, 0.9), Vector2(1.9, 0.1))
    print('bad search finished')
    #assert(graph.is_valid())
    #assert(vectors_equal(path.points, [Vector2(1, 0.9), Vector2(1.9, 0)]))
    #assert(path.ids == [-1, -1])

    


    graph.queue_free()  # currently required to avoid 'ObjectDB Instances still exist' (which could be a Godot bug)
