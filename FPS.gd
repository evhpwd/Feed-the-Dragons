extends Label

func _process(_delta):
	var fps := Engine.get_frames_per_second()
	if fps < 55:
		set("theme_override_colors/font_color", Color.RED)
	else:
		set("theme_override_colors/font_color", Color.WHITE)
	set_text("FPS: %d" % fps)
