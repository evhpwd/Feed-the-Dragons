extends Node2D

const SIM_HEIGHT := Simulation.height
const SIM_WIDTH := Simulation.width

var sim_scene := preload("res://Simulation.tscn")
var sim: Simulation = sim_scene.instantiate()
var added := false

const LEVELS := [
	{
		"emitter": [int(float(SIM_WIDTH) / 2.0), int(float(SIM_HEIGHT) * 0.2)],
		"blocks": {
			Simulation.CellType.GOAL1: [[180, 100], [181, 100], [182, 100], [183, 100]],
		}
	}
]
const LEVEL := 0

func _ready():
	pass

func _on_hud_start_editor():
	sim.reset()
	sim.load_editor()
	$HUD/BrushChoice.show()
	if not added:
		add_child(sim)
		added = true
	for cell in range(0, Simulation.CellType.LENGTH):
		$HUD/BrushChoice.add_item(Simulation.CellType.keys()[cell], int(cell))

func _on_hud_brush_selected(index):
	sim.brush_type = index

func _on_hud_start_game():
	sim.reset()
	sim.load_level(LEVELS[LEVEL])
	$HUD/BrushChoice.hide()
	if not added:
		add_child(sim)
		added = true

func grid_to_json(grid: PackedByteArray) -> String:
	var blocktypes := {}
	for row in range(SIM_HEIGHT):
		for col in range(SIM_WIDTH):
			var cell := grid[row * SIM_WIDTH + col]
			if cell == Simulation.CellType.AIR: continue
			if not blocktypes.has(cell): blocktypes[cell] = []
			blocktypes[cell].append(Vector2i(col, row))
	var level := {
		"emitter": Vector2i(int(float(SIM_WIDTH) / 2.0), int(float(SIM_HEIGHT) * 0.2)),
		"blocks": blocktypes,
	}
	return JSON.stringify(level)

func _on_hud_export_clicked():
	var level := grid_to_json(sim.grid)
	var dialog := $HUD/FileDialog
	dialog.file_selected.connect(
		func(path: String):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_line(level)
	)
	dialog.popup_centered()

