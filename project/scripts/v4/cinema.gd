extends Control
const UI = preload("res://scripts/v4/ui.gd")
var progress: float = 1.0
var mode: String = ""
var title: String = ""
var subtitle: String = ""
var detail: String = ""
var snapshot: Texture2D
var reduced: bool = false
var running: bool = false
var tween: Tween
signal completed

func _ready() -> void:
 mouse_filter = MOUSE_FILTER_IGNORE
 z_index = 90

func play(beat: Array, old: Texture2D, reduce: bool = false) -> void:
 title=beat[0]; subtitle=beat[1]; detail=beat[2]; mode=beat[3]
 snapshot=old
 reduced=reduce
 progress=0
 running=true
 mouse_filter=MOUSE_FILTER_STOP
 if tween and tween.is_valid(): tween.kill()
 tween=create_tween()
 tween.tween_property(self,"progress",1.0,0.2 if reduced else 1.5 if mode in ["receipt","rename","redline","preview"] else 2.3)
 tween.tween_callback(finish)

func finish() -> void:
 if not running: return
 if tween and tween.is_valid(): tween.kill()
 progress=1
 running=false
 mouse_filter=MOUSE_FILTER_IGNORE
 queue_redraw()
 completed.emit()

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed: finish()

func _process(_delta: float) -> void:
 if running: queue_redraw()

func _draw() -> void:
 if not running or reduced: return
 var p = progress
 var envelope = minf(1.0,minf(p*6,(1-p)*6))
 var accent = UI.PINK if mode in ["breach","erase","release","erase_line","forgery","redline"] else UI.CYAN
 draw_rect(Rect2(0,38,800,420),Color(0.02,0.05,0.13,0.58*envelope))
 if snapshot and p < 0.65:
  for i in range(18):
   var shift = pow(clampf(p*2-float(i%5)*0.08,0,1),2)
   var source=Rect2(12,44+i*22,310,22) if mode in ["erase_line","forgery","rewind"] else Rect2(334,44+i*22,454,22)
   var dest=source
   if mode in ["erase","erase_line"]: dest.size.x *= 1-shift
   elif mode == "breach": dest.position.x -= shift*(160+(i%3)*45)
   elif mode == "release": dest.position.x += shift*600
   elif mode=="silence": dest.position.y+=shift*5
   elif mode=="rewind": dest.position.y-=shift*(30+i*12)
   else:
    dest.position.x += shift*(100 if i%2 else -90)
    dest.position.y += shift*(i-9)*10
   draw_texture_rect_region(snapshot,dest,source,Color(1,1,1,1-clampf(p*1.5,0,1)))
 for i in range(72):
  var start = Vector2(350+(i*37)%425,68+(i*19)%348)
  var end = Vector2(295-(i*29)%230,120+(i*23)%205) if mode == "memory" else Vector2(355+(i%12)*35,94+(i/12)*43)
  if mode in ["breach","forgery"]: end = Vector2(60+(i*23)%260,90+(i*17)%260)
  var k=clampf(p*1.6-(i%7)*0.035,0,1)
  var at=start.lerp(end,k)+Vector2(sin(k*PI)*float(i%5-2)*22,-sin(k*PI)*50)
  draw_rect(Rect2(at.round(),Vector2(3+i%3,3+i%3)),Color(accent,envelope*0.8))
 if p>0.18 and p<0.88:
  var x=190 if mode in ["breach","forgery"] else 355
  draw_rect(Rect2(x,198,414,100),Color("071426"))
  draw_rect(Rect2(x,198,414,2),accent)
  draw_rect(Rect2(x,296,414,2),accent)
  draw_string(UI.pixel_font(),Vector2(x+16,223),title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,accent)
  draw_string(UI.pixel_font(),Vector2(x+16,249),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.PAPER)
  draw_string(UI.pixel_font(),Vector2(x+16,276),detail,HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.MUTED)
 if mode=="silence":
  draw_rect(Rect2(350,210,268,int(119*envelope)),Color("040a13"))
  draw_string(UI.pixel_font(),Vector2(366,235),"AUDIT OFFLINE",HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.PINK)
 if mode=="forgery" and p>0.08:
  var left=lerpf(430,34,clampf(p*2,0,1))
  draw_rect(Rect2(left,110,270,62),Color("38273f"))
  draw_rect(Rect2(left,110,270,2),UI.PINK)
  draw_string(UI.pixel_font(),Vector2(left+12,132),"你？ / UNSIGNED",HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.PINK)
  draw_string(UI.pixel_font(),Vector2(left+12,154),"允许 E-017 继承后续授权",HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.PAPER)
 if mode=="redline":
  draw_rect(Rect2(566,271,206,64),Color(UI.PINK,envelope*0.12))
  draw_line(Vector2(577,316),Vector2(577+181*minf(1,p*2),316),UI.PINK,2)
 if mode=="compare":
  draw_string(UI.pixel_font(),Vector2(575,145),"+ 还是",HORIZONTAL_ALIGNMENT_LEFT,-1,24,UI.PINK)
  draw_string(UI.pixel_font(),Vector2(575,178),"+ 页 03",HORIZONTAL_ALIGNMENT_LEFT,-1,24,UI.PINK)
 if mode=="rewind":
  draw_string(UI.pixel_font(),Vector2(80,230),"23:47:08" if p<0.5 else "23:47:07",HORIZONTAL_ALIGNMENT_LEFT,-1,24,UI.PURPLE)
 if mode=="witness":
  for i in range(6):
   draw_line(Vector2(390,110+i*9),Vector2(717,110+i*9),Color(UI.CYAN,envelope*0.25),1)
  draw_string(UI.pixel_font(),Vector2(385,94),"E-017",HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.PURPLE)
  draw_string(UI.pixel_font(),Vector2(650,94),"E-017 ?",HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.CYAN)
 draw_string(UI.pixel_font(),Vector2(650,450),"空格 / 点击跳过",HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.MUTED)

