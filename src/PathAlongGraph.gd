# pooled arrays are slower for allocating
var points: Array
var ids: Array

func _init():
	points = []
	ids = []

func append(pos: Vector2, id: int = -1) -> void:
	points.append(pos)
	ids.append(id)
