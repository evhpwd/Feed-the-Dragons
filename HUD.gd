extends CanvasLayer

signal play_game
signal start_editor
signal menu_moment
signal brush_selected(index)
signal swap_gravity
signal export_clicked
signal import_clicked
signal next_level_moment
signal reset_level_moment

func _ready():
	pass

func _process(_delta):
	pass

func _on_play_button_pressed():
	play_game.emit()

func _on_editor_button_pressed():
	start_editor.emit()

func _on_brush_choice_item_selected(index):
	brush_selected.emit(index)

func _on_export_button_pressed():
	export_clicked.emit()

func _on_import_button_pressed():
	import_clicked.emit()

func _on_swap_gravity_button_pressed():
	swap_gravity.emit()

func _on_menu_button_pressed():
	menu_moment.emit()

func _on_next_level_button_pressed():
	next_level_moment.emit()

func _on_reset_button_pressed():
	reset_level_moment.emit()
