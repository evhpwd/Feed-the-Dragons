extends Node

var grid := PackedByteArray()
var changed = false
const height = 200
const width = 300
var spawn = 0
# To get a color code
# - print("%X" % Color.COLOR_NAME)
# - Flip the bytes of the result (AB CD EF GH -> GH EF CD AB)
# - Put that into the below format
const AIR   := 0
const SAND  := 1
const GRASS := 2
const RESERVED:= -1

@onready var image = Image.create(width, height, false, Image.FORMAT_RGB8)
@onready var grid_sprite = $GridTex

func _ready():
	grid.resize(width * height)
	grid.fill(AIR)
	
	for i in range(width * (height / 2), width * height):
		grid[i] = GRASS

	grid_sprite.texture = ImageTexture.create_from_image(image)
	grid_sprite.size = get_viewport().size
	
	Input.use_accumulated_input = false

func _process(_delta):
	if changed:
		for row in range(0, height):
			for col in range(0, width):
				var cell = grid[(row * width) + col]
				if cell == SAND:
					image.set_pixel(col, row, Color.SANDY_BROWN)
				elif cell == GRASS:
					image.set_pixel(col, row, Color.SEA_GREEN)
				elif cell == AIR:
					image.set_pixel(col, row, Color.SKY_BLUE)
		grid_sprite.texture.update(image)
		changed = false

func _input(event):
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

			if grid[(position.y * width) + position.x] == AIR:
				grid[(position.y * width) + position.x] = GRASS

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
	grid[450 + randi() % 100] = 1
	grid[400] = 1

	var new_grid := PackedByteArray()
	new_grid.resize(width * height)
	new_grid.fill(AIR)

	for row in range(height-1, -1, -1):
		for col in range(width-1, -1, -1):
			var cell = grid[(row * width) + col]
			if cell == SAND:
				if not move_cell(row, col, new_grid):
					new_grid[(row * width) + col] = SAND
			elif cell == GRASS:
				new_grid[(row * width) + col] = GRASS
			elif cell == AIR: pass

	grid = new_grid

func move_cell(row, col, new_grid):
	var current = (row * width) + col
	var below = ((row + 1) * width) + col
	
	if grid[below] == AIR:
		new_grid[below] = grid[current]
		return true
	
	if row + 1 >= height:
		return false
	if col + 1 >= width or col - 1 < 0:
		return false

	var left_right = (randi_range(0, 1) * 2) - 1
	if grid[below + left_right] == AIR and (grid[current + left_right] == AIR or grid[below] == SAND):
		grid[below + left_right] = RESERVED
		new_grid[below + left_right] = grid[current]
		return true
	elif grid[below - left_right] == AIR and (grid[current - left_right] == AIR or grid[below] == SAND):
		grid[below - left_right] = RESERVED
		new_grid[below - left_right] = grid[current]
		return true

	return false
