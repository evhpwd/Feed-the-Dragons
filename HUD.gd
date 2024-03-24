extends CanvasLayer

signal start_game
signal start_editor
signal brush_selected(index)

func _ready():
	pass

func _process(_delta):
	pass

func _on_play_button_pressed():
	start_game.emit()

func _on_editor_button_pressed():
	start_editor.emit()

func _on_brush_choice_item_selected(index):
	brush_selected.emit(index)
