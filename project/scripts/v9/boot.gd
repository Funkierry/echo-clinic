extends Control
## Start-of-shift boot, after the PV's opening: one dot of light stretches into a line, a few
## terminal lines type out, then the clinic fades in. Click or press any key to skip.
const UI=preload("res://scripts/v9/ui.gd")
signal finished
const LINES=["night-shift@017:~$ ./echo_clinic --shift=night","> 院方工单 #0417 已附加","> 患者 E-017 · 状态：在线 · 稳定 31%","> 交接单已放在聊天窗里"]
var t: float=0.0
var duration: float=3.4
var done: bool=false

func _ready() -> void:
 size=Vector2(1100,600); z_index=125; mouse_filter=MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed: finish()

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed: finish(); get_viewport().set_input_as_handled()

func finish() -> void:
 if done: return
 done=true
 var tw=create_tween(); tw.tween_property(self,"modulate:a",0.0,0.35)
 tw.tween_callback(func(): finished.emit(); queue_free())

func _process(delta: float) -> void:
 t+=delta
 if t>=duration: finish()
 queue_redraw()

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color(0.01,0.015,0.03))
 var c=size/2
 # 0–0.5s a dot, 0.5–1.1s it stretches into a line.
 var k=clampf((t-0.5)/0.6,0,1)
 var w=2.0+ease(k,0.3)*700.0
 draw_rect(Rect2(c-Vector2(w/2,1),Vector2(w,2)),Color(UI.BLUE,0.9))
 if t<0.5: draw_circle(c,2.0+sin(t*20.0),Color(UI.PAPER,0.9))
 var font=UI.mono()
 for i in range(LINES.size()):
  var start=1.1+i*0.45
  if t<start: break
  var shown=int((t-start)*48.0)
  var line: String=LINES[i]
  draw_string(font,c+Vector2(-340,30+i*22),line.left(shown),HORIZONTAL_ALIGNMENT_LEFT,-1,13,UI.CYAN if i==0 else UI.MUTED)
 draw_string(font,Vector2(980,580),"点击跳过",HORIZONTAL_ALIGNMENT_LEFT,-1,10,UI.DIM)
