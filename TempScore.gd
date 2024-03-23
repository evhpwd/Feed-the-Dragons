extends Label


func _ready():
	set_text("0")

func _process(_delta):
	var count = $"..".counts[Main.CellType.GOAL1]
	set_text("%d" % [count])
