extends Node
class_name Main

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
	GOAL1,
	GOAL2,
	GOAL3,
}

var counts := {CellType.GOAL1: 0, CellType.GOAL2: 0, CellType.GOAL3: 0}

@onready var image := Image.create(width, height, false, Image.FORMAT_RGBAF)
@onready var grid_sprite := $GridTex
var gravity_dir := Vector2i.DOWN

func _ready():
	grid.resize(width * height)
	grid.fill(CellType.AIR)
	
	for i in range(width * int(height / 1.2), width * height):
		grid[i] = CellType.GRASS
	
	var emitter_start := height * int(float(width) / 2.0)
	var emitter_end := height * int(float(width) / 1.5)
	for i in range(emitter_start, emitter_end, width):
		for n in range(i + 100, i + 135):
			grid[n] = CellType.GOAL1
	
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
				elif cell >= CellType.GOAL1:
					if counts[cell] < 100:
						image.set_pixel(col, row, Color.BROWN)
					else:
						image.set_pixel(col, row, Color.GREEN)
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
	grid[width * height / 2 + 30] = 1 #warning-ignore:integer_division

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
			elif cell == CellType.GOAL1:
				new_grid[(row * width) + col] = CellType.GOAL1

	grid = new_grid

func move_cell(row, col, new_grid) -> bool:
	var current = (row * width) + col
	assert(grid[current] == CellType.SAND)
	var below = ((row + gravity_dir.y) * width) + col
	
	var next_cell := int(below)
	if can_move(Vector2i(col, row), gravity_dir):
		if handle_movement(new_grid, current, next_cell): return true

	if row + 1 >= height:
		return false
	if col + 1 >= width or col - 1 < 0:
		return false

	var dir = 1 if randi_range(0, 1) == 1 else -1
	next_cell = below + dir
	if can_move(Vector2i(col, row), Vector2i(dir, gravity_dir.y)):
		if handle_movement(new_grid, current, next_cell): return true

	next_cell = below - dir
	if can_move(Vector2i(col, row), Vector2i(-dir, gravity_dir.y)):
		if handle_movement(new_grid, current, next_cell): return true
	return false

func handle_movement(new_grid: PackedByteArray, current: int, next_cell: int) -> bool:
	assert(grid[current] == CellType.SAND, "sand????????")
	if grid[next_cell] >= CellType.GOAL1:
		counts[grid[next_cell]] += 1
		counts[grid[next_cell]] = clamp(counts[grid[next_cell]], 0, 100)
		#print(counts[grid[next_cell]])
		new_grid[current] = CellType.AIR
		return true
	elif grid[next_cell] == CellType.AIR:
		grid[next_cell] = CellType.RESERVED
		new_grid[next_cell] = grid[current]
		return true
	return false

# Rules for SAND particle movement
# - Can move down into AIR
# - Can move diagonally downward into AIR if:
#   - Cell on side is AIR or...
#   - Cell below is SAND
# - If moves into GOAL cell
#   - Remove sand
#   - Increment count
func can_move(from: Vector2i, dir: Vector2i) -> bool:
	var new_pos = from + dir
	if grid[new_pos.y * width + new_pos.x] != CellType.AIR and \
	   grid[new_pos.y * width + new_pos.x] < CellType.GOAL1: 
		return false
	if dir == gravity_dir: return true
	if dir == Vector2i(1, gravity_dir.y) or dir == Vector2i(-1, gravity_dir.y):
		if grid[from.y * width + from.x + dir.x] == CellType.AIR or \
		   grid[from.y * width + from.x + dir.x] >= CellType.GOAL1: 
			return true
		if grid[(from.y + gravity_dir.y) * width + from.x] == CellType.SAND: return true
	return false
