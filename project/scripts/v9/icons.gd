extends RefCounted
## Small vector icons drawn with line primitives, so the bench can show *things* instead of words.
## Every icon fits the given rect and uses one accent colour, matching the hairline TUI look.

static func draw(ci: CanvasItem, name: String, r: Rect2, color: Color, width: float=1.6) -> void:
 var c=r.get_center()
 var s=minf(r.size.x,r.size.y)/2.0
 var w=width
 match name:
  "plug":
   ci.draw_rect(Rect2(c+Vector2(-s*0.45,-s*0.2),Vector2(s*0.9,s*0.75)),color,false,w)
   ci.draw_line(c+Vector2(-s*0.22,-s*0.2),c+Vector2(-s*0.22,-s*0.7),color,w)
   ci.draw_line(c+Vector2(s*0.22,-s*0.2),c+Vector2(s*0.22,-s*0.7),color,w)
   ci.draw_line(c+Vector2(0,s*0.55),c+Vector2(0,s*0.95),color,w)
  "socket":
   ci.draw_arc(c,s*0.8,0,TAU,32,color,w,true)
   ci.draw_rect(Rect2(c+Vector2(-s*0.32,-s*0.18),Vector2(s*0.14,s*0.36)),color)
   ci.draw_rect(Rect2(c+Vector2(s*0.18,-s*0.18),Vector2(s*0.14,s*0.36)),color)
  "process":
   ci.draw_arc(c,s*0.75,0,TAU,32,color,w,true)
   for i in range(6):
    var a=TAU*i/6.0
    ci.draw_line(c+Vector2(cos(a),sin(a))*s*0.75,c+Vector2(cos(a),sin(a))*s*0.98,color,w)
   ci.draw_arc(c,s*0.3,0,TAU,16,color,w,true)
  "stop":
   var pts=PackedVector2Array()
   for i in range(9): pts.append(c+Vector2(cos(TAU*i/8.0+PI/8),sin(TAU*i/8.0+PI/8))*s*0.85)
   ci.draw_polyline(pts,color,w,true)
   ci.draw_rect(Rect2(c-Vector2(s*0.3,s*0.3),Vector2(s*0.6,s*0.6)),color)
  "log":
   ci.draw_rect(Rect2(c-Vector2(s*0.6,s*0.8),Vector2(s*1.2,s*1.6)),color,false,w)
   for i in range(4): ci.draw_line(c+Vector2(-s*0.4,-s*0.45+i*s*0.32),c+Vector2(s*(0.4-0.15*(i%2)),-s*0.45+i*s*0.32),color,w*0.8)
  "wave":
   var p=PackedVector2Array()
   for i in range(25):
    var x=-s+2.0*s*i/24.0
    p.append(c+Vector2(x,sin(i*0.9)*s*0.5*(1.0-absf(x)/s*0.4)))
   ci.draw_polyline(p,color,w,true)
  "file":
   var fr=Rect2(c-Vector2(s*0.55,s*0.75),Vector2(s*1.1,s*1.5))
   var fold=s*0.35
   ci.draw_polyline(PackedVector2Array([fr.position,fr.position+Vector2(fr.size.x-fold,0),fr.position+Vector2(fr.size.x,fold),fr.end,fr.position+Vector2(0,fr.size.y),fr.position]),color,w,true)
   ci.draw_polyline(PackedVector2Array([fr.position+Vector2(fr.size.x-fold,0),fr.position+Vector2(fr.size.x-fold,fold),fr.position+Vector2(fr.size.x,fold)]),color,w*0.8,true)
  "hidden":
   draw(ci,"file",r,Color(color,0.7),w)
   ci.draw_line(c+Vector2(-s*0.7,s*0.7),c+Vector2(s*0.7,-s*0.7),color,w)
  "package":
   ci.draw_rect(Rect2(c-Vector2(s*0.75,s*0.55),Vector2(s*1.5,s*1.1)),color,false,w)
   ci.draw_line(c+Vector2(-s*0.75,-s*0.15),c+Vector2(s*0.75,-s*0.15),color,w)
   ci.draw_line(c+Vector2(0,-s*0.55),c+Vector2(0,s*0.55),color,w*0.8)
  "audio":
   ci.draw_rect(Rect2(c+Vector2(-s*0.7,-s*0.25),Vector2(s*0.35,s*0.5)),color)
   ci.draw_polyline(PackedVector2Array([c+Vector2(-s*0.35,-s*0.25),c+Vector2(0,-s*0.6),c+Vector2(0,s*0.6),c+Vector2(-s*0.35,s*0.25)]),color,w,true)
   ci.draw_arc(c+Vector2(s*0.1,0),s*0.4,-PI/3,PI/3,10,color,w,true)
   ci.draw_arc(c+Vector2(s*0.1,0),s*0.7,-PI/3,PI/3,12,color,w,true)
  "envelope":
   var er=Rect2(c-Vector2(s*0.8,s*0.55),Vector2(s*1.6,s*1.1))
   ci.draw_rect(er,color,false,w)
   ci.draw_polyline(PackedVector2Array([er.position,c+Vector2(0,s*0.1),er.position+Vector2(er.size.x,0)]),color,w,true)
  "letter":
   draw(ci,"envelope",Rect2(r.position+Vector2(0,r.size.y*0.15),r.size*0.9),color,w)
   ci.draw_line(c+Vector2(s*0.5,-s*0.9),c+Vector2(s*0.9,-s*0.5),color,w)
  "inbox":
   ci.draw_polyline(PackedVector2Array([c+Vector2(-s*0.8,-s*0.1),c+Vector2(-s*0.8,s*0.6),c+Vector2(s*0.8,s*0.6),c+Vector2(s*0.8,-s*0.1)]),color,w,true)
   ci.draw_polyline(PackedVector2Array([c+Vector2(-s*0.8,-s*0.1),c+Vector2(-s*0.3,-s*0.1),c+Vector2(-s*0.15,s*0.15),c+Vector2(s*0.15,s*0.15),c+Vector2(s*0.3,-s*0.1),c+Vector2(s*0.8,-s*0.1)]),color,w,true)
  "chart":
   ci.draw_rect(Rect2(c-Vector2(s*0.65,s*0.8),Vector2(s*1.3,s*1.6)),color,false,w)
   ci.draw_rect(Rect2(c+Vector2(-s*0.25,-s*0.92),Vector2(s*0.5,s*0.24)),color)
   ci.draw_line(c+Vector2(-s*0.4,-s*0.3),c+Vector2(s*0.4,-s*0.3),color,w*0.8)
   ci.draw_line(c+Vector2(-s*0.4,0),c+Vector2(s*0.3,0),color,w*0.8)
   ci.draw_line(c+Vector2(-s*0.4,s*0.3),c+Vector2(s*0.4,s*0.3),color,w*0.8)
  "stamp":
   ci.draw_rect(Rect2(c+Vector2(-s*0.7,s*0.35),Vector2(s*1.4,s*0.35)),color,false,w)
   ci.draw_rect(Rect2(c+Vector2(-s*0.45,s*0.05),Vector2(s*0.9,s*0.3)),color,false,w)
   ci.draw_arc(c+Vector2(0,-s*0.35),s*0.32,0,TAU,20,color,w,true)
   ci.draw_line(c+Vector2(0,-s*0.03),c+Vector2(0,s*0.05),color,w)
  "ear":
   ci.draw_arc(c+Vector2(0,-s*0.1),s*0.55,PI*0.9,PI*2.15,24,color,w,true)
   ci.draw_line(c+Vector2(s*0.5,s*0.15),c+Vector2(0,s*0.85),color,w)
   ci.draw_arc(c+Vector2(0,-s*0.1),s*0.22,PI,PI*2.1,12,color,w,true)
  "coin":
   ci.draw_arc(c,s*0.8,0,TAU,32,color,w,true)
   ci.draw_arc(c,s*0.6,0,TAU,32,Color(color,0.5),w*0.7,true)
   ci.draw_string(ThemeDB.fallback_font,c+Vector2(-s*0.22,s*0.3),"T",HORIZONTAL_ALIGNMENT_LEFT,-1,int(s*0.9),color)
  "send":
   ci.draw_polyline(PackedVector2Array([c+Vector2(-s*0.8,-s*0.6),c+Vector2(s*0.85,0),c+Vector2(-s*0.8,s*0.6),c+Vector2(-s*0.45,0),c+Vector2(-s*0.8,-s*0.6)]),color,w,true)
  "talk":
   ci.draw_rect(Rect2(c-Vector2(s*0.8,s*0.55),Vector2(s*1.6,s*0.95)),color,false,w)
   ci.draw_polyline(PackedVector2Array([c+Vector2(-s*0.4,s*0.4),c+Vector2(-s*0.55,s*0.8),c+Vector2(-s*0.05,s*0.4)]),color,w,true)
  "contract":
   draw(ci,"chart",r,color,w)
   ci.draw_line(c+Vector2(-s*0.3,s*0.6),c+Vector2(s*0.45,s*0.6),Color(color,0.6),w)
  "eye":
   ci.draw_arc(c+Vector2(0,s*0.6),s*0.95,PI*1.2,PI*1.8,16,color,w,true)
   ci.draw_arc(c+Vector2(0,-s*0.6),s*0.95,PI*0.2,PI*0.8,16,color,w,true)
   ci.draw_circle(c,s*0.22,color)
  "key":
   ci.draw_rect(Rect2(c-Vector2(s*0.8,s*0.6),Vector2(s*1.6,s*1.2)),color,false,w)
   ci.draw_rect(Rect2(c-Vector2(s*0.8,s*0.6),Vector2(s*1.6,s*0.2)),Color(color,0.25))
  "page":
   draw(ci,"file",r,color,w)
   ci.draw_string(ThemeDB.fallback_font,c+Vector2(-s*0.2,s*0.35),"3",HORIZONTAL_ALIGNMENT_LEFT,-1,int(s),color)
  "trash":
   ci.draw_line(c+Vector2(-s*0.7,-s*0.55),c+Vector2(s*0.7,-s*0.55),color,w)
   ci.draw_rect(Rect2(c+Vector2(-s*0.2,-s*0.8),Vector2(s*0.4,s*0.25)),color,false,w)
   ci.draw_polyline(PackedVector2Array([c+Vector2(-s*0.55,-s*0.45),c+Vector2(-s*0.42,s*0.85),c+Vector2(s*0.42,s*0.85),c+Vector2(s*0.55,-s*0.45)]),color,w)
   for i in [-1,0,1]: ci.draw_line(c+Vector2(i*s*0.2,-s*0.25),c+Vector2(i*s*0.17,s*0.6),color,w*0.7)
  "gear":
   for i in range(8):
    var a=TAU*i/8.0
    ci.draw_line(c+Vector2(cos(a),sin(a))*s*0.6,c+Vector2(cos(a),sin(a))*s*0.92,color,w*2.0)
   ci.draw_arc(c,s*0.6,0,TAU,24,color,w,true)
   ci.draw_arc(c,s*0.22,0,TAU,12,color,w,true)
  "note":
   var nr=Rect2(c-Vector2(s*0.6,s*0.8),Vector2(s*1.2,s*1.6))
   ci.draw_rect(nr,color,false,w)
   ci.draw_rect(Rect2(nr.position,Vector2(nr.size.x,s*0.25)),Color(color,0.5))
   for i in range(4): ci.draw_line(c+Vector2(-s*0.4,-s*0.3+i*s*0.3),c+Vector2(s*0.4,-s*0.3+i*s*0.3),color,w*0.6)
  "help":
   ci.draw_arc(c,s*0.85,0,TAU,32,color,w,true)
   ci.draw_arc(c+Vector2(0,-s*0.2),s*0.3,PI,TAU+PI*0.5,12,color,w,true)
   ci.draw_line(c+Vector2(0,s*0.1),c+Vector2(0,s*0.3),color,w)
   ci.draw_circle(c+Vector2(0,s*0.55),w,color)
  "run":
   ci.draw_rect(Rect2(c-Vector2(s*0.8,s*0.5),Vector2(s*1.6,s*1.0)),color,false,w)
   ci.draw_line(c+Vector2(-s*0.5,-s*0.2),c+Vector2(-s*0.2,0),color,w)
   ci.draw_line(c+Vector2(-s*0.2,0),c+Vector2(-s*0.5,s*0.2),color,w)
   ci.draw_line(c+Vector2(0,s*0.2),c+Vector2(s*0.45,s*0.2),color,w)
  "power":
   ci.draw_arc(c,s*0.7,-PI*0.3,PI*1.3,24,color,w,true)
   ci.draw_line(c+Vector2(0,-s*0.9),c+Vector2(0,-s*0.1),color,w)
  _:
   ci.draw_rect(Rect2(c-Vector2(s*0.5,s*0.5),Vector2(s,s)),color,false,w)
