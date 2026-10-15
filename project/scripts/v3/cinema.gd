extends Control
const UI = preload("res://scripts/v3/ui.gd")
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
 tween.tween_property(self,"progress",1.0,0.2 if reduced else 2.3)
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
 var accent = UI.PINK if mode in ["breach","erase","release"] else UI.CYAN
 draw_rect(Rect2(0,38,800,420),Color(0.02,0.05,0.13,0.58*envelope))
 if snapshot and p < 0.65:
  for i in range(18):
   var shift = pow(clampf(p*2-float(i%5)*0.08,0,1),2)
   var source=Rect2(334,44+i*22,454,22)
   var dest=source
   if mode == "erase": dest.size.x *= 1-shift
   elif mode == "breach": dest.position.x -= shift*(160+(i%3)*45)
   elif mode == "release": dest.position.x += shift*600
   else:
    dest.position.x += shift*(100 if i%2 else -90)
    dest.position.y += shift*(i-9)*10
   draw_texture_rect_region(snapshot,dest,source,Color(1,1,1,1-clampf(p*1.5,0,1)))
 for i in range(72):
  var start = Vector2(350+(i*37)%425,68+(i*19)%348)
  var end = Vector2(295-(i*29)%230,120+(i*23)%205) if mode == "memory" else Vector2(355+(i%12)*35,94+(i/12)*43)
  if mode == "breach": end = Vector2(60+(i*23)%260,90+(i*17)%260)
  var k=clampf(p*1.6-(i%7)*0.035,0,1)
  var at=start.lerp(end,k)+Vector2(sin(k*PI)*float(i%5-2)*22,-sin(k*PI)*50)
  draw_rect(Rect2(at.round(),Vector2(3+i%3,3+i%3)),Color(accent,envelope*0.8))
 if p>0.18 and p<0.88:
  var x=190 if mode=="breach" else 355
  draw_rect(Rect2(x,198,414,100),Color("071426"))
  draw_rect(Rect2(x,198,414,2),accent)
  draw_rect(Rect2(x,296,414,2),accent)
  draw_string(UI.pixel_font(),Vector2(x+16,223),title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,accent)
  draw_string(UI.pixel_font(),Vector2(x+16,249),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.PAPER)
  draw_string(UI.pixel_font(),Vector2(x+16,276),detail,HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.MUTED)
 draw_string(UI.pixel_font(),Vector2(650,450),"空格 / 点击跳过",HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.MUTED)
