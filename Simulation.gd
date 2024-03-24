extends Node
class_name Simulation

var grid := PackedByteArray()
var changed := false
const width := 300
const height := 200
var emitter = null

enum CellType {
	AIR,
	SAND,
	GRASS,
	GOAL1,
	GOAL2,
	GOAL3,
	EMITTER,
	# Cells below this point aren't available in level editor
	RESERVED,
	LENGTH,
}

var counts := {CellType.GOAL1: 0, CellType.GOAL2: 0, CellType.GOAL3: 0}
var brush_type := CellType.GRASS

@onready var image := Image.create(width, height, false, Image.FORMAT_RGBAF)
@onready var grid_sprite := $GridTex
var gravity_dir := Vector2i.DOWN
var cell_colors: Array

func _ready():
	cell_colors.resize(CellType.LENGTH)
	cell_colors[CellType.SAND] = Color.SANDY_BROWN
	cell_colors[CellType.GRASS] = Color.SEA_GREEN
	cell_colors[CellType.AIR] = Color.SKY_BLUE
	cell_colors[CellType.EMITTER] = cell_colors[CellType.AIR]

	grid_sprite.texture = ImageTexture.create_from_image(image)
	grid_sprite.size = get_viewport().size
	
	# Poll mouse more frequently for smoother lines
	Input.use_accumulated_input = false


func _process(_delta):
	if changed:
		for row in range(0, height):
			for col in range(0, width):
				var cell := grid[(row * width) + col]
				var color = cell_colors[cell]
				if color != null:
					image.set_pixel(col, row, color)
				elif cell >= CellType.GOAL1 && cell <= CellType.GOAL3:
					if counts[cell] < 100:
						image.set_pixel(col, row, Color.BROWN)
					else:
						image.set_pixel(col, row, Color.GREEN)
		grid_sprite.texture.update(image)
		changed = false

func reset():
	emitter = null
	gravity_dir = Vector2i.DOWN
	for i in counts:
		counts[i] = 0

func load_level(level: Dictionary):
	grid.resize(width * height)
	grid.fill(CellType.AIR)
	# emitter = level.get("emitter")
	for cell_type: CellType in level.get("blocks", {}):
		for pos: Array in level["blocks"][cell_type]:
			grid[pos[1] * width + pos[0]] = cell_type

func load_editor():
	grid.resize(width * height)
	grid.fill(CellType.AIR)
	changed = true

##Maps viewport coordinates (i.e. from a click) to the corresponding grid position
func viewport_to_grid(pos: Vector2i) -> Vector2i:
	var viewport := get_viewport()
	var mapping = Vector2(
		float(width) / float(viewport.size.x),
		float(height) / float(viewport.size.y)
	)
	pos.x *= mapping.x
	pos.y *= mapping.y
	return pos

func _input(event):
	var viewport = get_viewport()
	var old_cell_type: CellType
	var new_cell_type: CellType
	if event is InputEventKey and event.is_action_pressed("swap_gravity"):
		gravity_dir = Vector2i(0, -gravity_dir.y)
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			old_cell_type = CellType.AIR
			new_cell_type = brush_type
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			old_cell_type = brush_type
			new_cell_type = CellType.AIR
		if (
			event.position.x < 0 or event.position.y < 0 or \
			event.position.x >= viewport.size.x or event.position.y >= viewport.size.y
		):
			return

		var last_point = event.position - event.relative
		var points = bresenhams_line(last_point, event.position)
		for position in points:
			var mapped := viewport_to_grid(position)
			if mapped.y >= height or mapped.x >= width:
				continue
			if grid[(mapped.y * width) + mapped.x] == old_cell_type:
				grid[(mapped.y * width) + mapped.x] = new_cell_type
		changed = true
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			old_cell_type = CellType.AIR
			new_cell_type = brush_type
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			old_cell_type = brush_type
			new_cell_type = CellType.AIR
		else:
			return
		var mapped := viewport_to_grid(event.position)
		if mapped.y >= height or mapped.x >= width:
			return
		if grid[(mapped.y * width) + mapped.x] == old_cell_type:
			grid[(mapped.y * width) + mapped.x] = new_cell_type
			changed = true

func bresenhams_line(point1: Vector2i, point2: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var d := (point2 - point1).abs()
	var dx := d.x
	var dy := -d.y
	var err := dx + dy
	var e2 := 2 * err
	var sx := 1 if point1.x < point2.x else -1
	var sy := 1 if point1.y < point2.y else -1
	while true:
		points.append(point1)
		if point1 == point2:
			break
		e2 = 2 * err
		if e2 >= dy:
			err += dy
			point1.x += sx
		if e2 <= dx:
			err += dx
			point1.y += sy
	return points

func _physics_process(_delta):
	changed = true
	if emitter != null:
		grid[emitter.y * width + emitter.x] = 1

	var new_grid := PackedByteArray()
	new_grid.resize(width * height)
	new_grid.fill(CellType.AIR)

	for row in range(height):
		for col in range(width):
			var pos := (row * width) + col
			var cell := grid[pos]
			if cell == CellType.SAND:
				if not move_cell(row, col, new_grid):
					new_grid[pos] = CellType.SAND
			elif cell == CellType.GRASS:
				new_grid[pos] = cell
			elif cell >= CellType.GOAL1 and cell <= CellType.GOAL3:
				new_grid[pos] = cell
	grid = new_grid

func move_cell(row: int, col: int, new_grid: PackedByteArray) -> bool:
	# 'Fall off' top and bottom of screen
	if (row + gravity_dir.y) < 0 or row + gravity_dir.y >= height: return true
	var current := (row * width) + col
	assert(grid[current] == CellType.SAND)
	var below := ((row + gravity_dir.y) * width) + col
	
	var next_cell := below
	if can_move(Vector2i(col, row), gravity_dir):
		if handle_movement(new_grid, current, next_cell): return true

	if col + 1 >= width or col - 1 < 0:
		return false

	var dir := 1 if randi_range(0, 1) == 1 else -1
	next_cell = below + dir
	if can_move(Vector2i(col, row), Vector2i(dir, gravity_dir.y)):
		if handle_movement(new_grid, current, next_cell): return true

	next_cell = below - dir
	if can_move(Vector2i(col, row), Vector2i(-dir, gravity_dir.y)):
		if handle_movement(new_grid, current, next_cell): return true
	return false

func handle_movement(new_grid: PackedByteArray, current: int, next_cell: int) -> bool:
	assert(grid[current] == CellType.SAND, "moving non-sand")
	var next_cell_content := grid[next_cell]
	if next_cell_content >= CellType.GOAL1 && next_cell_content <= CellType.GOAL3:
		assert(!counts[next_cell_content] >= 100, "moving into filled goal")
		counts[next_cell_content] += 1
		new_grid[current] = CellType.AIR
		return true
	elif next_cell_content == CellType.AIR:
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
	var new_pos := from + dir
	var new_pos_content := grid[new_pos.y * width + new_pos.x]
	if new_pos_content != CellType.AIR and not \
	 (
		new_pos_content >= CellType.GOAL1 &&
		new_pos_content <= CellType.GOAL3 &&
		counts[new_pos_content] < 100
	): 
		return false
	if dir == gravity_dir: return true
	if dir == Vector2i(1, gravity_dir.y) or dir == Vector2i(-1, gravity_dir.y):
		var adjacent_content := grid[from.y * width + from.x + dir.x]
		if adjacent_content == CellType.AIR or \
			adjacent_content == CellType.SAND or \
			(
				new_pos_content >= CellType.GOAL1 &&
				new_pos_content <= CellType.GOAL3 &&
				counts[new_pos_content] < 100
			): 
			return true
	return false
