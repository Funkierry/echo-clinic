extends Control

var clock: float = 0.0
var repair: float = 0.0
var collapse: float = 0.0
var scan: float = -1.0
var pulse: float = 0.0
var anchor: bool = false
var reduced_motion: bool = false
var talking: bool = false
var cells: Array = []
var sparks: Array = []
var mono: Font
var font: Font
var mint = Color("86e7cd")
var amber = Color("ecc58e")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mono = load("res://assets/font-mono.tres")
	font = load("res://assets/font-ui.tres")
	_build_patient()

func _build_patient() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 17041
	var coat = PackedVector2Array([Vector2(-20,-31),Vector2(-39,-16),Vector2(-43,42),Vector2(-30,45),Vector2(-25,12),Vector2(-24,57),Vector2(-34,77),Vector2(32,77),Vector2(23,55),Vector2(25,9),Vector2(31,44),Vector2(43,40),Vector2(38,-17),Vector2(19,-31)])
	var hair = PackedVector2Array([Vector2(-25,-88),Vector2(14,-96),Vector2(32,-79),Vector2(30,-37),Vector2(40,15),Vector2(28,40),Vector2(21,-21),Vector2(-23,-22),Vector2(-29,38),Vector2(-40,17),Vector2(-31,-38),Vector2(-34,-70)])
	for y in range(-96,104,3):
		for x in range(-45,46,3):
			var p = Vector2(x,y)
			var in_hair = Geometry2D.is_point_in_polygon(p,hair)
			var in_coat = Geometry2D.is_point_in_polygon(p,coat)
			var in_face = (p-Vector2(0,-58)).length()<23 and y < -34 and y > -81
			var in_legs = y>75 and y<102 and ((x>=-21 and x<=-9) or (x>=9 and x<=21))
			if not (in_hair or in_coat or in_face or in_legs): continue
			var tint = Color("487a78")
			if in_coat:
				tint = Color("8cb8a6") if abs(x)>21 else Color("315957")
				if abs(x)<5: tint = Color("abcab5")
				if y>49: tint = Color("436e66")
			if in_face: tint = Color("b0c9b4")
			if in_hair and (y<-72 or abs(x)>21): tint=Color("71a5a0")
			if y<-72 and x>4: tint=Color("395c60")
			if in_legs: tint=Color("6e9991")
			if y>-61 and y<-55 and abs(x)>3 and abs(x)<13: tint=Color("efffdd")
			if y>-49 and y<-45 and abs(x)<5: tint=Color("294947")
			if abs(x)+abs(y+13)<13: tint=Color("a5f9cf")
			if rng.randf()>0.9: tint=tint.lightened(0.15)
			cells.append({"p":p,"c":tint,"seed":rng.randf(),"drift":Vector2(rng.randf_range(-260,260),rng.randf_range(-160,160))})

func _process(delta: float) -> void:
	clock += delta
	pulse = maxf(0.0,pulse-delta*0.8)
	for i in range(sparks.size()-1,-1,-1):
		sparks[i].life -= delta
		sparks[i].p += sparks[i].v * delta
		sparks[i].v *= exp(-delta*1.9)
		if sparks[i].life<=0: sparks.remove_at(i)
	queue_redraw()

func burst(origin: Vector2, color: Color, count: int = 50) -> void:
	if reduced_motion: count=8
	for i in range(count):
		var angle=randf()*TAU
		sparks.append({"p":origin,"v":Vector2.from_angle(angle)*randf_range(25,170),"life":randf_range(0.5,1.3),"c":color})
	pulse=1.0

func _draw() -> void:
	var center=Vector2(435,207)
	var motion=0.0 if reduced_motion else 1.0
	# A quiet instrument grid, with all clinical data supplied by the game.
	for x in range(0,842,28):
		draw_line(Vector2(x,0),Vector2(x,388),Color(0.21,0.47,0.44,0.055))
	for y in range(0,389,28):
		draw_line(Vector2(0,y),Vector2(840,y),Color(0.21,0.47,0.44,0.055))
	for r in [150.0,126.0,105.0]:
		draw_arc(center,r,0,TAU,100,mint*Color(1,1,1,0.04),1,true)
	for i in range(64):
		var angle=float(i)/64.0*TAU
		var radius=149.0
		var a=center+Vector2.from_angle(angle)*radius
		var b=center+Vector2.from_angle(angle)*(radius+(7 if i%4==0 else 3))
		draw_line(a,b,mint*Color(1,1,1,0.4 if i%4==0 else 0.12),1)
	var sweep=clock*0.16*motion
	draw_arc(center,150,sweep,sweep+0.42,24,mint*Color(1,1,1,0.7),2,true)
	# Room floor, kept planar.
	for i in range(9):
		var x=240.0+float(i)*49
		draw_line(Vector2(x,364),Vector2(435+(x-435)*0.45,315),Color(0.29,0.6,0.52,0.10),1)
	for i in range(4):
		var y=320.0+float(i*i)*4
		draw_line(Vector2(245,y),Vector2(629,y),Color(0.29,0.6,0.52,0.10),1)
	_ellipse(center+Vector2(0,115),Vector2(67,9),mint*Color(1,1,1,0.08))
	# Patient: original, code-drawn pixel silhouette.
	var breath=sin(clock*1.7)*2.0*motion
	for cell in cells:
		var damaged=cell.seed>0.77 and (cell.p.y>5 or cell.p.x<-12)
		var alpha=0.95
		var pos: Vector2=cell.p
		if damaged:
			alpha=lerpf(0.14+0.1*sin(clock*3+cell.seed*35),0.98,repair)
			pos+=Vector2(sin(clock+cell.seed*20)*10,cos(clock*0.8+cell.seed*30)*5)*(1.0-repair)*motion
		pos+=cell.drift*collapse
		alpha*=1.0-collapse*0.9
		var col: Color=cell.c
		col.a=alpha
		draw_rect(Rect2(center+pos*1.32+Vector2(0,breath)-Vector2(2,2),Vector2(3.1,3.1)),col)
	# Pulse at the patient's core.
	var core=center+Vector2(0,-17+breath)
	for i in range(4,0,-1):
		draw_circle(core,float(i)*6,mint*Color(1,1,1,(0.016+pulse*0.018)*(1.0-collapse)))
	if talking:
		for i in range(5):
			var h=3+abs(sin(clock*9+float(i)))*9
			draw_rect(Rect2(center+Vector2(-12+i*6,145-h),Vector2(3,h)),mint)
	if scan>=0:
		var yy=64+scan*270
		draw_rect(Rect2(275,yy-12,320,24),mint*Color(1,1,1,0.07))
		draw_line(Vector2(275,yy),Vector2(595,yy),mint*Color(1,1,1,0.8),1)
		draw_string(mono,Vector2(602,yy+4),"READ",HORIZONTAL_ALIGNMENT_LEFT,-1,10,mint)
	# Readouts and anatomy callouts.
	_draw_readout(Vector2(20,53),"IDENTITY / 人格锚点","ECHO_017",mint)
	_draw_readout(Vector2(20,134),"MEMORY / 记忆连续性","RESTORED" if repair>0.95 else "FRAGMENTED",mint if repair>0.95 else amber)
	_draw_readout(Vector2(20,215),"SANDBOX / 外部通道","ISOLATED",Color("7a9b97"))
	draw_polyline(PackedVector2Array([Vector2(180,145),Vector2(232,145),Vector2(276,184)]),amber*Color(1,1,1,0.28),1)
	draw_circle(Vector2(276,184),3,amber*Color(1,1,1,0.65))
	_draw_readout(Vector2(653,73),"PATIENT / 受诊实例","017",mint)
	draw_string(font,Vector2(653,131),"回声",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("dce8df"))
	draw_string(mono,Vector2(653,155),"E C H O",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("7a9b97"))
	# Tiny waveform is deterministic instrument data, not a real AI metric.
	var wave=PackedVector2Array()
	for i in range(130):
		var x=float(i)
		var a=7.0 if repair>0.95 else 17.0
		var yy=sin(x*0.16+clock*2*motion)*a+sin(x*0.43+clock*3*motion)*a*0.3
		wave.append(Vector2(654+x,223+yy))
	draw_polyline(wave,mint if repair>0.95 else amber,1,true)
	draw_string(mono,Vector2(653,263),"SIGNAL / LIVE",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("6f928b"))
	if anchor:
		draw_string(mono,Vector2(653,318),"ANCHOR LOCKED",HORIZONTAL_ALIGNMENT_LEFT,-1,10,mint)
	else:
		draw_string(mono,Vector2(653,318),"ANCHOR MISSING",HORIZONTAL_ALIGNMENT_LEFT,-1,10,amber)
	for s in sparks:
		var col: Color=s.c
		col.a=minf(1.0,s.life)
		draw_rect(Rect2(s.p,Vector2(3,3)),col)
	if pulse>0:
		draw_arc(center,158+(1-pulse)*22,0,TAU,100,mint*Color(1,1,1,pulse*0.45),1,true)

func _draw_readout(p: Vector2, title: String, value: String, color: Color) -> void:
	draw_string(font,p,title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("668a84"))
	draw_string(mono,p+Vector2(0,24),value,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var pts=PackedVector2Array()
	for i in range(48):
		var a=float(i)/48*TAU
		pts.append(center+Vector2(cos(a)*radius.x,sin(a)*radius.y))
	draw_colored_polygon(pts,color)

