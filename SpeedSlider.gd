extends Node2D

const MIN_VALUE := 1
const MAX_VALUE := 60
@onready var slider: HSlider = $HSlider


func _ready():
	slider.value = float(Engine.physics_ticks_per_second)
	slider.min_value = float(MIN_VALUE)
	slider.max_value = float(MAX_VALUE)
	slider.size.x = 100

func _process(_delta):
	var speed := Engine.physics_ticks_per_second
	$Label.set_text("Speed: %d" % speed)

func _on_slider_change(value: float):
	Engine.physics_ticks_per_second = clamp(int(value), MIN_VALUE, MAX_VALUE)
