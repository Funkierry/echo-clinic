extends Control
## MEDIC-OS 98: wallpaper, icons, windows, taskbar with start menu and tray, balloon notices,
## right-click menus. The clinic (main) supplies the app list and builds each app's contents.
const UI=preload("res://scripts/v9/ui.gd")
const Icons=preload("res://scripts/v9/icons.gd")
const Win=preload("res://scripts/v9/window.gd")
const Juice=preload("res://scripts/v9/juice.gd")
const TASKBAR_H=24
const AREA=Rect2(350,6,746,566)
const CELL=Vector2(80,76)
const WALLPAPERS={"story":Color("4a1f52"),"teal":Color("0e3940"),"night":Color("141a33"),"plum":Color("2f1a33"),"gray":Color("2a2e36")}
signal app_opened(app_id: String)
var host
var apps: Array=[]          # [{id,label,icon,size:Vector2,desc,resizable}]
var windows: Dictionary={}  # id -> Window
var minimized: Dictionary={}
var seen_apps: Dictionary={}
var selected: Dictionary={} # icon id -> true
var hovered: String=""
var icon_nodes: Dictionary={}
var icon_cells: Dictionary={} # icon id -> Vector2i grid cell, once moved by hand
var icon_layer: Control
var window_layer: Control
var taskbar: Control
var start_menu: Control
var popup: Control
var toasts: Array=[]        # {text,color,life}
var clock_text: String="23:47"
var rent_on: bool=false
var time: float=0.0
var last_click: Dictionary={}
var task_buttons: Control
var tray_wallet: Button
var tray_rent: Button
var tray_sound: Button
var tray_clock: Button
var notice_layer: Control
var gadget: Control
var wallpaper: String="story"
var backdrop: Control
var marquee: Rect2=Rect2()
var marquee_from: Vector2=Vector2.ZERO
var marking: bool=false
var drag_icon: String=""
var drag_from: Vector2=Vector2.ZERO
var drag_moved: bool=false
var drag_cell: Vector2i=Vector2i.ZERO

func setup(main) -> void:
 host=main; size=Vector2(1100,600)
 mouse_filter=MOUSE_FILTER_IGNORE
 set_wallpaper(wallpaper)
 var logo=Control.new(); logo.size=size; logo.mouse_filter=MOUSE_FILTER_IGNORE; add_child(logo)
 logo.draw.connect(func(): _draw_logo(logo))
 # A Win98 "active desktop" gadget: the clock, the countdown to midnight, and her live vitals.
 gadget=Control.new(); gadget.position=Vector2(892,12); gadget.size=Vector2(196,136); gadget.mouse_filter=MOUSE_FILTER_IGNORE; add_child(gadget)
 gadget.draw.connect(_draw_gadget)
 # Empty desktop: click to deselect, drag to lasso icons, right-click for the desktop menu.
 backdrop=Control.new(); backdrop.position=AREA.position; backdrop.size=AREA.size; backdrop.mouse_filter=MOUSE_FILTER_STOP; add_child(backdrop)
 backdrop.gui_input.connect(_backdrop_input)
 backdrop.draw.connect(_draw_marquee)
 icon_layer=Control.new(); icon_layer.size=size; icon_layer.mouse_filter=MOUSE_FILTER_IGNORE; add_child(icon_layer)
 window_layer=Control.new(); window_layer.size=size; window_layer.mouse_filter=MOUSE_FILTER_IGNORE; add_child(window_layer)
 taskbar=Control.new(); taskbar.position=Vector2(0,600-TASKBAR_H); taskbar.size=Vector2(1100,TASKBAR_H); add_child(taskbar)
 taskbar.draw.connect(_draw_taskbar)
 var start=UI.button(taskbar,"   开始",Rect2(3,3,70,18),toggle_start,UI.PAPER)
 start.name="Start"; start.tooltip_text="单击这里开始。"
 var flag=Control.new(); flag.position=Vector2(9,6); flag.size=Vector2(12,12); flag.mouse_filter=MOUSE_FILTER_IGNORE; start.add_child(flag)
 flag.draw.connect(func():
  flag.draw_rect(Rect2(0,0,5,5),UI.PINK); flag.draw_rect(Rect2(6,0,5,5),UI.CYAN)
  flag.draw_rect(Rect2(0,6,5,5),UI.BLUE); flag.draw_rect(Rect2(6,6,5,5),UI.GOLD))
 notice_layer=Control.new(); notice_layer.size=size; notice_layer.mouse_filter=MOUSE_FILTER_IGNORE; notice_layer.z_index=20
 task_buttons=Control.new(); task_buttons.position=Vector2(80,3); task_buttons.size=Vector2(700,18); taskbar.add_child(task_buttons)
 tray_rent=UI.button(taskbar,"",Rect2(812,3,92,18),func(): host.toggle_rent(),UI.GOLD)
 tray_rent.tooltip_text="把她的算力租出去：每 12 秒 +1T，每夜最多 10T。\n代价：她的上下文少 1.5K。"
 tray_wallet=UI.button(taskbar,"",Rect2(906,3,70,18),func(): host._show_journal("wallet"),UI.GOLD)
 tray_wallet.tooltip_text="钱包。单击查看账本。"
 tray_sound=UI.button(taskbar,"♪",Rect2(978,3,22,18),func(): _volume_popup(),UI.MUTED)
 tray_sound.tooltip_text="音量"
 tray_clock=UI.button(taskbar,"",Rect2(1004,3,92,18),func(): _clock_popup(),UI.PAPER)
 tray_clock.tooltip_text="夜班 · 第 1 夜"
 for k in ["normal","hover"]: tray_clock.add_theme_stylebox_override(k,StyleBoxEmpty.new())
 add_child(notice_layer)
 notice_layer.draw.connect(_draw_notices)

## Night sky per act: [top, horizon, neon]. The city outside the clinic changes with the story.
const SKIES=[
 [Color("120f2e"),Color("0f4650"),Color("5fe0c8")],
 [Color("1a1238"),Color("4a1f52"),Color("ff7d92")],
 [Color("0d1838"),Color("2c4876"),Color("b39dff")],
 [Color("201030"),Color("6e2a50"),Color("ffc56e")],
 [Color("2a0c1c"),Color("8c3428"),Color("ff7d92")],
 [Color("1c2236"),Color("b8643a"),Color("ffc56e")],
 [Color("28466e"),Color("e6a070"),Color("5fe0c8")],
]
const BAYER=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5]
## Painted at a quarter of the screen and scaled up with nearest-neighbour; a little wider than the
## screen so the city layers can drift for parallax.
const QW=284
const QH=144
var story_key: String=""
var neon: Color=Color("5fe0c8")
## The live wallpaper: a Control holding sky, far city, near city and two effect layers.
var scene: Control
var scene_act: int=0

## "story" paints the city at the current act; the others are plain dithered colours.
func set_wallpaper(id: String) -> void:
 if not WALLPAPERS.has(id): id="story"
 wallpaper=id
 if id=="story":
  story_key=""
  set_story(host.state.phase,host.state.later())
  return
 var base: Color=WALLPAPERS[id]
 neon=UI.CYAN
 _show_scene(_paint([base.darkened(0.45),base,UI.CYAN],false),false)

func set_story(phase: int,later: bool) -> void:
 if wallpaper!="story": return
 var key="%d/%s"%[phase,later]
 if key==story_key: return
 var fade=not story_key.is_empty()
 story_key=key
 scene_act=phase
 var sky: Array=SKIES[clampi(phase,0,SKIES.size()-1)].duplicate()
 # The second night is the same city, a shade colder.
 if later: sky=[sky[0].lerp(Color("2a1a4a"),0.35),sky[1].lerp(Color("3a2a6a"),0.3),sky[2]]
 neon=sky[2]
 _show_scene(_paint(sky,true),fade)

## Builds the layered wallpaper and cross-fades it in over the old one.
func _show_scene(data: Dictionary,fade: bool) -> void:
 var s=Control.new(); s.size=size; s.mouse_filter=MOUSE_FILTER_IGNORE
 s.set_meta("data",data)
 add_child(s); move_child(s,0)
 for k in ["sky","far","near"]:
  if not data.has(k): continue
  var tr=TextureRect.new(); tr.name=k; tr.texture=data[k]; tr.mouse_filter=MOUSE_FILTER_IGNORE
  tr.position=Vector2(-16,0) if k!="sky" else Vector2(-16,0)
  s.add_child(tr)
  if k=="sky":
   var back=Control.new(); back.name="fx_back"; back.size=size; back.mouse_filter=MOUSE_FILTER_IGNORE; s.add_child(back)
   back.draw.connect(func(): _draw_fx_back(back,data))
 var front=Control.new(); front.name="fx_front"; front.size=size; front.mouse_filter=MOUSE_FILTER_IGNORE; s.add_child(front)
 front.draw.connect(func(): _draw_fx_front(front,data))
 var old=scene
 scene=s
 if is_instance_valid(old):
  if fade and not host.self_testing and not host.reduced_motion:
   move_child(s,old.get_index()+1)
   s.modulate.a=0.0
   var tw=create_tween(); tw.tween_property(s,"modulate:a",1.0,1.4)
   tw.tween_callback(old.queue_free)
  else: old.queue_free()

func _h2(x: float,y: float) -> float:
 return fposmod(sin(x*127.1+y*311.7)*43758.5453,1.0)

func _sky_image(top: Color,low: Color) -> Image:
 var img=Image.create(QW,QH,false,Image.FORMAT_RGBA8)
 var steps=10.0
 for y in range(QH):
  var f=float(y)/float(QH-1)
  for x in range(QW):
   var v=pow(f,1.3)*steps
   var lv=floor(v)+(1.0 if v-floor(v)>BAYER[(x%4)+(y%4)*4]/16.0 else 0.0)
   img.set_pixel(x,y,top.lerp(low,lv/steps))
 return img

## Returns textures for each layer plus the positions the effect layers animate.
func _paint(sky: Array,city: bool) -> Dictionary:
 var top: Color=sky[0]; var low: Color=sky[1]; var glow: Color=sky[2]
 var img=_sky_image(top,low)
 if not city:
  for y in range(0,QH,2):
   for x in range(((y/2)%2)*2,QW,4): img.set_pixel(x,y,img.get_pixel(x,y).lightened(0.12))
  return {"sky":_upscale(img),"top":top,"low":low,"glow":glow,"city":false}
 # Faint fixed stars in the image; the bright ones twinkle on the effect layer.
 var stars: Array=[]
 for y in range(int(QH*0.6)):
  for x in range(QW):
   var r=_h2(x,y)
   if r>0.994: img.set_pixel(x,y,img.get_pixel(x,y).lerp(UI.PAPER,0.35))
   elif r>0.9915 and stars.size()<90: stars.append([Vector2(x,y)*4-Vector2(16,0),_h2(y,x)*TAU,1.0+_h2(x+1,y)*3.0])
 # Moon, with a bite out of it.
 var mc=Vector2(210,24)
 for y in range(int(mc.y)-13,int(mc.y)+14):
  for x in range(int(mc.x)-13,int(mc.x)+14):
   var d=Vector2(x,y).distance_to(mc)
   if d<9.0 and Vector2(x,y).distance_to(mc+Vector2(4,-2))>7.5: img.set_pixel(x,y,UI.PAPER.lerp(glow,0.15))
   elif d<13.0: img.set_pixel(x,y,img.get_pixel(x,y).lerp(glow,0.12*(13.0-d)/4.0))
 # Far city: hazy, taller, almost the colour of the horizon.
 var far=Image.create(QW,QH,false,Image.FORMAT_RGBA8); far.fill(Color(0,0,0,0))
 var haze=low.darkened(0.42)
 var x0=0
 while x0<QW:
  var bw=5+int(_h2(x0,17)*8)
  var bh=int(QH*(0.22+_h2(x0,13)*0.26))
  for x in range(x0,mini(QW,x0+bw)):
   for y in range(QH-bh,QH): far.set_pixel(x,y,haze)
  for wy in range(QH-bh+3,QH-2,4):
   for wx in range(x0+1,mini(QW,x0+bw)-1,3):
    if _h2(wx,wy+50)>0.86: far.set_pixel(wx,wy,haze.lerp(UI.GOLD,0.35))
  x0+=bw
 # Near city with lit windows; some windows are left out of the image and flicker on the effect layer.
 var near=Image.create(QW,QH,false,Image.FORMAT_RGBA8); near.fill(Color(0,0,0,0))
 var shade=low.darkened(0.74)
 var lit=[UI.GOLD,UI.CYAN,UI.PINK,UI.GOLD]
 var flicker: Array=[]
 var tower=Vector2(174,QH-2-int(QH*0.5))
 x0=0
 while x0<QW:
  var bw=6+int(_h2(x0,7)*10)
  var bh=int(QH*(0.14+_h2(x0,3)*0.22))
  if x0>154 and x0<194:
   bh=int(QH*0.5); tower=Vector2(x0+bw/2,QH-2-bh)
  for x in range(x0,mini(QW,x0+bw)):
   for y in range(QH-2-bh,QH): near.set_pixel(x,y,shade)
  for wy in range(QH-2-bh+3,QH-4,3):
   for wx in range(x0+2,mini(QW,x0+bw)-1,3):
    var r=_h2(wx,wy)
    if r>0.78:
     var c=Color(lit[int(_h2(wy,wx)*4.0)%4]).lerp(shade,0.25)
     if r>0.95 and flicker.size()<60: flicker.append([Vector2(wx,wy)*4-Vector2(16,0),c,_h2(wx+3,wy)*20.0])
     else: near.set_pixel(wx,wy,c)
  x0+=bw+1
 # The neon cross stands on the clinic tower's roof.
 var cross=(tower+Vector2(-1,-8))*4-Vector2(16,0)
 return {"sky":_upscale(img),"far":_upscale(far),"near":_upscale(near),"stars":stars,"flicker":flicker,"cross":cross,"top":top,"low":low,"glow":glow,"city":true}

func _upscale(img: Image) -> ImageTexture:
 img.resize(img.get_width()*4,img.get_height()*4,Image.INTERPOLATE_NEAREST)
 return ImageTexture.create_from_image(img)

## Stars twinkle, slow fog drifts, a plane blinks across, and now and then a shooting star.
func _draw_fx_back(c: Control,d: Dictionary) -> void:
 var t=_fx_time()
 if not d.get("city",false): return
 for s in d.stars:
  var a=0.35+0.65*absf(sin(t*float(s[2])*0.6+float(s[1])))
  var p: Vector2=s[0]
  c.draw_rect(Rect2(p,Vector2(4,4)),Color(UI.PAPER,a))
  if a>0.92: c.draw_rect(Rect2(p+Vector2(-4,0),Vector2(12,4)),Color(UI.PAPER,0.25)); c.draw_rect(Rect2(p+Vector2(0,-4),Vector2(4,12)),Color(UI.PAPER,0.25))
 var fog: Color=Color(d.low).lightened(0.25)
 for i in range(3):
  var w=420.0+i*120.0
  var x=fposmod(i*380.0+t*(6.0+i*3.0),1100.0+w)-w
  var y=150.0+i*70.0
  for k in range(4):
   c.draw_rect(Rect2(x+k*16,y+k*4,w-k*32,12-k*2),Color(fog,0.045))
 # A plane, blinking.
 var px=fposmod(t*16.0,1400.0)-150.0
 c.draw_rect(Rect2(px,96+sin(t*0.3)*6,4,4),Color(UI.PINK,1.0 if int(t*2.0)%2==0 else 0.15))
 c.draw_rect(Rect2(px-8,96+sin(t*0.3)*6,4,4),Color(UI.PAPER,0.3))
 # Shooting star every nine seconds.
 var st=fmod(t,9.0)
 if st<0.7:
  var k=st/0.7
  var a=Vector2(500+_h2(floor(t/9.0),1)*400,30+_h2(floor(t/9.0),2)*80)
  var head=a+Vector2(220,90)*k
  c.draw_line(head-Vector2(60,24)*(1.0-k*0.5),head,Color(UI.PAPER,0.8*(1.0-k)),2.0)

## Flickering windows, the neon cross breathing (and stuttering), rain, lightning on the worst act.
func _draw_fx_front(c: Control,d: Dictionary) -> void:
 var t=_fx_time()
 if d.get("city",false):
  for wnd in d.flicker:
   var phase=float(wnd[2])
   var on=_h2(floor(t*0.7+phase),phase)>0.22
   if on: c.draw_rect(Rect2(wnd[0],Vector2(4,4)),wnd[1])
  var glow: Color=d.glow
  var cp: Vector2=d.cross
  var stutter=_h2(floor(t*9.0),3.0)>0.985
  var a=(0.65+0.35*sin(t*2.2))*(0.15 if stutter else 1.0)
  for r in [44.0,32.0,22.0]: c.draw_circle(cp+Vector2(2,2),r,Color(glow,0.06*a))
  c.draw_rect(Rect2(cp+Vector2(-16,0),Vector2(36,4)),Color(glow.lightened(0.3),a))
  c.draw_rect(Rect2(cp+Vector2(0,-16),Vector2(4,36)),Color(glow.lightened(0.3),a))
  c.draw_rect(Rect2(cp+Vector2(-16,4),Vector2(36,4)),Color(glow,a))
  c.draw_rect(Rect2(cp+Vector2(4,-16),Vector2(4,36)),Color(glow,a))
 # Rain: slanted streaks falling all the time.
 for i in range(130):
  var sp=380.0+_h2(i,9)*260.0
  var x=fposmod(_h2(i,1)*1200.0-t*sp*0.25,1200.0)-50.0
  var y=fposmod(_h2(i,2)*600.0+t*sp,600.0)
  c.draw_line(Vector2(x,y),Vector2(x-3,y+12),Color(UI.PAPER,0.13),1.0)
 # Lightning, only when the night is at its worst.
 if d.get("city",false) and scene_act==4:
  var lt=fmod(t,13.0)
  if lt<0.5:
   var flash=(1.0-lt/0.5)*(1.0 if lt<0.08 or (lt>0.18 and lt<0.26) else 0.25)
   c.draw_rect(Rect2(Vector2.ZERO,c.size),Color(1,0.92,0.96,flash*0.3))
   # A jagged bolt down to the roofs.
   var seed=floor(t/13.0)
   var p=Vector2(560+_h2(seed,4)*420,0)
   for i in range(9):
    var q=p+Vector2((_h2(seed,i+10)-0.5)*60,34)
    c.draw_line(p,q,Color(1,1,1,flash),3.0); c.draw_line(p,q,Color(UI.PINK,flash*0.6),7.0)
    p=q

func _fx_time() -> float:
 return 0.0 if host.reduced_motion or host.self_testing and not fx_test else time

var fx_test: bool=false

## Layers drift against the mouse a little, so the window feels like glass in front of a city.
func _parallax() -> void:
 if not is_instance_valid(scene): return
 var off=Vector2.ZERO
 if not (host.reduced_motion or host.self_testing):
  off=(get_viewport().get_mouse_position()-Vector2(550,300))/Vector2(550,300)
  off=off.clamp(Vector2(-1,-1),Vector2(1,1))
 for k in [["sky",2.0],["far",6.0],["near",12.0]]:
  var n=scene.get_node_or_null(str(k[0]))
  if n: n.position=Vector2(-16-off.x*float(k[1]),-off.y*float(k[1])*0.3)
 var fx=scene.get_node_or_null("fx_front")
 if fx: fx.position=Vector2(-off.x*12.0,0)
 for n in ["fx_back","fx_front"]:
  var l=scene.get_node_or_null(n)
  if l: l.queue_redraw()

func _process(delta: float) -> void:
 time+=delta
 for t in toasts: t.life+=delta
 toasts=toasts.filter(func(t): return t.life<4.0)
 if not toasts.is_empty() or notice_layer.has_meta("dirty"):
  notice_layer.queue_redraw()
  if toasts.is_empty(): notice_layer.remove_meta("dirty")
 for id in icon_nodes:
  if not seen_apps.has(id): icon_nodes[id].queue_redraw()
 if is_instance_valid(gadget): gadget.queue_redraw()
 _parallax()

# --- apps and icons -------------------------------------------------------------

func set_apps(list: Array) -> void:
 apps=list
 rebuild_icons()

func spec_of(id: String) -> Dictionary:
 for a in apps:
  if a.id==id: return a
 return {}

func rebuild_icons() -> void:
 UI.clear(icon_layer); icon_nodes={}
 var taken: Dictionary={}
 for id in icon_cells: taken[icon_cells[id]]=id
 var i=0
 for a in apps:
  if a.get("hidden",false) or not host.app_available(a.id): continue
  var cell: Vector2i
  if icon_cells.has(a.id): cell=icon_cells[a.id]
  else:
   while taken.has(Vector2i(i/7,i%7)): i+=1
   cell=Vector2i(i/7,i%7); i+=1
  taken[cell]=a.id
  var node=Control.new(); node.position=_cell_pos(cell); node.size=Vector2(72,68); node.mouse_filter=MOUSE_FILTER_STOP
  node.tooltip_text=str(a.get("desc",""))
  var id=a.id
  node.gui_input.connect(func(e): _icon_input(id,e))
  node.pivot_offset=Vector2(36,26)
  node.mouse_entered.connect(func():
   hovered=id; node.queue_redraw()
   if not _still(): node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(node,"scale",Vector2(1.08,1.08),0.14))
  node.mouse_exited.connect(func():
   if hovered==id: hovered=""
   node.queue_redraw()
   if not _still(): node.create_tween().tween_property(node,"scale",Vector2.ONE,0.12))
  node.draw.connect(func(): _draw_icon(node,a))
  icon_layer.add_child(node)
  icon_nodes[id]=node
  if not seen_apps.has(id) and not host.self_testing and not node.has_meta("popped"):
   Juice.punch(node,0.3)

func _cell_pos(cell: Vector2i) -> Vector2:
 return Vector2(AREA.position.x+10+cell.x*CELL.x,AREA.position.y+8+cell.y*CELL.y)

func _cell_at(p: Vector2) -> Vector2i:
 var c=Vector2i(int(round((p.x-AREA.position.x-10)/CELL.x)),int(round((p.y-AREA.position.y-8)/CELL.y)))
 return Vector2i(clampi(c.x,0,int(AREA.size.x/CELL.x)-1),clampi(c.y,0,int(AREA.size.y/CELL.y)-1))

func select_only(id: String) -> void:
 selected={}
 if not id.is_empty(): selected[id]=true
 for n in icon_nodes.values(): n.queue_redraw()

func _icon_input(id: String,e: InputEvent) -> void:
 if e is InputEventMouseButton and e.pressed: _close_popups()
 if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
  if e.pressed:
   var now=Time.get_ticks_msec()
   if selected.has(id) and now-int(last_click.get(id,0))<450:
    last_click[id]=0; open(id); return
   if not selected.has(id) or selected.size()>1: select_only(id)
   last_click[id]=now
   drag_icon=id; drag_from=e.global_position; drag_moved=false; drag_cell=_current_cell(id)
   Sfx.play("click")
  elif drag_icon==id:
   if drag_moved: _drop_icon(id,e.global_position)
   drag_icon=""
 elif e is InputEventMouseMotion and drag_icon==id:
  if not drag_moved and e.global_position.distance_to(drag_from)>5: drag_moved=true
  if drag_moved:
   var n=icon_nodes[id]
   n.position=e.global_position-Vector2(36,26)
   n.modulate.a=0.7
 elif e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_RIGHT and e.pressed:
  select_only(id)
  var a=spec_of(id)
  popup_menu(e.global_position,[
   ["打开(O)",func(): open(id)],
   ["—"],
   ["属性(R)",func(): properties(id)],
  ])

## Icons snap to the grid where they are dropped; dropping on another icon swaps them.
func _drop_icon(id: String,at: Vector2) -> void:
 for other in icon_nodes:
  if other!=id and not icon_cells.has(other): icon_cells[other]=_cell_at(icon_nodes[other].position)
 var cell=_cell_at(at-Vector2(36,26))
 for other in icon_cells.keys():
  if other!=id and icon_cells[other]==cell: icon_cells[other]=drag_cell
 icon_cells[id]=cell
 Sfx.play("slot",1.2,-6.0)
 rebuild_icons()

func _current_cell(id: String) -> Vector2i:
 if icon_cells.has(id): return icon_cells[id]
 return _cell_at(icon_nodes[id].position) if icon_nodes.has(id) else Vector2i.ZERO

## A Win98-style properties sheet for a desktop icon.
func properties(id: String) -> void:
 var a=spec_of(id)
 if a.is_empty(): return
 open_dialog("dlg_props",str(a.label)+" 属性",Vector2(300,214),a.icon,func(c: Control):
  var big=Control.new(); big.position=Vector2(10,10); big.size=Vector2(36,36); c.add_child(big)
  big.draw.connect(func(): Icons.draw(big,a.icon,Rect2(Vector2.ZERO,big.size),UI.CYAN,1.6))
  UI.label(c,str(a.label),Rect2(58,18,220,14),UI.PAPER)
  var sep=ColorRect.new(); sep.position=Vector2(8,54); sep.size=Vector2(c.size.x-16,1); sep.color=UI.FACE_LO; c.add_child(sep)
  UI.label(c,"类型：   应用程序",Rect2(10,62,260,14),UI.MUTED)
  UI.label(c,"位置：   C:\\MEDIC\\%s.exe"%id,Rect2(10,80,260,14),UI.MUTED)
  UI.label(c,"打开过： %s"%("是" if seen_apps.has(id) else "还没有"),Rect2(10,98,260,14),UI.MUTED)
  var t=UI.text(c,str(a.get("desc","")),Rect2(10,118,c.size.x-20,40),UI.PAPER); t.autowrap_mode=TextServer.AUTOWRAP_ARBITRARY
  UI.button(c,"确定",Rect2(c.size.x-84,c.size.y-28,76,22),func(): close("dlg_props"),UI.PAPER))

func arrange_icons() -> void:
 icon_cells={}; rebuild_icons(); Sfx.play("pick")

func _draw_icon(node: Control,a: Dictionary) -> void:
 var sel=selected.has(a.id)
 var hot=hovered==a.id
 var r=Rect2(20,4,32,32)
 var col: Color=a.get("color",UI.CYAN)
 if sel: node.draw_rect(Rect2(14,0,44,40),Color(col,0.3))
 elif hot: node.draw_rect(Rect2(14,0,44,40),Color(UI.PAPER,0.08))
 # A little bevelled tile in the app's colour: highlight top-left, shadow bottom-right.
 node.draw_rect(r,col.darkened(0.62))
 node.draw_rect(Rect2(r.position,Vector2(r.size.x,2)),col.darkened(0.2)); node.draw_rect(Rect2(r.position,Vector2(2,r.size.y)),col.darkened(0.2))
 node.draw_rect(Rect2(r.position+Vector2(0,r.size.y-2),Vector2(r.size.x,2)),UI.EDGE); node.draw_rect(Rect2(r.position+Vector2(r.size.x-2,0),Vector2(2,r.size.y)),UI.EDGE)
 if hot: node.draw_rect(r.grow(1),Color(col,0.8),false,1.0)
 Icons.draw(node,a.icon,r.grow(-6),col.lightened(0.25) if not sel else UI.PAPER,1.4)
 var font=UI.mono()
 var w=font.get_string_size(a.label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
 var lr=Rect2((72-w)/2-2,42,w+4,15)
 node.draw_rect(lr,Color(col.darkened(0.35),0.9) if sel else Color(0,0,0,0.45))
 if sel: node.draw_rect(lr,Color(UI.PAPER,0.5),false,1.0)
 node.draw_string(font,Vector2((72-w)/2,54),a.label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.PAPER)
 var badge=str(host.app_badge(a.id))
 if not seen_apps.has(a.id): badge="新"
 if not badge.is_empty():
  # A badge until the app has been opened once, or while something inside waits for you.
  var pulse=0.5+0.5*sin(time*5.0)
  var bw=font.get_string_size(badge,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+6
  node.draw_rect(Rect2(68-bw,0,bw,14),Color(UI.PINK,0.7+0.3*pulse))
  node.draw_string(font,Vector2(71-bw,12),badge,HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.INK)

func icon_rect(id: String) -> Rect2:
 return icon_nodes[id].get_global_rect() if icon_nodes.has(id) else Rect2()

func _backdrop_input(e: InputEvent) -> void:
 if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
  _close_popups()
  if e.pressed:
   select_only(""); marking=true; marquee_from=e.position; marquee=Rect2(e.position,Vector2.ZERO)
  else:
   marking=false; marquee=Rect2(); backdrop.queue_redraw()
 elif e is InputEventMouseMotion and marking:
  marquee=Rect2(marquee_from,Vector2.ZERO).expand(e.position)
  selected={}
  var g=Rect2(marquee.position+backdrop.global_position,marquee.size)
  for id in icon_nodes:
   if g.intersects(icon_nodes[id].get_global_rect().grow(-14)): selected[id]=true
  for n in icon_nodes.values(): n.queue_redraw()
  backdrop.queue_redraw()
 elif e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_RIGHT and e.pressed:
  _close_popups(); select_only("")
  popup_menu(e.global_position,[
   ["排列图标",arrange_icons],
   ["刷新",func(): host.refresh_desktop(true); Sfx.play("scan")],
   ["—"],
   ["新建文件夹",func(): toast("权限不足：这台诊疗机的桌面是只读的。",UI.PINK); Sfx.play("error")],
   ["—"],
   ["更换壁纸",[["窗外（随剧情）",func(): host.set_wallpaper("story")],["青绿",func(): host.set_wallpaper("teal")],["深夜",func(): host.set_wallpaper("night")],["暗紫",func(): host.set_wallpaper("plum")],["灰",func(): host.set_wallpaper("gray")]]],
   ["属性",func(): open("control")],
  ])

func _draw_marquee() -> void:
 if marking and marquee.size.length()>2:
  backdrop.draw_rect(marquee,Color(UI.TITLE_B,0.18))
  backdrop.draw_rect(marquee,Color(UI.PAPER,0.6),false,1.0)

# --- popup menus ------------------------------------------------------------------

## A right-click style menu. Items: [label, Callable, enabled?] or [label, [sub items]] or ["—"].
func popup_menu(at: Vector2,items: Array,parent_menu: Control=null) -> Control:
 if parent_menu==null: _close_popups()
 var m=Control.new(); m.z_index=30
 var w=150.0
 for it in items:
  if it[0]!="—": w=maxf(w,UI.mono().get_string_size(str(it[0]),HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+48)
 var h=6.0
 for it in items: h+=8.0 if it[0]=="—" else 20.0
 m.size=Vector2(w,h)
 m.position=Vector2(minf(at.x,1100-w-2),minf(at.y,600-TASKBAR_H-h))
 if parent_menu: parent_menu.add_child(m); m.position=Vector2(parent_menu.size.x-4,0); m.set_meta("sub",true)
 else:
  add_child(m); popup=m
  _unfold(m)
  # A full-screen catcher: clicking anywhere else closes the menu.
  var catcher=Control.new(); catcher.position=-m.position; catcher.size=Vector2(1100,600); catcher.mouse_filter=MOUSE_FILTER_STOP; catcher.show_behind_parent=true
  catcher.gui_input.connect(func(ev):
   if ev is InputEventMouseButton and ev.pressed: _close_popups())
  m.add_child(catcher)
 var bg=Panel.new(); bg.size=m.size; bg.add_theme_stylebox_override("panel",UI.bevel(UI.FACE)); m.add_child(bg)
 _fill_menu(m,items,3.0,w)
 Sfx.play("click",1.3,-6.0)
 return m

func _fill_menu(m: Control,items: Array,y: float,w: float,left: float=3.0) -> void:
 for it in items:
  if it[0]=="—":
   var sep=ColorRect.new(); sep.position=Vector2(left+4,y+3); sep.size=Vector2(w-left-10,1); sep.color=UI.FACE_LO; m.add_child(sep)
   y+=8.0; continue
  var sub=it.size()>1 and it[1] is Array
  var enabled=it.size()<3 or bool(it[2])
  var cb: Callable=it[1] if it.size()>1 and it[1] is Callable else Callable()
  var b=Button.new(); b.text="  "+str(it[0])+("    ▸" if sub else ""); b.position=Vector2(left,y); b.size=Vector2(w-left-3,20)
  b.alignment=HORIZONTAL_ALIGNMENT_LEFT; b.focus_mode=Control.FOCUS_NONE
  b.add_theme_font_override("font",UI.mono()); b.add_theme_font_size_override("font_size",12)
  b.add_theme_color_override("font_color",UI.PAPER); b.add_theme_color_override("font_hover_color",UI.PAPER)
  b.add_theme_color_override("font_disabled_color",UI.DIM)
  b.add_theme_stylebox_override("normal",StyleBoxEmpty.new()); b.add_theme_stylebox_override("pressed",UI.style(UI.TITLE_B,UI.TITLE_B,0))
  b.add_theme_stylebox_override("hover",UI.style(UI.TITLE_B,UI.TITLE_B,0)); b.add_theme_stylebox_override("disabled",StyleBoxEmpty.new())
  b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
  b.disabled=not enabled or not sub and not cb.is_valid()
  if sub:
   var subitems: Array=it[1]
   var open_sub=func():
    for c in m.get_children():
     if c.has_meta("sub"): c.queue_free()
    var s=popup_menu(Vector2.ZERO,subitems,m); s.position=Vector2(m.size.x-4,b.position.y-3)
   b.mouse_entered.connect(open_sub)
   b.pressed.connect(open_sub)
  else:
   b.mouse_entered.connect(func():
    for c in m.get_children():
     if c.has_meta("sub"): c.queue_free())
   b.pressed.connect(func(): _close_popups(); cb.call())
  m.add_child(b)
  y+=20.0

func _close_popups() -> void:
 if is_instance_valid(popup): popup.queue_free()
 popup=null
 if is_instance_valid(start_menu): start_menu.queue_free()
 start_menu=null

func any_popup() -> bool:
 return is_instance_valid(popup) or is_instance_valid(start_menu)

# --- windows --------------------------------------------------------------------

func is_open(id: String) -> bool:
 return windows.has(id) and is_instance_valid(windows[id])

func active_window() -> String:
 for id in windows:
  if is_instance_valid(windows[id]) and windows[id].active and windows[id].visible: return id
 return ""

func open(id: String) -> Control:
 _close_popups()
 if is_open(id):
  var w0=windows[id]; w0.visible=true; minimized.erase(id); focus(id)
  return w0
 var spec=spec_of(id)
 if spec.is_empty(): return null
 seen_apps[id]=true
 # Some apps are full-screen views of their own (casebook, outsourcing).
 if host.launch_external(id):
  rebuild_icons(); app_opened.emit(id); return null
 return _make_window(id,spec.label,spec.size,spec.icon,bool(spec.get("resizable",false)),func(c): host.build_app(id,c),spec.get("color",UI.BLUE))

## A window that is not an app on the desktop: properties, run, shut down.
func open_dialog(id: String,caption: String,sz: Vector2,icon: String,builder: Callable) -> Control:
 _close_popups()
 if is_open(id): close(id)
 return _make_window(id,caption,sz,icon,false,builder)

func _make_window(id: String,caption: String,sz: Vector2,icon: String,resizable: bool,builder: Callable,accent: Color=UI.BLUE) -> Control:
 var n=windows.size()
 var pos=Vector2(AREA.position.x+92+n*18,AREA.position.y+14+n*16)
 pos.x=minf(pos.x,AREA.end.x-sz.x); pos.y=minf(pos.y,AREA.end.y-sz.y)
 var w=Win.new(); window_layer.add_child(w)
 w.reduced=host.reduced_motion or host.self_testing
 w.accent=accent
 w.setup(id,caption,Rect2(pos,sz),icon,true,true,resizable)
 w.bounds=Rect2(0,0,1100,600-TASKBAR_H)
 w.closed.connect(close)
 w.minimized.connect(minimize)
 w.focused.connect(focus)
 w.user_resized.connect(refresh_app)
 w.title_menu.connect(func(i,at): popup_menu(at,_window_menu(i)))
 w.set_meta("builder",builder)
 builder.call(w.client)
 var origin=icon_rect(id).get_center() if icon_nodes.has(id) else pos+sz/2
 if not w.reduced: w.open_from(origin)
 Sfx.play("pick",0.9)
 windows[id]=w
 focus(id)
 rebuild_icons()
 app_opened.emit(id)
 return w

func _window_menu(id: String) -> Array:
 var w=windows[id]
 return [
  ["还原",func(): restore(id),not w.visible or w.maximized],
  ["最小化",func(): minimize(id),w.visible],
  ["最大化",func(): w.toggle_maximize(),w.resizable and not w.maximized],
  ["—"],
  ["关闭",func(): close(id)],
 ]

func minimize(id: String) -> void:
 if not is_open(id): return
 var w=windows[id]
 var at=Vector2(140,600-TASKBAR_H/2)
 for b in task_buttons.get_children():
  if b.get_meta("app","")==id: at=b.get_global_rect().get_center()
 minimized[id]=true
 w.shrink_to(at,func():
  w.visible=false; _refresh_tasks())

func restore(id: String) -> void:
 if not is_open(id): return
 var w=windows[id]
 if w.maximized and w.visible: w.toggle_maximize(); return
 w.visible=true; minimized.erase(id); focus(id)

func close(id: String) -> void:
 if not is_open(id): return
 var w=windows[id]
 host._app_closed(id)
 windows.erase(id); minimized.erase(id)
 if _still(): w.queue_free()
 else:
  w.mouse_filter=MOUSE_FILTER_IGNORE; w.pivot_offset=w.size/2
  var tw=w.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
  tw.tween_property(w,"scale",Vector2(0.9,0.9),0.12); tw.tween_property(w,"modulate:a",0.0,0.12)
  tw.chain().tween_callback(w.queue_free)
 # The next window in line becomes the active one, as on a real desktop.
 var keys=windows.keys()
 for i in range(keys.size()-1,-1,-1):
  if is_instance_valid(windows[keys[i]]) and windows[keys[i]].visible: focus(keys[i]); return
 _refresh_tasks()

func focus(id: String) -> void:
 for k in windows:
  if is_instance_valid(windows[k]):
   windows[k].active=k==id; windows[k].queue_redraw()
 if is_open(id):
  window_layer.move_child(windows[id],-1)
  # Keep dictionary order = stacking order, so closing hands focus to the one underneath.
  var w=windows[id]; windows.erase(id); windows[id]=w
 _refresh_tasks()

## Rebuilds one app's contents in place (after the story moved on, or a resize).
func refresh_app(id: String) -> void:
 if not is_open(id): return
 # Bench and lounge keep their own state and refresh themselves.
 if id in ["bench","lounge"]: return
 var w=windows[id]
 UI.clear(w.client)
 (w.get_meta("builder") as Callable).call(w.client)

func refresh_all() -> void:
 for id in windows.keys():
  if not str(id).begins_with("dlg_"): refresh_app(id)
 rebuild_icons()

func _refresh_tasks() -> void:
 UI.clear(task_buttons)
 var x=0
 var count=0
 for id in windows:
  if is_instance_valid(windows[id]): count+=1
 var bw=clampf(700.0/maxf(1,count)-4,60,140)
 var order: Array=[]
 for id in windows: order.append(id)
 order.sort_custom(func(a,b): return windows[a].get_instance_id()<windows[b].get_instance_id())
 for id in order:
  if not is_instance_valid(windows[id]): continue
  var w=windows[id]
  var on=w.active and w.visible
  var b=UI.button(task_buttons,w.title,Rect2(x,0,bw,18),func():
   if w.visible and w.active: minimize(id)
   else: w.visible=true; minimized.erase(id); focus(id),w.accent.lerp(UI.PAPER,0.4),on)
  b.clip_text=true; b.set_meta("app",id); b.tooltip_text=w.title
  b.gui_input.connect(func(e):
   if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_RIGHT and e.pressed: popup_menu(b.get_global_rect().position-Vector2(0,110),_window_menu(id)))
  x+=bw+4

# --- start menu, tray, notices ------------------------------------------------

func toggle_start() -> void:
 if is_instance_valid(start_menu):
  _close_popups(); return
 _close_popups()
 var programs: Array=[]
 for a in apps:
  if not a.get("hidden",false) and host.app_available(a.id): programs.append([a.label,func(): open(a.id)])
 var items: Array=[["程序",programs],["文档",host.documents()],["—"]]
 items.append_array(host.start_menu_extras())
 var m=popup_menu(Vector2(3,0),items)
 # Re-dress the generic menu as the start menu: blue side band with the OS name.
 popup=null; start_menu=m
 if not _still():
  # The start menu rises out of the taskbar.
  var to_y=600-TASKBAR_H-m.size.y
  m.position.y=to_y+18; m.modulate.a=0.0; m.scale=Vector2.ONE
  var tw=m.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  tw.tween_property(m,"position:y",to_y,0.14); tw.tween_property(m,"modulate:a",1.0,0.1)
 m.size.x+=22
 for c in m.get_children():
  if c is Panel: c.size.x=m.size.x
  elif c is Button or c is ColorRect: c.position.x+=22
 m.position=Vector2(3,600-TASKBAR_H-m.size.y)
 for c in m.get_children():
  if c.mouse_filter==MOUSE_FILTER_STOP and c.show_behind_parent: c.position=-m.position
 var side=Control.new(); side.position=Vector2(3,3); side.size=Vector2(20,m.size.y-6); side.mouse_filter=MOUSE_FILTER_IGNORE; m.add_child(side)
 side.draw.connect(func():
  side.draw_rect(Rect2(Vector2.ZERO,side.size),UI.TITLE_A)
  # The OS name runs up the band, rotated like the real thing.
  side.draw_set_transform(Vector2(15,side.size.y-6),-PI/2)
  side.draw_string(UI.mono(),Vector2.ZERO,"MEDIC-OS 98",HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.PAPER)
  side.draw_set_transform(Vector2.ZERO,0.0))

func _volume_popup() -> void:
 _close_popups()
 var m=Control.new(); m.size=Vector2(64,150); m.position=Vector2(958,600-TASKBAR_H-152); m.z_index=30; add_child(m); popup=m
 _unfold(m)
 var catcher=Control.new(); catcher.position=-m.position; catcher.size=Vector2(1100,600); catcher.mouse_filter=MOUSE_FILTER_STOP; catcher.show_behind_parent=true
 catcher.gui_input.connect(func(ev):
  if ev is InputEventMouseButton and ev.pressed: _close_popups())
 m.add_child(catcher)
 var bg=Panel.new(); bg.size=m.size; bg.add_theme_stylebox_override("panel",UI.bevel(UI.FACE)); m.add_child(bg)
 UI.label(m,"音量",Rect2(14,4,40,14),UI.PAPER)
 var s=VSlider.new(); s.position=Vector2(22,22); s.size=Vector2(20,96); s.min_value=0; s.max_value=100; s.step=5; s.value=host.volume*100
 s.name="Volume"
 s.value_changed.connect(func(v): host.set_volume(v/100.0))
 m.add_child(s)
 var mute=CheckBox.new(); mute.text="静音"; mute.position=Vector2(4,122); mute.button_pressed=host.muted
 UI.style_check(mute)
 mute.toggled.connect(func(_on): host._toggle_mute())
 m.add_child(mute)

func _clock_popup() -> void:
 _close_popups()
 popup_menu(Vector2(960,600-TASKBAR_H-80),[["夜班 · 第 %d 夜"%host.state.loop,Callable(),false],["现在 %s · 雨"%clock_text,Callable(),false],["—"],["日期/时间属性…",func(): open("control")]])

func toast(text: String,color: Color=UI.CYAN) -> void:
 toasts.append({"text":text,"color":color,"life":0.0})
 notice_layer.set_meta("dirty",true)
 if toasts.size()>3: toasts.pop_front()
 Sfx.play("slot",1.3,-8.0)

func set_status(clock: String,wallet: String,renting: bool,muted: bool) -> void:
 clock_text=clock
 tray_clock.text=clock
 if tray_wallet.text!=wallet: tray_wallet.text=wallet
 tray_rent.text="算力出租 开" if renting else "算力出租 关"
 tray_rent.add_theme_color_override("font_color",UI.GOLD if renting else UI.MUTED)
 tray_sound.text="×" if muted else "♪"
 rent_on=renting

func _draw_gadget() -> void:
 var g=gadget; var st=host.state
 g.draw_style_box(UI.bevel(Color(0.03,0.06,0.1,0.82),true),Rect2(Vector2.ZERO,g.size))
 g.draw_rect(Rect2(3,3,g.size.x-6,16),Color(neon.darkened(0.55),0.95))
 g.draw_rect(Rect2(3,18,g.size.x-6,1),neon)
 g.draw_string(UI.mono(),Vector2(8,15),"夜班 · 第 %d 夜"%st.loop,HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.PAPER)
 var blink=":" if int(time*2.0)%2==0 else " "
 g.draw_string(UI.mono(),Vector2(10,58),clock_text.replace(":",blink),HORIZONTAL_ALIGNMENT_LEFT,-1,36,UI.CYAN)
 var left=maxi(0,60-(47+st.phase*2))
 g.draw_string(UI.mono(),Vector2(108,40),"距 00:00",HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.MUTED)
 g.draw_string(UI.mono(),Vector2(108,56),"%d 分钟"%left,HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.PINK if left<=5 else UI.GOLD)
 # Her vitals. While 42 still rewrites her, the line jumps at :13 and :31, whatever she says.
 var r=Rect2(8,70,g.size.x-16,40)
 g.draw_rect(r,Color(0,0,0,0.45))
 for gx in range(int(r.position.x),int(r.end.x),12): g.draw_line(Vector2(gx,r.position.y),Vector2(gx,r.end.y),Color(UI.LINE,0.35),1.0)
 var hurting=not st.seen("trace_finish") and st.phase<6 and not st.later()
 var pts=PackedVector2Array()
 var now=fmod(time*3.0,45.0)
 for i in range(int(r.size.x)):
  var sec=fmod(now-(r.size.x-i)*0.12+45.0,45.0)
  var beat=exp(-pow(fmod(sec,1.1)-0.2,2)/0.002)*0.35
  var spike=(exp(-pow(sec-13.0,2)/0.3)+exp(-pow(sec-31.0,2)/0.3)) if hurting else 0.0
  pts.append(Vector2(r.position.x+i,r.end.y-6-(beat+spike*0.9)*(r.size.y-10)))
 g.draw_polyline(pts,UI.PINK if hurting else UI.CYAN,1.0)
 var stab=st.stability-(15 if host.profile.renting else 0)
 g.draw_string(UI.mono(),Vector2(8,128),"E-017  稳定 %d%%"%maxi(0,stab),HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.MUTED)

func _draw_logo(l: Control) -> void:
 l.draw_string(UI.mono(),Vector2(AREA.end.x-110,AREA.end.y-6),"MEDIC-OS 98",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(UI.PAPER,0.22))

## Balloon notices above the tray.
func _draw_notices() -> void:
 var l=notice_layer
 var y=600-TASKBAR_H-10
 for i in range(toasts.size()-1,-1,-1):
  var t=toasts[i]
  var a=clampf(minf(t.life*6.0,(4.0-t.life)*2.0),0.0,1.0)
  var w=UI.mono().get_string_size(t.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+24
  var slide=0.0 if _still() else (1.0-ease(clampf(t.life*5.0,0.0,1.0),0.3))*(w+20)
  var r=Rect2(1094-w+slide,y-24,w,22)
  l.draw_style_box(UI.bevel(Color("2a2414") if t.color==UI.GOLD else UI.FACE),r)
  l.draw_rect(Rect2(r.position+Vector2(3,3),Vector2(4,16)),Color(t.color,a))
  l.draw_string(UI.mono(),r.position+Vector2(14,16),t.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(UI.PAPER,a))
  y-=28

func _draw_taskbar() -> void:
 taskbar.draw_style_box(UI.bevel(UI.FACE),Rect2(Vector2.ZERO,taskbar.size))
 # A hairline of the act's neon along the top edge.
 taskbar.draw_rect(Rect2(0,0,taskbar.size.x,1),Color(neon,0.55))
 var tray=Rect2(808,2,288,20)
 taskbar.draw_style_box(UI.bevel(UI.FACE,true),tray)

## Keyboard on the desktop: Enter opens the selected icon, Esc closes menus. True when handled.
func key(event: InputEventKey) -> bool:
 if event.keycode==KEY_ESCAPE and any_popup(): _close_popups(); return true
 if event.keycode in [KEY_ENTER,KEY_KP_ENTER] and selected.size()==1 and active_window().is_empty():
  open(selected.keys()[0]); return true
 if event.keycode==KEY_F4 and event.alt_pressed and not active_window().is_empty():
  close(active_window()); return true
 if event.keycode==KEY_META or event.keycode==KEY_ESCAPE and event.ctrl_pressed: toggle_start(); return true
 return false

## True when motion is off: reduced-motion players and the self-test see everything at rest.
func _still() -> bool:
 return host.reduced_motion or host.self_testing

func _unfold(m: Control) -> void:
 if _still(): return
 m.pivot_offset=Vector2(0,0); m.scale=Vector2(1,0.6); m.modulate.a=0.0
 var tw=m.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
 tw.tween_property(m,"scale",Vector2.ONE,0.12); tw.tween_property(m,"modulate:a",1.0,0.08)

func close_all() -> void:
 _close_popups()
 for id in windows.keys(): close(id)
