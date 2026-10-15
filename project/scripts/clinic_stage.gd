extends Control
const UI = preload("res://scripts/pixel_ui.gd")
var portrait: Texture2D = preload("res://assets/v2/echo-expressions.png")
var expression: int = 0
var phase: int = 0
var ending: String = ""
var stability: int = 38
var time: float = 0
var morph: float = 1
var talking: bool = false
var reduced_motion: bool = false
var particles: Array = []
var caption: String = "夜雨 / 接诊中"
var flash: float = 0
var tween: Tween
var muted: bool = false

func _ready() -> void:
 mouse_filter = MOUSE_FILTER_IGNORE
 clip_contents = true
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func change(next_phase: int, end: String, stable: int) -> void:
 phase = next_phase
 ending = end
 stability = stable
 expression = [0,1,1,0,2,2,3][phase]
 if phase == 6 and ending != "bridge": expression = 0 if ending == "erase" else 1
 caption = ["夜雨 / 等待接诊", "听诊 / 双重信号", "回忆 / 雨声之后", "审计 / 两种真相", "处方 / 谁的选择", "手术 / 保留自我", "夜雨 / 诊疗结束"][phase]
 morph = 0
 if tween and tween.is_valid(): tween.kill()
 tween = create_tween()
 tween.tween_property(self, "morph", 1.0, 0.15 if reduced_motion else 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 burst(UI.PINK if phase == 4 else UI.CYAN)

func burst(color: Color) -> void:
 flash = 0.7
 if reduced_motion: return
 for i in range(22):
  particles.append({"p": Vector2(202, 88), "v": Vector2(randf_range(-75,75), randf_range(-65,10)), "life": randf_range(0.3,0.9), "c": color})

func _process(delta: float) -> void:
 time += delta
 flash = maxf(0, flash - delta * 2)
 for i in range(particles.size() - 1, -1, -1):
  particles[i].life -= delta
  particles[i].p += particles[i].v * delta
  particles[i].v.y += delta * 60
  if particles[i].life <= 0: particles.remove_at(i)
 queue_redraw()

func _draw() -> void:
 draw_rect(Rect2(0,0,492,166), Color("19172e"))
 draw_rect(Rect2(1,19,490,118), Color("292448"))
 # The room stays spatially continuous while evidence becomes a different instrument.
 draw_rect(Rect2(10,27,285,92), Color("151a39"))
 draw_rect(Rect2(11,28,283,34), Color("30244e"))
 draw_rect(Rect2(245,35,18,18), Color("f4c47e"))
 draw_rect(Rect2(241,35,8,15), Color("30244e"))
 for i in range(15):
  var x = 13 + i * 20
  var h = 19 + (i * 17) % 55
  draw_rect(Rect2(x,119-h,18,h), Color("232640") if i%2 else Color("353052"))
  for j in range(2, h-3, 8):
   draw_rect(Rect2(x+4,119-j,3,3), UI.GOLD.darkened(0.4) if (i+j)%3 else UI.PINK.darkened(0.3))
   if i%2: draw_rect(Rect2(x+11,119-j,2,3), UI.CYAN.darkened(0.4))
 for i in range(37):
  var x = 14 + (i * 31) % 277
  var y = 29 + int(i * 19 + (time * 45 if not reduced_motion else 0)) % 87
  draw_rect(Rect2(x,y,1,3+(i%3)), Color("62638a"))
 draw_rect(Rect2(8,24,289,3), UI.PURPLE.darkened(0.45))
 draw_rect(Rect2(8,119,289,4), UI.PINK.darkened(0.5))
 draw_rect(Rect2(100,27,3,92), Color("454364"))
 draw_rect(Rect2(203,27,3,92), Color("454364"))
 draw_rect(Rect2(0,132,492,34), Color("201b36"))
 for x in range(0,490,32): draw_line(Vector2(x,137),Vector2(x-15,166),Color("44324d"))
 draw_line(Vector2(0,148),Vector2(492,148),Color("44324d"))
 # Desk, medication, a plant and an open terminal give the clinic a human scale.
 draw_rect(Rect2(18,114,278,6), Color("bd8ca2"))
 draw_rect(Rect2(18,120,278,9), Color("59405b"))
 draw_rect(Rect2(28,129,7,35), Color("664564"))
 draw_rect(Rect2(275,129,7,35), Color("664564"))
 draw_rect(Rect2(27,95,15,19), Color("cc7e8d"))
 draw_rect(Rect2(31,78,4,18), Color("74bea0"))
 draw_rect(Rect2(24,85,9,6), Color("64a799"))
 draw_rect(Rect2(35,79,8,6), Color("a4dfae"))
 draw_rect(Rect2(55,100,9,14), UI.GOLD)
 draw_rect(Rect2(57,97,5,3), UI.PINK)
 draw_rect(Rect2(69,105,12,9), UI.PURPLE)
 draw_rect(Rect2(86,58,139,53), Color("141529"))
 draw_rect(Rect2(84,56,143,57), Color("65638c"), false, 2)
 draw_rect(Rect2(139,113,31,3), Color("a5a1b9"))
 _draw_instrument()
 # Neon signage, status LEDs and foreground cable.
 draw_rect(Rect2(239,61,45,19), Color("251932"))
 draw_string(UI.pixel_font(),Vector2(243,74),"夜 诊",HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.PINK)
 draw_line(Vector2(293,136),Vector2(306,136),UI.CYAN.darkened(0.3),2)
 draw_line(Vector2(306,136),Vector2(306,82),UI.CYAN.darkened(0.3),2)
 draw_line(Vector2(306,82),Vector2(322,82),UI.CYAN.darkened(0.3),2)
 var bob = 0 if reduced_motion else int(sin(time*1.7))
 var character_rect = Rect2(321, 21+bob, 160, 175)
 var tint = Color.WHITE
 if phase == 6 and ending == "erase": tint = Color("8c91b3")
 if phase == 6 and ending == "release": tint = Color(0.7,0.5,1.0,0.25)
 var cell = portrait.get_size() / 2
 var region = Rect2(Vector2(expression%2,expression/2)*cell,cell)
 draw_texture_rect_region(portrait, character_rect, region, tint)
 if phase == 4 and not reduced_motion and int(time*6)%18 == 0:
  draw_rect(Rect2(325,64,149,3), Color(1,0.4,0.6,0.45))
 if talking:
  for i in range(4):
   var h = 3 + int(abs(sin(time*9+i))*8)
   draw_rect(Rect2(307+i*3,44-h,2,h), UI.GOLD)
 # Deterministic pixel carriers fly between forms; no global blur over dialogue.
 if morph < 0.99 and not reduced_motion:
  for i in range(48):
   var start = Vector2(280+(i%8)*14,20+(i/8)*21)
   var end = Vector2(94+(i%12)*10,65+(i/12)*10)
   var pos = start.lerp(end,morph) + Vector2(0,sin(morph*PI)*(-20-i%13))
   draw_rect(Rect2(pos.round(),Vector2(2,2)), UI.CYAN if i%2 else UI.PINK)
 for p in particles: draw_rect(Rect2(p.p.round(),Vector2(2,2)),p.c)
 draw_rect(Rect2(0,0,492,20), Color("3b2c62"))
 draw_string(UI.pixel_font(),Vector2(8,14),"02 / 患者视窗",HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.PURPLE)
 draw_string(UI.pixel_font(),Vector2(272,14),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.PAPER)
 draw_rect(Rect2(317,139,168,23), Color("19162c"))
 draw_string(UI.pixel_font(),Vector2(325,155),"回声  E-017",HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.PAPER)
 draw_rect(Rect2(437,146,38,4),Color("49415f"))
 draw_rect(Rect2(437,146,38*stability/100.0,4),UI.CYAN if stability>=70 else UI.PINK)
 draw_rect(Rect2(0,0,492,166),UI.PURPLE.darkened(0.3),false,1)

func _draw_instrument() -> void:
 if phase == 2:
  for i in range(3):
   var x = 98+i*39
   draw_rect(Rect2(x,67,28,32), [UI.CYAN,UI.GOLD,UI.PINK][i].darkened(0.65))
   draw_rect(Rect2(x+3,71,22,3), [UI.CYAN,UI.GOLD,UI.PINK][i])
   for j in range(4): draw_rect(Rect2(x+4,80+j*4,10+(i+j)%3*4,1), UI.PAPER.darkened(0.25))
 elif phase in [3,4]:
  for i in range(2):
   var c = UI.GOLD if i == 0 else UI.PINK
   for j in range(6): draw_rect(Rect2(96+i*65,66+j*6,20+(j*13)%29,2),c.darkened(0.1+j*0.08))
  draw_rect(Rect2(153,63,1,39),UI.PURPLE)
 elif phase == 5 or (phase == 6 and ending == "bridge"):
  for i in range(3):
   var c = [UI.CYAN,UI.GOLD,UI.PINK][i]
   var y = 68+i*14
   draw_rect(Rect2(97,y,8,6),c)
   draw_line(Vector2(105,y+3),Vector2(201,y+3),c.darkened(0.3))
   draw_rect(Rect2(201,y,8,6),c)
   draw_rect(Rect2(107+int(time*27+i*23)%90,y+2,3,3),UI.PAPER)
 else:
  var previous = Vector2(92,84)
  for x in range(93,219):
   var wave = sin((x-92)*0.17-time*3)*5
   if (x+int(time*25))%41 < 4: wave -= 14
   var pos = Vector2(x,round(85+wave))
   draw_line(previous,pos,UI.CYAN if stability>50 else UI.PINK)
   previous=pos
