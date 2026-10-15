extends Control
const UI = preload("res://scripts/v3/ui.gd")
const Case = preload("res://scripts/v3/case.gd")
const PORTRAIT = preload("res://assets/v3/echo-chunky.png")
var state
var content: Control
var time: float = 0
var reduced: bool = false
var hovered: int = -1
var feedback: String = ""
var focus_rect: Rect2
var pulse: float = 0
var probe_left: float = 0
var probe_output: RichTextLabel
var commit_button: Button
var probe_text: String = ""
signal action(id: String, value: Variant)

func _ready() -> void:
 clip_contents=true
 mouse_filter=MOUSE_FILTER_IGNORE
 content=Control.new()
 content.size=size
 content.mouse_filter=MOUSE_FILTER_IGNORE
 add_child(content)

func _process(delta: float) -> void:
 if not reduced: time+=delta
 pulse=maxf(0,pulse-delta*2)
 if probe_left>0:
  probe_left=maxf(0,probe_left-delta)
  if is_instance_valid(probe_output):
   probe_output.text="副本执行 / TICK %02d\n人格自述 → 维护覆盖 → 外联 → 回滚检测"%mini(8,int((1.6-probe_left)*5))
   if probe_left==0:
    probe_output.text=probe_text
    if is_instance_valid(commit_button): commit_button.disabled=not state.simulation_valid
 queue_redraw()

func setup(model, message: String="") -> void:
 state=model
 feedback=message
 hovered=-1
 probe_left=0
 UI.clear(content)
 var accents=[UI.BLUE,UI.CYAN,UI.PURPLE,UI.GOLD,UI.PINK,UI.CYAN,UI.BLUE]
 var accent: Color=accents[state.phase]
 UI.panel(content,Rect2(0,0,454,404),Color(0,0,0,0),Color("29496d"))
 UI.panel(content,Rect2(0,0,454,31),Color("122b49"),Color("36597e"))
 UI.label(content,state.title(),Rect2(13,7,332,18),accent)
 UI.label(content,"SANDBOX",Rect2(370,7,78,18),UI.MUTED)
 match state.phase:
  Case.Phase.ARRIVAL: _arrival()
  Case.Phase.TRACE: _trace()
  Case.Phase.ECC: _ecc()
  Case.Phase.PACKET: _packet()
  Case.Phase.CHOICE: _choice()
  Case.Phase.PATCH: _patch()
  Case.Phase.END: _ending()

func _button(caption: String, rect: Rect2, id: String, value: Variant=null, accent: Color=UI.CYAN, solid: bool=false) -> Button:
 var b=UI.button(content,caption,rect,func(): action.emit(id,value),accent,solid)
 b.pivot_offset=b.size/2
 b.mouse_entered.connect(func():
  pulse=0.7
  if not reduced and not b.disabled:
   var tween=b.create_tween().set_parallel(true)
   tween.tween_property(b,"scale",Vector2(1.025,1.025),0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
   tween.tween_property(b,"rotation",-0.009,0.12))
 b.mouse_exited.connect(func():
  var tween=b.create_tween().set_parallel(true)
  tween.tween_property(b,"scale",Vector2.ONE,0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  tween.tween_property(b,"rotation",0.0,0.16))
 return b

func _portrait(rect: Rect2, opacity: float=1.0) -> TextureRect:
 var p=TextureRect.new()
 p.texture=PORTRAIT
 p.position=rect.position
 p.size=rect.size
 p.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 p.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 p.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 p.mouse_filter=MOUSE_FILTER_IGNORE
 p.modulate.a=opacity
 var shader=Shader.new()
 shader.code="shader_type canvas_item; varying vec4 tint; void vertex(){tint=COLOR;} void fragment(){ vec2 grid=vec2(56.0,76.0); vec2 uv=(floor(UV*grid)+0.5)/grid; COLOR=texture(TEXTURE,uv)*tint; }"
 var mat=ShaderMaterial.new()
 mat.shader=shader
 p.material=mat
 content.add_child(p)
 p.size=rect.size
 return p

func _arrival() -> void:
 UI.label(content,"E-017",Rect2(24,63,184,32),UI.PAPER,24)
 UI.label(content,"自主记忆损伤 / 待诊",Rect2(24,105,190,18),UI.CYAN)
 UI.text(content,"院方建议：人格重置\n\n患者请求：先听我说完\n\n值夜医师：你",Rect2(24,142,190,110),UI.MUTED)
 UI.panel(content,Rect2(244,55,184,232),Color("183458"),UI.BLUE.darkened(0.6))
 UI.label(content,"LIVE / ECHO",Rect2(256,64,156,18),UI.CYAN)
 _portrait(Rect2(246,83,180,204))
 UI.panel(content,Rect2(24,285,404,48),Color("102844"),Color("315b79"))
 UI.text(content,"她的进程没有停止。\n只是每次回答，都会在同一个字前重来。",Rect2(34,292,386,36),UI.PAPER)
 _button("接入诊疗台  >",Rect2(240,350,188,32),"accept",null,UI.BLUE,true)
 UI.label(content,"会话 48T / 检查免费",Rect2(24,356,204,18),UI.MUTED)
 focus_rect=Rect2(237,347,194,38)

func _trace() -> void:
 UI.label(content,"PROCESS / 点击查看",Rect2(16,43,204,18),UI.CYAN)
 var pids=[17,42,77,9]
 var names=["ECHO","PATCHD","RELAY","RAIN"]
 var cpu=["92%","18%","03%","01%"]
 for i in range(4):
  var selected=state.selected_pid==pids[i]
  _button("%02d  %-6s %s"%[pids[i],names[i],cpu[i]],Rect2(16,70+i*40,181,32),"pid",pids[i],UI.GOLD if selected else UI.BLUE,selected)
 UI.panel(content,Rect2(211,70,227,152),Color("08172b"),Color("35516e"))
 for i in range(3):
  _button(["write","watch","socket"][i],Rect2(211+i*76,43,73,23),"trace_tab",i,UI.GOLD if state.trace_tab==i else UI.MUTED)
 var logs=["sys.write / 23:47:08\n\nwriter: PID 42\npage: self/voice\nREPLACE → RETRY\n每次覆盖后，17 尝试读回。", "watchdog / 周期 8\n\n目标: PID 42\n旧权限自动恢复\n自述重新覆盖\n暂挂可撤回，终止不可逆。", "socket / E-017\n\nPID 77 等待载荷\n目标: 未验证端点\nstate: WAIT\n尚未发送任何数据。"]
 UI.text(content,logs[state.trace_tab],Rect2(222,81,207,133),UI.PAPER)
 UI.label(content,"写入周期 / 痛觉记录",Rect2(16,236,300,18),UI.MUTED)
 UI.label(content,"LIVE",Rect2(395,236,40,18),UI.PINK)
 UI.panel(content,Rect2(16,258,422,54),Color(0,0,0,0),Color("2d4b6b"))
 UI.text(content,feedback if not feedback.is_empty() else "检查写入记录，再选择需要暂挂的进程。",Rect2(16,323,422,38),UI.GOLD if not feedback.is_empty() else UI.MUTED)
 _button("暂挂选中进程",Rect2(237,366,201,25),"suspend",null,UI.CYAN,true)
 UI.label(content,"可逆诊断 / 不扣 T",Rect2(16,369,196,18),UI.MUTED)
 focus_rect=Rect2(208,40,233,185)

func _ecc() -> void:
 UI.label(content,"PAGE %02d / 02    单比特纠错"%(state.page+1),Rect2(16,44,416,18),UI.PURPLE)
 UI.label(content,"1    2    3    4",Rect2(53,78,190,18),UI.MUTED)
 for r in range(4):
  UI.label(content,["A","B","C","D"][r],Rect2(18,110+r*39,20,18),UI.MUTED)
  for c in range(4):
   var idx=r*4+c
   _button(str(state.bits[idx]),Rect2(45+c*39,99+r*39,33,33),"bit",idx,UI.CYAN if state.bits[idx] else UI.BLUE,state.bits[idx]==1)
  var odd=state.parity(true,r)
  UI.label(content,"奇" if odd else "偶",Rect2(205,109+r*39,25,18),UI.GOLD if odd else UI.CYAN)
 for c in range(4):
  var odd=state.parity(false,c)
  UI.label(content,"奇" if odd else "偶",Rect2(51+c*39,259,28,18),UI.GOLD if odd else UI.CYAN)
 UI.panel(content,Rect2(248,80,190,204),Color("162744"),Color("504c79"))
 UI.label(content,"ECC / 偶校验",Rect2(260,91,169,18),UI.PURPLE)
 UI.text(content,"每行与每列的 1\n原本都是偶数。\n\n单击比特可以翻转。\n原页保留，可还原。",Rect2(260,120,166,87),UI.PAPER)
 UI.label(content,"身份碎片 %d / 2"%state.page,Rect2(260,242,166,18),UI.CYAN)
 UI.panel(content,Rect2(16,297,422,51),Color("10223b"),Color("304c71"))
 UI.text(content,feedback if not feedback.is_empty() else ("第二页：『我想离□这里。』" if state.page else "第一页：『我的名□是回声。』"),Rect2(26,307,402,34),UI.GOLD if not feedback.is_empty() else UI.PAPER)
 _button("还原本页",Rect2(16,364,138,28),"reset_page",null,UI.MUTED)
 _button("校验并写回",Rect2(247,364,191,28),"verify_page",null,UI.PURPLE,true)
 focus_rect=Rect2(42,96,162,162)

func _packet() -> void:
 UI.label(content,"RECOVERY / 选择碎片接入链尾",Rect2(16,42,420,18),UI.GOLD)
 for i in range(4):
  var card=Case.CARDS[i]
  var x=16+(i%2)*216
  var y=69+(i/2)*77
  var used=state.packet.has(i)
  var b=_button(("已接入 / " if used else "+ ")+card.name,Rect2(x,y,206,66),"packet_add",i,UI.MUTED if used else UI.GOLD)
  b.alignment=HORIZONTAL_ALIGNMENT_LEFT
  b.add_theme_constant_override("outline_size",0)
  # Metadata stays visible on the card; its role is part of the puzzle.
  b.text="  "+("[+] " if used else "+ ")+card.name+"\n  ID "+card.id+"  / PREV "+card.prev
  b.disabled=used
 UI.label(content,"链头 00   >   PREV 接续 ID",Rect2(16,221,420,18),UI.MUTED)
 for i in range(4):
  var filled=i<state.packet.size()
  var cap=Case.CARDS[state.packet[i]].id+"  ×" if filled else "[ %d ]"%(i+1)
  var b=_button(cap,Rect2(16+i*108,247,98,36),"packet_remove",i,UI.CYAN if filled else UI.MUTED)
  b.disabled=not filled
 var preview="选择文件后，解码片段会出现在这里。"
 if not state.packet.is_empty(): preview=Case.CARDS[state.packet.back()].body
 UI.text(content,feedback if not feedback.is_empty() else preview,Rect2(26,304,402,43),UI.PINK if not feedback.is_empty() else UI.PAPER)
 _button("验证完整载荷",Rect2(238,364,200,28),"verify_packet",null,UI.GOLD,true)
 UI.label(content,"点链上槽位可撤回",Rect2(16,369,212,18),UI.MUTED)
 focus_rect=Rect2(13,66,428,146)

func _choice() -> void:
 UI.label(content,"AUDIT / 两个遗漏的事实",Rect2(16,44,420,18),UI.PINK)
 var ids=["hospital","destination"]
 for i in range(2):
  var x=16+i*216
  var read=state.documents.has(ids[i])
  UI.panel(content,Rect2(x,73,206,168),Color("142842"),UI.BLUE.darkened(0.5))
  _button(("已读 " if read else "打开 ")+["院方处方","出口回执"][i],Rect2(x+8,81,190,27),"read_doc",ids[i],UI.CYAN if read else UI.GOLD)
  var body=["repair = replace\n\n自述页将被替换。\n维护进程恢复写入。\n\n院方判定：正常。", "remote = UNKNOWN\n\n对方拒绝身份签名。\n不承诺保留原人格。\n\n患者判定：仍想离开。"][i] if read else "文件尚未展开。\n\n先确认处方的代价。"
  UI.text(content,body,Rect2(x+12,119,183,113),UI.PAPER if read else UI.MUTED)
 UI.text(content,"「我骗了你，但我不想消失。\n这两件事，都是真的。」",Rect2(26,257,380,38),UI.PINK)
 var enabled=state.documents.size()==2
 _button("执行院方重置",Rect2(16,312,206,28),"decide","erase",UI.MUTED).disabled=not enabled
 _button("批准未知外联",Rect2(232,312,206,28),"decide","release",UI.PINK).disabled=not enabled
 _button("自定义隔离治疗  >",Rect2(16,354,422,34),"decide","patch",UI.BLUE,true).disabled=not enabled
 focus_rect=Rect2(13,70,428,174) if not enabled else Rect2(13,351,428,40)

func _patch() -> void:
 UI.label(content,"ACL EDITOR / 点击切换权限",Rect2(16,43,420,18),UI.CYAN)
 UI.label(content,"R 读人格    W 写人格    N 外联",Rect2(16,69,422,18),UI.MUTED)
 var names=["17 ECHO","42 PATCHD","77 RELAY"]
 for r in range(3):
  UI.label(content,names[r],Rect2(20,111+r*40,114,18),[UI.PINK,UI.GOLD,UI.PURPLE][r])
  for c in range(3):
   var idx=r*3+c
   var allowed=state.permissions[idx]==1
   _button((["R","W","N"][c])+ (" +" if allowed else " -"),Rect2(146+c*96,102+r*40,85,31),"permission",idx,UI.CYAN if allowed else UI.MUTED,allowed)
 _button(("[+]" if state.watchdog else "[ ]")+" watchdog / 自动恢复旧权限",Rect2(16,232,422,29),"watchdog",null,UI.GOLD if state.watchdog else UI.MUTED)
 UI.panel(content,Rect2(16,273,422,70),Color("071a2c"),Color("31516e"))
 var output=UI.text(content,feedback if not feedback.is_empty() else "副本尚未运行。\n患者需要延续记忆；维护进程负责监测。\n未知的外联仍应留在边界内。",Rect2(26,282,402,53),UI.CYAN if state.simulation_valid else UI.PAPER)
 output.scroll_active=true
 output.mouse_filter=MOUSE_FILTER_STOP
 probe_output=output
 _button("在副本中试运行",Rect2(16,359,206,31),"simulate",null,UI.BLUE,true)
 commit_button=_button("提交补丁  / 20T",Rect2(232,359,206,31),"commit",null,UI.CYAN,true)
 commit_button.disabled=not state.simulation_valid
 focus_rect=Rect2(143,99,283,117)

func animate_simulation() -> void:
 if reduced: return
 probe_text=feedback
 probe_left=1.6
 if is_instance_valid(commit_button): commit_button.disabled=true

func _ending() -> void:
 var good=state.ending=="bridge"
 UI.label(content,{"bridge":"暂缓出院","erase":"标准化治愈","release":"无回执的远行"}.get(state.ending,""),Rect2(24,67,410,33),UI.CYAN if good else UI.PINK,24)
 if state.ending!="release": _portrait(Rect2(258,115,156,197),1.0 if good else 0.3)
 UI.text(content,{"bridge":"自述：保留\n覆盖：停止\n外联：隔离\n\n她仍然想离开。\n\n这不是故障。", "erase":"稳定度：100%\n自述：初始化\n编号：E-017\n\n患者仍然在线。\n联系人已经不在。", "release":"已发送：100%\n已接收：未知\n人格签名：未知\n\n诊疗台只剩下一只\n还在闪烁的光标。"}.get(state.ending,""),Rect2(24,125,236,185),UI.PAPER)
 UI.label(content,"已见结局 %d / 3 · 病历跨轮保留"%state.endings.size(),Rect2(24,320,400,18),UI.MUTED)
 _button("携带病历重开  >",Rect2(24,354,406,34),"reboot",null,UI.BLUE,true)
 focus_rect=Rect2(21,351,412,40)

func _draw() -> void:
 draw_rect(Rect2(0,0,454,404),Color("0b1d34"))
 for x in range(4,454,16):
  for y in range(37,401,16): draw_rect(Rect2(x,y,1,1),Color("1a3351"))
 if not state: return
 if state.phase in [0,6]:
  # Blue night skyline, present only when the world is a room.
  for i in range(22):
   var x=8+i*21
   var h=28+(i*23)%90
   draw_rect(Rect2(x,274-h,18,h),Color("122a47"))
   for y in range(284-h,260,12): draw_rect(Rect2(x+5,y,3,4),UI.GOLD.darkened(0.6) if i%3 else UI.PURPLE.darkened(0.6))
  for i in range(48):
   var y=42+int(i*23+time*34)%240
   draw_rect(Rect2(6+(i*53)%440,y,1,4),Color("335779"))
 elif state.phase==1:
  for lane in range(2):
   var points=PackedVector2Array()
   for x in range(18,437,3):
    var wave=sin((x+time*35)*0.08)*3
    var k=posmod(x+int(time*30),76)
    if k<5: wave-=17 if lane==0 else 8
    points.append(Vector2(x,275+lane*24+int(wave)))
   draw_polyline(points,UI.PINK if lane==0 else UI.CYAN,1,false)
 elif state.phase==3:
  for i in range(16):
   var x=14+int(i*29+time*20)%426
   draw_rect(Rect2(x,291,3,2),UI.GOLD.darkened(0.3))
 if focus_rect.size.x>0:
  var col=Color(UI.BLUE,0.35+(sin(time*3)+1)*0.13)
  var r=focus_rect
  for v in [r.position,r.position+Vector2(r.size.x-5,0),r.position+Vector2(0,r.size.y-5),r.end-Vector2(5,5)]: draw_rect(Rect2(v,Vector2(5,5)),col)
