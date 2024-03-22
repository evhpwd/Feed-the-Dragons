extends Node

var grid := PackedByteArray()
var changed = false
const height = 200
const width = 300
var spawn = 0

enum CellType {
	AIR,
	SAND,
	GRASS,
	RESERVED,
}

@onready var image = Image.create(width, height, false, Image.FORMAT_RGB8)
@onready var grid_sprite = $GridTex
var gravity_dir := Vector2i.DOWN

## Gets the value of a cell on the [member grid]
func get_cell(pos: Vector2i) -> CellType:
	return grid[pos.y * width + pos.x] as CellType

func _ready():
	grid.resize(width * height)
	grid.fill(CellType.AIR)
	
	for i in range(width * (height / 2), width * height):
		grid[i] = CellType.GRASS

	grid_sprite.texture = ImageTexture.create_from_image(image)
	grid_sprite.size = get_viewport().size
	
	Input.use_accumulated_input = false

func _process(_delta):
	if changed:
		for row in range(0, height):
			for col in range(0, width):
				var cell = grid[(row * width) + col]
				if cell == CellType.SAND:
					image.set_pixel(col, row, Color.SANDY_BROWN)
				elif cell == CellType.GRASS:
					image.set_pixel(col, row, Color.SEA_GREEN)
				elif cell == CellType.AIR:
					image.set_pixel(col, row, Color.SKY_BLUE)
		grid_sprite.texture.update(image)
		changed = false

func _input(event):
	if event is InputEventKey and event.is_action_pressed("swap_gravity"):
		gravity_dir = Vector2i(0, -gravity_dir.y)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var viewport = get_viewport()
		if (
			event.position.x < 0 or event.position.y < 0 or \
			event.position.x >= viewport.size.x or event.position.y >= viewport.size.y
		):
			return
		var viewport_to_grid = Vector2(
			float(width) / float(viewport.size.x),
			float(height) / float(viewport.size.y)
		)

		var last_point = event.position - event.relative
		var points = bresenhams_line(last_point, event.position)
		for position in points:
			position.x *= viewport_to_grid.x
			position.y *= viewport_to_grid.y

			if grid[(position.y * width) + position.x] == CellType.AIR:
				grid[(position.y * width) + position.x] = CellType.GRASS

func bresenhams_line(point1, point2):
	var points = []
	var dx = abs(point2[0] - point1[0])
	var dy = -abs(point2[1] - point1[1])
	var err = dx + dy
	var e2 = 2 * err
	var sx = 1 if point1[0] < point2[0] else -1
	var sy = 1 if point1[1] < point2[1] else -1
	while true:
		points.append(Vector2i(point1[0], point1[1]))
		if point1[0] == point2[0] and point1[1] == point2[1]:
			break
		e2 = 2 * err
		if e2 >= dy:
			err += dy
			point1[0] += sx
		if e2 <= dx:
			err += dx
			point1[1] += sy
	return points

func _physics_process(_delta):
	changed = true
	grid[int(width * 80.5) + randi() % 100] = 1
	grid[width * 80 + 30] = 1

	var new_grid := PackedByteArray()
	new_grid.resize(width * height)
	new_grid.fill(CellType.AIR)

	for row in range(height):
		for col in range(width):
			var cell = grid[(row * width) + col]
			if cell == CellType.SAND:
				if not move_cell(row, col, new_grid):
					new_grid[(row * width) + col] = CellType.SAND
			elif cell == CellType.GRASS:
				new_grid[(row * width) + col] = CellType.GRASS
			elif cell == CellType.AIR: pass

	grid = new_grid

func move_cell(row, col, new_grid):
	var current = (row * width) + col
	var below = ((row + gravity_dir.y) * width) + col
	
	if can_move(Vector2i(col, row), gravity_dir):
		new_grid[below] = grid[current]
		return true

	if row + 1 >= height:
		return false
	if col + 1 >= width or col - 1 < 0:
		return false

	var dir = 1 if randi_range(0, 1) == 1 else -1
	if can_move(Vector2i(col, row), Vector2i(dir, gravity_dir.y)):
		grid[below + dir] = CellType.RESERVED
		new_grid[below + dir] = grid[current]
		return true

	if can_move(Vector2i(col, row), Vector2i(-dir, gravity_dir.y)):
		grid[below - dir] = CellType.RESERVED
		new_grid[below - dir] = grid[current]
		return true

	return false

# Rules for SAND particle movement
# - Can move down into AIR
# - Can move diagonally downward into AIR if:
#   - Cell on side is AIR or...
#   - Cell below is SAND
func can_move(from: Vector2i, dir: Vector2i) -> bool:
	var new_pos = from + dir
	if get_cell(new_pos) != CellType.AIR: return false
	if dir == gravity_dir: return true
	if dir == Vector2i(1, gravity_dir.y) or dir == Vector2i(-1, gravity_dir.y):
		var adj_dir = Vector2i(dir.x, 0)
		var adj = from + adj_dir
		if get_cell(adj) == CellType.AIR: return true
		if get_cell(from + gravity_dir) == CellType.SAND: return true
	return false
