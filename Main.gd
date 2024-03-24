extends Node2D

const SIM_HEIGHT := Simulation.height
const SIM_WIDTH := Simulation.width

var sim_scene := preload("res://Simulation.tscn")
var sim: Simulation = sim_scene.instantiate()
var added := false

const LEVELS := [
	{
		"emitter": Vector2i(int(float(SIM_WIDTH) / 2.0), int(float(SIM_HEIGHT) * 0.2)),
		"blocks": [
			{
				"type": Simulation.CellType.GOAL1,
				"positions": [Vector2i(180, 100), Vector2i(181, 100), Vector2i(182, 100), Vector2i(183, 100)]
			}
		]
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
	
