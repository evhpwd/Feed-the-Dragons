extends Node2D

var sim_scene := preload("res://Simulation.tscn")
var sim: Simulation = sim_scene.instantiate()
const SIM_HEIGHT := Simulation.height
const SIM_WIDTH := Simulation.width

var added := false
var editor_run := false
var current_level := 0
var levels := [preload("res://Levels/level.json").data, preload("res://Levels/level2.json").data, preload("res://Levels/level3.json").data, preload("res://Levels/level4.json").data]
const level_dialog: Array[String] = [
	"This dragon looks hungry! Draw a line with your mouse so the food can get to its mouth. Use right click to erase the line",
	"Looks like someone flipped gravity! Use the G button or click the gravity button on the side to flip gravity and feed these dragons",
	"One dragon has started getting thirsty from all this sand they ate. Give them a drink of water - the other dragon still wants food!",
	"appy everyfing uve wearned :3",
]
const LEVEL := 0

func _ready():
	sim.all_goals_complete.connect(_on_simulation_all_goals_complete)
	sim.counter_changed.connect(_on_simulation_counter_changed)
	sim.skip_level.connect(_on_simulation_skip_level)
	sim.drawing_complete.connect(_hide_dialog)
	switch_to_menu()

func grid_to_viewport(pos: Vector2i) -> Vector2i:
	var viewport := get_viewport()
	var mapping = Vector2(
		float(SIM_WIDTH) / float(viewport.size.x),
		float(SIM_HEIGHT) / float(viewport.size.y)
	)
	pos.x /= mapping.x
	pos.y /= mapping.y
	return pos

# SWITCHING STATES
func switch_to_menu():
	$WaitTimer.start()
	sim.reset()
	sim.load_level(preload("res://Levels/menu.json").data)
	sim.simulating = false
	sim.can_input = false
	$HUD/PlayButton.show()
	$HUD/EditorButton.show()
	$HUD/MenuButton.hide()
	$HUD/ResetButton.hide()
	$HUD/SimulateButton.hide()
	$HUD/BrushChoice.hide()
	$HUD/ExportButton.hide()
	$HUD/ImportButton.hide()
	$HUD/SwapGravityButton.hide()
	$HUD/CountLabel1.hide()
	$HUD/CountLabel2.hide()
	$HUD/CountLabel3.hide()
	$HUD/SpeedSlider.hide()
	$HUD/FPS.hide()
	if not added:
		add_child(sim)
		added = true

func switch_to_editor():
	$WaitTimer.stop()
	sim.reset()
	sim.load_level({"rules": ["disable_simulation"], "goals": [[100, []],[100, []],[100, []]], "blocks": {}})
	$HUD/PlayButton.hide()
	$HUD/EditorButton.hide()
	$HUD/MenuButton.show()
	$HUD/ResetButton.hide()
	$HUD/SimulateButton.show()
	$HUD/BrushChoice.show()
	$HUD/ExportButton.show()
	$HUD/ImportButton.show()
	$HUD/SwapGravityButton.hide()
	$HUD/CountLabel1.hide()
	$HUD/CountLabel2.hide()
	$HUD/CountLabel3.hide()
	$HUD/SpeedSlider.show()
	$HUD/FPS.show()
	if not added:
		add_child(sim)
		added = true
	if not editor_run:
		for cell in range(0, Simulation.CellType.LENGTH):
			$HUD/BrushChoice.add_item(Simulation.CellType.keys()[cell], int(cell))
		editor_run = true

func switch_to_play(level: Dictionary, dialog: String):
	$WaitTimer.start()
	sim.reset()
	sim.load_level(level)
	sim.simulating = false

	var goals = level.get("goals")
	var coords = level.get("ui_coords")
	if goals.size() >= 1:
		$HUD/CountLabel1.text = "%d" % goals[0][0]
		$HUD/CountLabel1.position = grid_to_viewport(Vector2i(coords["counter1"][0], coords["counter1"][1]))
		$HUD/CountLabel1.show()
	if goals.size() >= 2:
		$HUD/CountLabel2.text = "%d" % goals[1][0]
		$HUD/CountLabel2.position = grid_to_viewport(Vector2i(coords["counter2"][0], coords["counter2"][1]))
		$HUD/CountLabel2.show()
	if goals.size() >= 3:
		$HUD/CountLabel3.text = "%d" % goals[2][0]
		$HUD/CountLabel3.position = grid_to_viewport(Vector2i(coords["counter3"][0], coords["counter3"][1]))
		$HUD/CountLabel3.show()
	
	var dialog_box := $HUD/LevelDialog
	dialog_box.set_text(dialog)
	if "dialog" in coords:
		var pos = coords.dialog
		dialog_box.position = Vector2(pos[0], pos[1])
	dialog_box.show()
	$HUD/PlayButton.hide()
	$HUD/EditorButton.hide()
	$HUD/MenuButton.show()
	$HUD/ResetButton.show()
	$HUD/SimulateButton.hide()
	$HUD/BrushChoice.hide()
	$HUD/ExportButton.hide()
	$HUD/ImportButton.hide()
	$HUD/SpeedSlider.hide()
	$HUD/FPS.hide()
	if sim.can_swap_gravity:
		$HUD/SwapGravityButton.show()
	else:
		$HUD/SwapGravityButton.hide()
	if not added:
		add_child(sim)
		added = true

# HUD SIGNALS
func _on_hud_start_editor():
	switch_to_editor()

func _on_hud_play_game():
	switch_to_play(levels[0], level_dialog[0])

func _on_hud_menu_moment():
	switch_to_menu()

func _on_hud_brush_selected(index):
	sim.brush_type = index

func grid_to_dict(grid: PackedByteArray) -> Dictionary:
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
	return level

func _on_hud_export_clicked():
	var level := JSON.stringify(grid_to_dict(sim.grid))
	var dialog := $HUD/ExportDialog
	dialog.file_selected.connect(
		func(path: String):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_line(level)
	)
	dialog.popup_centered()

func _on_hud_import_clicked():
	var dialog := $HUD/ImportDialog
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
	switch_to_play(levels[current_level], level_dialog[current_level])
	$HUD/NextLevelButton.hide()

func _on_hud_reset_level_moment():
	sim.reset()
	sim.load_level(levels[current_level])

func _on_hud_toggle_sim_moment():
	sim.simulating = not sim.simulating
	
# SIM SIGNALS
func _on_simulation_all_goals_complete():
	if current_level < levels.size() - 1:
		$HUD/NextLevelButton.show()

func _on_simulation_counter_changed(counter: int, count: int):
	if counter == 0:
		$HUD/CountLabel1.text = "%d" % count
	elif counter == 1:
		$HUD/CountLabel2.text = "%d" % count
	elif counter == 2:
		$HUD/CountLabel3.text = "%d" % count

func _on_simulation_skip_level():
	current_level += 1
	switch_to_play(levels[current_level], level_dialog[current_level])

# TIMER THIGNY
func _on_timer_timeout():
	sim.simulating = true

func _hide_dialog():
	$HUD/LevelDialog.hide()
