extends SceneTree

# This crashes Godot 3.1 but is fixed by 3.2

func _init():
    var DiGraph2D = preload("DiGraph2D.gd")
    var graph = DiGraph2D.new()

    graph.add_node(Vector2(0, 0))
    graph.add_node(Vector2(1, 0))
    graph.add_edge(1, 0, false)

    var path1 = graph.get_shortest_path(Vector2(0.1, 0.1), Vector2(0.9, 0.1))
    var path2 = graph.get_shortest_path(Vector2(0.1, 0.1), Vector2(0.9, 0.1))

    graph.queue_free()

    quit()
