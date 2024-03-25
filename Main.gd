extends Node2D

const SIM_HEIGHT := Simulation.height
const SIM_WIDTH := Simulation.width

var sim_scene := preload("res://Simulation.tscn")
var sim: Simulation = sim_scene.instantiate()
var added := false
var editor_run := false
var current_level := 0
var levels := [preload("res://Levels/level.json").data, preload("res://Levels/level2.json").data]
const LEVEL := 0

func _ready():
	sim.all_goals_complete.connect(_on_simulation_all_goals_complete)
	switch_to_menu()

func switch_to_menu():
	sim.reset()
	sim.load_level(preload("res://Levels/menu.json").data)
	sim.can_input = false
	$HUD/PlayButton.show()
	$HUD/EditorButton.show()
	$HUD/MenuButton.hide()
	$HUD/ResetButton.hide()
	$HUD/BrushChoice.hide()
	$HUD/ExportButton.hide()
	$HUD/ImportButton.hide()
	$HUD/SwapGravityButton.hide()
	if not added:
		add_child(sim)
		added = true

func switch_to_editor():
	sim.reset()
	sim.load_level({"rules": ["disable_simulation"], "goals": [1000, 1000, 1000], "blocks": {}})
	$HUD/PlayButton.hide()
	$HUD/EditorButton.hide()
	$HUD/MenuButton.show()
	$HUD/ResetButton.hide()
	$HUD/BrushChoice.show()
	$HUD/ExportButton.show()
	$HUD/ImportButton.show()
	$HUD/SwapGravityButton.hide()
	if not added:
		add_child(sim)
		added = true
	if not editor_run:
		for cell in range(0, Simulation.CellType.LENGTH):
			$HUD/BrushChoice.add_item(Simulation.CellType.keys()[cell], int(cell))
		editor_run = true

func switch_to_play(level: Dictionary):
	sim.reset()
	sim.load_level(level)
	$HUD/PlayButton.hide()
	$HUD/EditorButton.hide()
	$HUD/MenuButton.show()
	$HUD/ResetButton.show()
	$HUD/BrushChoice.hide()
	$HUD/ExportButton.hide()
	$HUD/ImportButton.hide()
	if sim.can_swap_gravity:
		$HUD/SwapGravityButton.show()
	else:
		$HUD/SwapGravityButton.hide()
	if not added:
		add_child(sim)
		added = true

func _on_hud_start_editor():
	switch_to_editor()

func _on_hud_play_game():
	switch_to_play(levels[0])

func _on_hud_menu_moment():
	switch_to_menu()

func _on_hud_brush_selected(index):
	sim.brush_type = index

func grid_to_json(grid: PackedByteArray) -> String:
	var blocktypes := {}
	for row in range(SIM_HEIGHT):
		for col in range(SIM_WIDTH):
			var cell := grid[row * SIM_WIDTH + col]
			if cell == Simulation.CellType.AIR: continue
			if not blocktypes.has(cell): blocktypes[cell] = []
			blocktypes[cell].append([col, row])
	var level := {
		"blocks": blocktypes,
	}
	return JSON.stringify(level)

func _on_hud_export_clicked():
	var level := grid_to_json(sim.grid)
	var dialog := $HUD/FileDialog
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.file_selected.connect(
		func(path: String):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_line(level)
	)
	dialog.popup_centered()

func _on_hud_import_clicked():
	var dialog := $HUD/FileDialog
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.file_selected.connect(
		func(path: String):
			var file := FileAccess.open(path, FileAccess.READ)
			sim.load_level(JSON.parse_string(file.get_as_text()))
	)
	dialog.popup_centered()

func _on_hud_swap_gravity():
	sim.gravity_dir *= -1

func _on_hud_next_level_moment():
	current_level += 1
	switch_to_play(levels[current_level])
	$HUD/NextLevelButton.hide()

func _on_hud_reset_level_moment():
	sim.reset()
	sim.load_level(levels[current_level])

func _on_simulation_all_goals_complete():
	if current_level < levels.size() - 1:
		$HUD/NextLevelButton.show()
