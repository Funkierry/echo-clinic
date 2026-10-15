extends Control

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_rect(Rect2(0,0,1440,900),Color("071317"))
	for x in range(0,1440,40):
		for y in range(0,900,40):
			draw_rect(Rect2(x,y,1,1),Color(0.25,0.5,0.45,0.16))
	draw_line(Vector2(32,83),Vector2(1408,83),Color("29453f"),1)
	draw_line(Vector2(32,858),Vector2(1408,858),Color("29453f"),1)
	for pos in [Vector2(32,104),Vector2(1408,104),Vector2(32,848),Vector2(1408,848)]:
		var direction=Vector2(1 if pos.x<100 else -1,1 if pos.y<200 else -1)
		draw_line(pos,pos+Vector2(12*direction.x,0),Color("8ce5cb"),2)
		draw_line(pos,pos+Vector2(0,12*direction.y),Color("8ce5cb"),2)
