extends Control
## A place a card can go. It never says what belongs there; it only lights up under a card it will take.
const UI=preload("res://scripts/v9/ui.gd")
var id: String=""
var accepts: Array=[]   # exact tags, or prefixes ending in ":" / "*"
var caption: String=""
var accent: Color=UI.BLUE
var hot: bool=false
var glow: float=0.0
var time: float=0.0
var filled: String=""
var dashed: bool=true
## Invisible until a card it accepts hovers over it (used on top of drawn objects like nodes).
var ghost: bool=false

func setup(slot_id: String, rect: Rect2, accept_tags: Array, text: String="", color: Color=UI.BLUE) -> void:
 id=slot_id; accepts=accept_tags; caption=text; accent=color
 position=rect.position; size=rect.size
 mouse_filter=MOUSE_FILTER_IGNORE
 add_to_group("drop_slot")

func can_accept(tag: String) -> bool:
 for a in accepts:
  var s=str(a)
  if s=="*": return true
  if s.ends_with(":") and tag.begins_with(s): return true
  if s==tag: return true
 return false

func _process(delta: float) -> void:
 time+=delta
 glow=lerpf(glow,1.0 if hot else 0.0,clampf(delta*14,0,1))
 queue_redraw()

func _draw() -> void:
 var r=Rect2(Vector2.ZERO,size)
 var pulse=0.5+0.5*sin(time*7.0)
 if ghost:
  if glow>0.01:
   draw_rect(r.grow(2),Color(accent,0.14*glow+0.08*pulse*glow))
   draw_rect(r.grow(2),Color(accent,0.8*glow),false,1.5)
  return
 if glow>0.01:
  draw_rect(r.grow(3*glow),Color(accent,0.10*glow+0.06*pulse*glow))
 draw_rect(r,Color(0,0,0,0.25))
 var c=Color(accent.lerp(UI.PAPER,glow*0.5),0.45+0.5*glow)
 if dashed:
  var step=8.0
  var x=0.0
  while x<size.x:
   draw_line(Vector2(x,0.5),Vector2(minf(x+4,size.x),0.5),c); draw_line(Vector2(x,size.y-0.5),Vector2(minf(x+4,size.x),size.y-0.5),c); x+=step
  var y=0.0
  while y<size.y:
   draw_line(Vector2(0.5,y),Vector2(0.5,minf(y+4,size.y)),c); draw_line(Vector2(size.x-0.5,y),Vector2(size.x-0.5,minf(y+4,size.y)),c); y+=step
 else:
  draw_rect(r,c,false,1.0)
 if not caption.is_empty():
  var font=UI.mono()
  var w=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
  draw_string(font,Vector2((size.x-w)/2,size.y/2+4),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(accent,0.55+0.4*glow))
