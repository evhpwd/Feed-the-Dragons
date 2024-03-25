extends Node
class_name Simulation
signal all_goals_complete
signal counter_changed(counter, count)
signal skip_level
signal drawing_complete

var grid := PackedByteArray()
var cell_colors: Array
var changed := false
const width := 300
const height := 200

enum CellType {
	AIR,
	FOOD,
	GRASS,
	GOAL1,
	GOAL2,
	GOAL3,
	FOOD_EMITTER,
	BLACK,
	GRAY,
	LIGHTGRAY,
	WHITE,
	YELLOW,
	ORANGE,
	RED,
	BLUE,
	GREEN,
	WATER,
	WATER_EMITTER,
	# Cells below this point aren't available in level editor
	RESERVED,
	LENGTH,
}

var goals: Dictionary
var brush_type := CellType.GRASS

@onready var image := Image.create(width, height, false, Image.FORMAT_RGBAF)
@onready var grid_sprite := $GridTex

# RULES THAT DEPEND ON LEVEL
var gravity_dir := Vector2i.DOWN
var can_swap_gravity := false
var simulating := true
var can_input := true

func _ready():
	cell_colors.resize(CellType.LENGTH)
	cell_colors[CellType.FOOD] = Color.SANDY_BROWN
	cell_colors[CellType.GRASS] = Color.SEA_GREEN
	cell_colors[CellType.AIR] = Color.SKY_BLUE
	cell_colors[CellType.FOOD_EMITTER] = Color.DARK_SLATE_GRAY
	cell_colors[CellType.BLACK] = Color.BLACK
	cell_colors[CellType.GRAY] = Color.DARK_SLATE_GRAY
	cell_colors[CellType.LIGHTGRAY] = Color.LIGHT_SLATE_GRAY
	cell_colors[CellType.WHITE] = Color.WHITE_SMOKE
	cell_colors[CellType.YELLOW] = Color.GOLD
	cell_colors[CellType.ORANGE] = Color.ORANGE_RED
	cell_colors[CellType.RED] = Color.DARK_RED
	cell_colors[CellType.BLUE] = Color.STEEL_BLUE
	cell_colors[CellType.GREEN] = Color.FOREST_GREEN
	cell_colors[CellType.WATER] = Color.MEDIUM_BLUE
	cell_colors[CellType.WATER_EMITTER] = Color.SLATE_GRAY

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
				elif cell >= CellType.GOAL1 and cell <= CellType.GOAL3:
					if goals[cell][0] < goals[cell][1]:
						image.set_pixel(col, row, Color.BROWN)
					else:
						image.set_pixel(col, row, Color.GREEN)
				else:
					image.set_pixel(col, row, Color.SKY_BLUE)
		grid_sprite.texture.update(image)
		changed = false

func reset():
	# RESET RULES/STATS
	gravity_dir = Vector2i.DOWN
	can_swap_gravity = false
	simulating = true
	can_input = true
	brush_type = CellType.GRASS
	goals.clear()
	
	# RESET GRID
	grid.resize(width * height)
	grid.fill(CellType.AIR)

func load_level(level: Dictionary):
	cell_colors.resize(CellType.LENGTH)
	grid.resize(width * height)
	grid.fill(CellType.AIR)

	for cell_type_s in level.get("blocks", {}):
		var cell_type: CellType = int(cell_type_s) as CellType
		for pos: Array in level["blocks"][cell_type_s]:
			grid[pos[1] * width + pos[0]] = cell_type
	
	var level_goals = level.get("goals")
	if level_goals:
		for i in range(0, level_goals.size()):
			goals[CellType.GOAL1 + i] = [0, level_goals[i][0], level_goals[i][1]]
	
	for rule in level.get("rules", {}):
		if rule == "g_up":
			gravity_dir = Vector2i.UP
		elif rule == "g_right":
			gravity_dir = Vector2i.RIGHT
		elif rule == "g_left":
			gravity_dir = Vector2i.LEFT
		elif rule == "enable_g_swapping":
			can_swap_gravity = true
		elif rule == "disable_simulation":
			simulating = false
		elif rule == "disable_input":
			can_input = false
		else:
			print("unknown rule!!!!!!!?????????")

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
	if not can_input:
		return
	var viewport = get_viewport()
	var old_cell_type: CellType
	var new_cell_type: CellType
	if event is InputEventKey and event.is_action_pressed("swap_gravity") and can_swap_gravity:
		gravity_dir *= -1
	if event is InputEventKey and event.is_action_pressed("skip"):
		skip_level.emit()
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			old_cell_type = CellType.AIR
			new_cell_type = brush_type
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			old_cell_type = brush_type
			new_cell_type = CellType.AIR
		else:
			return
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
		drawing_complete.emit()
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
		drawing_complete.emit()

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
	var new_grid := PackedByteArray()
	new_grid.resize(width * height)
	new_grid.fill(CellType.AIR)
	
	var horizontal_range: Array
	var vertical_range: Array
	if gravity_dir == Vector2i.UP:
		vertical_range = range(height - 1, -1, -1)
	else:
		vertical_range = range(height)

	var drip_toggle := true
	for row in vertical_range:
		if randi_range(0, 1) == 0:
			horizontal_range = range(width)
		else:
			horizontal_range = range(width - 1, -1, -1)
		for col in horizontal_range:
			var pos := int(row * width) + int(col)
			var cell := grid[pos]
			if simulating:
				if cell == CellType.FOOD and move_food(row, col, new_grid):
					pass
				elif cell == CellType.WATER and move_water(row, col, new_grid):
					pass
				elif cell < CellType.RESERVED and cell > CellType.AIR:
					new_grid[pos] = cell
					var next_cell = clamp(pos + (width * gravity_dir.y), 0, width * height - 1)
					if new_grid[next_cell] == CellType.AIR:
						if cell == CellType.FOOD_EMITTER:
							new_grid[next_cell] = CellType.FOOD
						elif cell == CellType.WATER_EMITTER:
							if drip_toggle:
								new_grid[next_cell] = CellType.WATER
			else:
				new_grid[pos] = cell
			drip_toggle = not drip_toggle
	
	var goals_fulfilled := false
	for goal in goals:
		if goals[goal][0] < goals[goal][1]:
			goals_fulfilled = false
			break
		else:
			goals_fulfilled = true
	if goals_fulfilled:
		all_goals_complete.emit()
	
	grid = new_grid

func handle_movement(new_grid: PackedByteArray, current: int, next_cell: int) -> bool:
	#assert(grid[current] == CellType.FOOD, "moving non-FOOD")
	var next_cell_content := grid[next_cell]
	if next_cell_content >= CellType.GOAL1 and next_cell_content <= CellType.GOAL3 and float(grid[current]) in goals[next_cell_content][2]:
		assert(!goals[next_cell_content][0] >= goals[next_cell_content][1], "moving into filled goal")#and int(grid[current]) in goals[next_cell_content][2]
		goals[next_cell_content][0] += 1
		counter_changed.emit(next_cell_content - CellType.GOAL1, goals[next_cell_content][1] - goals[next_cell_content][0])
		new_grid[current] = CellType.AIR
		return true
	elif next_cell_content == CellType.AIR:
		grid[next_cell] = CellType.RESERVED
		new_grid[next_cell] = grid[current]
		return true
	elif next_cell_content == CellType.WATER:
		grid[next_cell] = CellType.RESERVED
		new_grid[next_cell] = grid[current]
		return true
	return false

func move_food(row: int, col: int, new_grid: PackedByteArray) -> bool:
	# 'Fall off' top and bottom of screen
	if (row + gravity_dir.y) < 0 or row + gravity_dir.y >= height: return true
	var current := (row * width) + col
	#assert(grid[current] == CellType.FOOD)
	var below := ((row + gravity_dir.y) * width) + col
	
	var next_cell := below
	if food_can_move(Vector2i(col, row), gravity_dir):
		if handle_movement(new_grid, current, next_cell): return true

	if col + 1 >= width or col - 1 < 0:
		return false

	var dir := 1 if randi_range(0, 1) == 1 else -1
	next_cell = below + dir
	if food_can_move(Vector2i(col, row), Vector2i(dir, gravity_dir.y)):
		if handle_movement(new_grid, current, next_cell): return true

	next_cell = below - dir
	if food_can_move(Vector2i(col, row), Vector2i(-dir, gravity_dir.y)):
		if handle_movement(new_grid, current, next_cell): return true
	
	return false

# Rules for FOOD particle movement
# - Can move down into AIR
# - Can move diagonally downward into AIR if:
#   - Cell on side is AIR or...
#   - Cell below is FOOD
# - If moves into GOAL cell
#   - Remove FOOD
#   - Increment count
func food_can_move(from: Vector2i, dir: Vector2i) -> bool:
	var new_pos := from + dir
	var new_pos_content := grid[new_pos.y * width + new_pos.x]
	#print(goals[new_pos_content][2])
	#print(int(CellType.FOOD))
	if new_pos_content != CellType.AIR and \
	   new_pos_content != CellType.WATER and not \
	 (
		new_pos_content >= CellType.GOAL1 and
		new_pos_content <= CellType.GOAL3 and
		goals[new_pos_content][0] < goals[new_pos_content][1]
	): 
		return false
	if dir == gravity_dir: return true
	if dir == Vector2i(1, gravity_dir.y) or dir == Vector2i(-1, gravity_dir.y):
		var adjacent_content := grid[from.y * width + from.x + dir.x]
		if adjacent_content == CellType.AIR or \
			adjacent_content == CellType.FOOD or \
			 (
				new_pos_content >= CellType.GOAL1 and
				new_pos_content <= CellType.GOAL3 and
				goals[new_pos_content][0] < goals[new_pos_content][1]
			):
			return true
	return false
	
func move_water(row: int, col: int, new_grid: PackedByteArray) -> bool:
	# 'Fall off' top and bottom of screen
	if (row + gravity_dir.y) < 0 or row + gravity_dir.y >= height: return true
	var current := (row * width) + col
	#assert(grid[current] == CellType.water)
	var below := ((row + gravity_dir.y) * width) + col
	
	#vertical movement
	var next_cell := below
	if water_can_move(Vector2i(col, row), gravity_dir):
		if handle_movement(new_grid, current, next_cell): return true

	if col + 1 >= width or col - 1 < 0:
		return false

	#diagonal movement
	var dir := 1 if randi_range(0, 1) == 1 else -1
	next_cell = below + dir
	if water_can_move(Vector2i(col, row), Vector2i(dir, gravity_dir.y)):
		if handle_movement(new_grid, current, next_cell): return true

	next_cell = below - dir
	if water_can_move(Vector2i(col, row), Vector2i(-dir, gravity_dir.y)):
		if handle_movement(new_grid, current, next_cell): return true
	
	#sideways movement
	next_cell = current + dir
	if water_can_move(Vector2i(col, row), Vector2i(dir, 0)):
		if handle_movement(new_grid, current, next_cell): return true

	next_cell = current - dir
	if water_can_move(Vector2i(col, row), Vector2i(-dir, 0)):
		if handle_movement(new_grid, current, next_cell): return true
	return false
	
# Rules for WATER particle movement
# - Can move down into AIR
# - Can move diagonally downward into AIR if:
#   - Cell on side is AIR or...
#   - Cell below is WATER OR FOOD
# - Can move sideways if cell behind and below is water (also behind and above(?)
# - If moves into GOAL cell
#   - Remove WATER
#   - Increment count
func water_can_move(from: Vector2i, dir: Vector2i) -> bool:
	var new_pos := from + dir
	var new_pos_content := grid[new_pos.y * width + new_pos.x]
	if new_pos_content != CellType.AIR and not \
	 (
		new_pos_content >= CellType.GOAL1 and
		new_pos_content <= CellType.GOAL3 and
		goals[new_pos_content][0] < goals[new_pos_content][1] and
		CellType.WATER not in goals[new_pos_content][2]
	): 
		return false
	if dir == gravity_dir: return true
	if dir == Vector2i(1, gravity_dir.y) or dir == Vector2i(-1, gravity_dir.y):
		var adjacent_content := grid[from.y * width + from.x + dir.x]
		if adjacent_content == CellType.AIR or \
			adjacent_content == CellType.FOOD or \
			adjacent_content == CellType.WATER:
			return true
	if dir == Vector2i(-1, 0) or dir == Vector2i(1, 0):
		if grid[(new_pos.y + 1) * width + new_pos.x] != CellType.AIR:
			return true
	return false
