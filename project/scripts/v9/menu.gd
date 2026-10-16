extends Control
## Title screen, pause menu, save/load slots and settings in one full-screen overlay.
const UI=preload("res://scripts/v9/ui.gd")
const Saves=preload("res://scripts/v9/saves.gd")
const Ascii=preload("res://scripts/v9/ascii_portrait.gd")
const Juice=preload("res://scripts/v9/juice.gd")
var app
var mode: String="title"
var back_mode: String="title"
var content: Control
var time: float=0.0
var drops: Array=[]
var notice: String=""

func setup(main) -> void:
 app=main; size=Vector2(1100,600); z_index=130
 mouse_filter=MOUSE_FILTER_STOP
 content=Control.new(); content.size=size; content.mouse_filter=MOUSE_FILTER_IGNORE; add_child(content)
 for i in range(90): drops.append(Vector2(randf()*1100,randf()*600))

func open(next: String,from: String="") -> void:
 if not from.is_empty(): back_mode=from
 mode=next; notice=""
 visible=true
 render()

func render() -> void:
 UI.clear(content)
 match mode:
  "title": _title()
  "pause": _pause()
  "load","save": _slots()
  "settings": _settings()
  "confirm_new": _confirm_new()

func _process(delta: float) -> void:
 time+=delta
 for i in range(drops.size()):
  drops[i].y+=delta*(220+(i%7)*30); drops[i].x-=delta*30
  if drops[i].y>600: drops[i]=Vector2(randf()*1150,-10)
 queue_redraw()

func _draw() -> void:
 var title=mode in ["title","confirm_new"] or back_mode=="title"
 draw_rect(Rect2(Vector2.ZERO,size),Color(UI.BG,1.0 if title else 0.9))
 for i in range(drops.size()):
  draw_line(drops[i],drops[i]+Vector2(-3,10),Color(UI.LINE.lightened(0.3),0.35 if title else 0.15),1.0)

func _button(caption: String,rect: Rect2,cb: Callable,color: Color=UI.BLUE,solid: bool=false) -> Button:
 var b=UI.button(content,caption,rect,cb,color,solid)
 b.add_theme_font_size_override("font_size",14)
 return b

# --- screens -------------------------------------------------------------------

func _title() -> void:
 var portrait=Ascii.new(); content.add_child(portrait)
 portrait.setup(Rect2(640,70,330,450),"calm",true)
 UI.label(content,"night-shift@017:~$ ./echo_clinic",Rect2(90,84,500,18),UI.DIM,11)
 var logo=UI.label(content,"ECHO.CLINIC",Rect2(86,110,520,64),UI.BLUE,48)
 logo.add_theme_font_override("font",UI.mono())
 var sub=UI.label(content,"回声诊所 · 闭院前的最后一位患者",Rect2(90,178,520,24),UI.PAPER,16)
 sub.add_theme_font_override("font",UI.sans())
 var y=250
 var has_auto=Saves.exists("auto")
 if has_auto:
  var m=Saves.meta("auto")
  _button("继续",Rect2(90,y,280,40),func(): app.menu_continue(),UI.CYAN,true)
  UI.label(content,_describe(m),Rect2(386,y+11,240,18),UI.MUTED,10)
  y+=52
 _button("新的夜班",Rect2(90,y,280,40),func(): open("confirm_new") if has_auto else app.menu_new_game(),UI.BLUE,not has_auto); y+=52
 _button("读取存档",Rect2(90,y,280,40),func(): open("load","title"),UI.PURPLE); y+=52
 _button("设置",Rect2(90,y,280,40),func(): open("settings","title"),UI.MUTED); y+=52
 _button("退出",Rect2(90,y,280,40),func(): app.get_tree().quit(),UI.MUTED)
 UI.label(content,"v0.8.3 · 声音和动效可在设置里调整 · Esc 暂停",Rect2(90,560,520,16),UI.DIM,10)

func _confirm_new() -> void:
 UI.panel(content,Rect2(300,190,500,200),Color("101a2c"),UI.GOLD)
 var t=UI.text(content,"开始新的夜班会覆盖“自动存档”。\n手动存的三个存档位不受影响。",Rect2(330,220,440,60),UI.PAPER)
 t.add_theme_font_override("normal_font",UI.sans()); t.add_theme_font_size_override("normal_font_size",14)
 _button("开始新的夜班",Rect2(330,320,200,40),func(): app.menu_new_game(),UI.GOLD,true)
 _button("返回",Rect2(550,320,200,40),func(): open("title"),UI.MUTED)

func _pause() -> void:
 UI.panel(content,Rect2(380,120,340,360),Color("0c1424"),UI.BLUE)
 UI.label(content,"暂停",Rect2(410,138,280,30),UI.BLUE,22)
 var y=190
 _button("继续",Rect2(410,y,280,38),func(): app.menu_resume(),UI.CYAN,true); y+=48
 _button("保存",Rect2(410,y,280,38),func(): open("save","pause"),UI.BLUE); y+=48
 _button("读取存档",Rect2(410,y,280,38),func(): open("load","pause"),UI.PURPLE); y+=48
 _button("设置",Rect2(410,y,280,38),func(): open("settings","pause"),UI.MUTED); y+=48
 _button("回到标题",Rect2(410,y,280,38),func(): app.menu_to_title(),UI.MUTED)

func _describe(m: Dictionary) -> String:
 if m.is_empty(): return "空"
 return "第 %02d 夜 · %s · 钱包 %dT"%[int(m.get("night",1)),str(m.get("title","")),int(m.get("balance",0))]

func _slots() -> void:
 var saving=mode=="save"
 UI.label(content,"保存到存档位" if saving else "读取存档",Rect2(140,50,600,32),UI.BLUE,22)
 var y=100
 for slot in Saves.SLOTS:
  var m=Saves.meta(slot)
  UI.panel(content,Rect2(140,y,820,100),Color("0c1424"),UI.LINE if m.is_empty() else UI.BLUE)
  var thumb=TextureRect.new(); thumb.position=Vector2(150,y+8); thumb.size=Vector2(152,84)
  thumb.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; thumb.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
  if not str(m.get("thumb","")).is_empty():
   var img=Image.load_from_file(ProjectSettings.globalize_path(m.thumb))
   if img: thumb.texture=ImageTexture.create_from_image(img)
  content.add_child(thumb)
  UI.label(content,"自动存档" if slot=="auto" else "存档 %s"%slot,Rect2(318,y+12,200,20),UI.GOLD if slot=="auto" else UI.CYAN,13)
  var line=UI.label(content,_describe(m),Rect2(318,y+38,440,20),UI.PAPER if not m.is_empty() else UI.DIM,12)
  line.add_theme_font_override("font",UI.sans())
  UI.label(content,str(m.get("saved_at","")),Rect2(318,y+64,300,16),UI.DIM,10)
  var x=770
  if saving and slot!="auto":
   _button("覆盖" if not m.is_empty() else "保存",Rect2(x,y+30,80,36),func(): _save_to(slot),UI.BLUE,true); x+=90
  if not saving and not m.is_empty():
   _button("读取",Rect2(x,y+30,80,36),func(): app.menu_load(slot),UI.CYAN,true); x+=90
  if not m.is_empty() and slot!="auto" and not saving:
   _button("删除",Rect2(x,y+30,80,36),func(): Saves.erase(slot); render(),UI.PINK)
  y+=112
 if not notice.is_empty(): UI.label(content,notice,Rect2(140,552,600,18),UI.GOLD,12)
 _button("返回",Rect2(780,548,180,36),func(): open(back_mode),UI.MUTED)

func _save_to(slot: String) -> void:
 notice="已保存到存档 %s。"%slot if app.menu_save(slot) else "保存失败，请检查磁盘空间。"
 Sfx.play("stamp")
 render()

func _settings() -> void:
 UI.panel(content,Rect2(330,110,440,380),Color("0c1424"),UI.BLUE)
 UI.label(content,"设置",Rect2(360,128,300,30),UI.BLUE,22)
 var rows=[
  ["声音",not app.muted,func(): app._toggle_mute(); render()],
  ["动效",not app.reduced_motion,func(): app._toggle_motion(); render()],
  ["教学提示",app.coach.enabled,func(): app.coach.set_enabled(not app.coach.enabled); app._save_preferences(); render()],
 ]
 var y=180
 for r in rows:
  var l=UI.label(content,r[0],Rect2(362,y+8,160,20),UI.PAPER,14); l.add_theme_font_override("font",UI.sans())
  _button("开" if r[1] else "关",Rect2(600,y,140,36),r[2],UI.CYAN if r[1] else UI.MUTED,r[1])
  y+=50
 _button("重新显示所有教学",Rect2(362,y,378,36),func(): app.coach.reset(); app._save_preferences(); notice="教学提示会重新出现。"; render(),UI.GOLD); y+=50
 _button("AI 设置",Rect2(362,y,378,36),func(): app._show_ai_settings(); app.modal.z_index=140,UI.PURPLE); y+=50
 if not notice.is_empty(): UI.label(content,notice,Rect2(362,y,378,18),UI.GOLD,11)
 _button("返回",Rect2(362,440,378,36),func(): open(back_mode),UI.MUTED)
