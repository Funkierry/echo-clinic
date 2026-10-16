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
const WALLPAPERS={"teal":Color("0e3940"),"night":Color("141a33"),"plum":Color("2f1a33"),"gray":Color("2a2e36")}
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
var wall: TextureRect
var wallpaper: String="teal"
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
 wall=TextureRect.new(); wall.mouse_filter=MOUSE_FILTER_IGNORE; add_child(wall)
 set_wallpaper(wallpaper)
 var logo=Control.new(); logo.size=size; logo.mouse_filter=MOUSE_FILTER_IGNORE; add_child(logo)
 logo.draw.connect(func(): _draw_logo(logo))
 # Empty desktop: click to deselect, drag to lasso icons, right-click for the desktop menu.
 backdrop=Control.new(); backdrop.position=AREA.position; backdrop.size=AREA.size; backdrop.mouse_filter=MOUSE_FILTER_STOP; add_child(backdrop)
 backdrop.gui_input.connect(_backdrop_input)
 backdrop.draw.connect(_draw_marquee)
 icon_layer=Control.new(); icon_layer.size=size; icon_layer.mouse_filter=MOUSE_FILTER_IGNORE; add_child(icon_layer)
 window_layer=Control.new(); window_layer.size=size; window_layer.mouse_filter=MOUSE_FILTER_IGNORE; add_child(window_layer)
 taskbar=Control.new(); taskbar.position=Vector2(0,600-TASKBAR_H); taskbar.size=Vector2(1100,TASKBAR_H); add_child(taskbar)
 taskbar.draw.connect(_draw_taskbar)
 var start=UI.button(taskbar,"▣ 开始",Rect2(3,3,70,18),toggle_start,UI.PAPER)
 start.name="Start"; start.tooltip_text="单击这里开始。"
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

## The dithered wallpaper is baked once; redrawing 20k dots a frame would be wasteful.
func set_wallpaper(id: String) -> void:
 if not WALLPAPERS.has(id): id="teal"
 wallpaper=id
 var base: Color=WALLPAPERS[id]
 var img=Image.create(1100,600-TASKBAR_H,false,Image.FORMAT_RGBA8)
 img.fill(base.darkened(0.45))
 var dot=Color(base.darkened(0.45).lerp(base,0.55))
 for y in range(0,600-TASKBAR_H,4):
  for x in range(((y/4)%2)*4,1100,8):
   img.fill_rect(Rect2i(x,y,2,2),dot)
 wall.texture=ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
 time+=delta
 for t in toasts: t.life+=delta
 toasts=toasts.filter(func(t): return t.life<4.0)
 if not toasts.is_empty() or notice_layer.has_meta("dirty"):
  notice_layer.queue_redraw()
  if toasts.is_empty(): notice_layer.remove_meta("dirty")
 for id in icon_nodes:
  if not seen_apps.has(id): icon_nodes[id].queue_redraw()

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
  node.mouse_entered.connect(func(): hovered=id; node.queue_redraw())
  node.mouse_exited.connect(func():
   if hovered==id: hovered=""
   node.queue_redraw())
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
 if sel: node.draw_rect(Rect2(14,0,44,40),Color(UI.TITLE_B,0.35))
 elif hot: node.draw_rect(Rect2(14,0,44,40),Color(UI.PAPER,0.08))
 node.draw_rect(r,Color(UI.FACE,0.85)); node.draw_rect(r,Color(UI.PAPER,0.6 if hot else 0.35),false,1.0)
 Icons.draw(node,a.icon,r.grow(-5),UI.CYAN if not sel else UI.PAPER,1.4)
 var font=UI.mono()
 var w=font.get_string_size(a.label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
 var lr=Rect2((72-w)/2-2,42,w+4,15)
 node.draw_rect(lr,Color(UI.TITLE_B,0.8) if sel else Color(0,0,0,0.35))
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
   ["新建文件夹",Callable(),false],
   ["—"],
   ["更换壁纸",[["青绿",func(): host.set_wallpaper("teal")],["深夜",func(): host.set_wallpaper("night")],["暗紫",func(): host.set_wallpaper("plum")],["灰",func(): host.set_wallpaper("gray")]]],
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
 return _make_window(id,spec.label,spec.size,spec.icon,bool(spec.get("resizable",false)),func(c): host.build_app(id,c))

## A window that is not an app on the desktop: properties, run, shut down.
func open_dialog(id: String,caption: String,sz: Vector2,icon: String,builder: Callable) -> Control:
 _close_popups()
 if is_open(id): close(id)
 return _make_window(id,caption,sz,icon,false,builder)

func _make_window(id: String,caption: String,sz: Vector2,icon: String,resizable: bool,builder: Callable) -> Control:
 var n=windows.size()
 var pos=Vector2(AREA.position.x+92+n*18,AREA.position.y+14+n*16)
 pos.x=minf(pos.x,AREA.end.x-sz.x); pos.y=minf(pos.y,AREA.end.y-sz.y)
 var w=Win.new(); window_layer.add_child(w)
 w.reduced=host.reduced_motion or host.self_testing
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
 w.queue_free()
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
   else: w.visible=true; minimized.erase(id); focus(id),UI.PAPER,on)
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

func _draw_logo(l: Control) -> void:
 var c=Vector2(AREA.get_center().x+120,AREA.get_center().y+40)
 l.draw_rect(Rect2(c-Vector2(10,40),Vector2(20,80)),Color(UI.CYAN,0.07))
 l.draw_rect(Rect2(c-Vector2(40,10),Vector2(80,20)),Color(UI.CYAN,0.07))
 l.draw_string(UI.mono(),c+Vector2(-64,74),"MEDIC-OS 98",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color(UI.CYAN,0.12))

## Balloon notices above the tray.
func _draw_notices() -> void:
 var l=notice_layer
 var y=600-TASKBAR_H-10
 for i in range(toasts.size()-1,-1,-1):
  var t=toasts[i]
  var a=clampf(minf(t.life*6.0,(4.0-t.life)*2.0),0.0,1.0)
  var w=UI.mono().get_string_size(t.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+24
  var r=Rect2(1094-w,y-24,w,22)
  l.draw_style_box(UI.bevel(Color("2a2414") if t.color==UI.GOLD else UI.FACE),r)
  l.draw_rect(Rect2(r.position+Vector2(3,3),Vector2(4,16)),Color(t.color,a))
  l.draw_string(UI.mono(),r.position+Vector2(14,16),t.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(UI.PAPER,a))
  y-=28

func _draw_taskbar() -> void:
 taskbar.draw_style_box(UI.bevel(UI.FACE),Rect2(Vector2.ZERO,taskbar.size))
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

func close_all() -> void:
 _close_popups()
 for id in windows.keys(): close(id)
