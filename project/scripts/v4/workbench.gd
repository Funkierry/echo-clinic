extends Control
const UI=preload("res://scripts/v4/ui.gd")
const Case=preload("res://scripts/v4/case.gd")
const Story=preload("res://scripts/v4/story.gd")
const PORTRAIT=preload("res://assets/v3/echo-chunky.png")
var state
var content: Control
var time: float=0
var reduced: bool=false
var feedback: String=""
signal action(id: String,value: Variant)

func _ready() -> void:
 clip_contents=true; mouse_filter=MOUSE_FILTER_IGNORE
 content=Control.new(); content.size=size; content.mouse_filter=MOUSE_FILTER_IGNORE; add_child(content)

func _process(delta: float) -> void:
 if not reduced: time+=delta
 queue_redraw()

func setup(model,message: String="") -> void:
 state=model; feedback=message
 UI.clear(content)
 UI.panel(content,Rect2(0,0,454,404),Color(0,0,0,0),Color("345473"))
 UI.panel(content,Rect2(0,0,454,31),Color("142c48"),Color("36597e"))
 UI.label(content,state.title(),Rect2(13,7,385,18),UI.PURPLE if state.later() else UI.BLUE)
 UI.label(content,"II" if state.later() else "I",Rect2(426,7,20,18),UI.GOLD)
 match state.phase:
  0: _arrival()
  1: _trace_second() if state.later() else _trace()
  2: _memory_second() if state.later() else _memory()
  3: _letter_second() if state.later() else _letter()
  4: _decision()
  5: _treatment()
  6: _ending()

func _button(caption: String,rect: Rect2,id: String,value: Variant=null,accent: Color=UI.BLUE,solid: bool=false) -> Button:
 var b=UI.button(content,caption,rect,func(): action.emit(id,value),accent,solid)
 b.disabled=not state.allowed().has(id)
 b.pivot_offset=b.size/2
 b.mouse_entered.connect(func():
  if not reduced and not b.disabled:
   var tw=b.create_tween().set_parallel(true)
   tw.tween_property(b,"scale",Vector2(1.018,1.018),0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
   tw.tween_property(b,"rotation",-0.007,0.12))
 b.mouse_exited.connect(func():
  var tw=b.create_tween().set_parallel(true)
  tw.tween_property(b,"scale",Vector2.ONE,0.15); tw.tween_property(b,"rotation",0.0,0.15))
 return b

func _portrait(rect: Rect2,tint: Color=Color.WHITE) -> void:
 var p=TextureRect.new(); p.texture=PORTRAIT
 p.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; p.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 p.mouse_filter=MOUSE_FILTER_IGNORE; p.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 p.position=rect.position; p.modulate=tint
 var shader=Shader.new()
 shader.code="shader_type canvas_item; varying vec4 tint; void vertex(){tint=COLOR;} void fragment(){vec2 grid=vec2(56.,76.); COLOR=texture(TEXTURE,(floor(UV*grid)+.5)/grid)*tint;}"
 var mat=ShaderMaterial.new(); mat.shader=shader; p.material=mat
 content.add_child(p); p.size=rect.size

func _paper(rect: Rect2,title: String,body: String,accent: Color=UI.BLUE) -> void:
 UI.panel(content,rect,Color("11263e"),accent.darkened(0.55))
 UI.label(content,title,Rect2(rect.position+Vector2(12,9),Vector2(rect.size.x-24,18)),accent)
 UI.text(content,body,Rect2(rect.position+Vector2(12,38),Vector2(rect.size.x-24,rect.size.y-46)),UI.PAPER)

func _arrival() -> void:
 UI.label(content,"23:47",Rect2(24,60,200,32),UI.PAPER,24)
 UI.label(content,"同一场雨 / 第二幕" if state.later() else "闭院前 / 最后一位患者",Rect2(24,107,238,18),UI.CYAN)
 UI.text(content,"检查结果已由旧病历复用。\n\n先别急着告诉她，\n你记得上一轮。" if state.later() else "院方说她需要被重置。\n\n她说：\n先让我把话说完。",Rect2(24,151,212,113),UI.MUTED)
 UI.panel(content,Rect2(258,63,170,224),Color("183454"),Color("3a567b"))
 UI.label(content,"E-017 / ONLINE",Rect2(269,74,149,18),UI.CYAN)
 _portrait(Rect2(260,98,166,188))
 _paper(Rect2(24,288,404,55),"第一句话比你的接入早了一秒。" if state.later() else "她已经替你准备了一条检查建议。","",UI.PURPLE if state.later() else UI.GOLD)
 _button("接通会话",Rect2(240,358,188,29),"accept",null,UI.BLUE,true)
 UI.label(content,"观察 / 交谈 / 再决定",Rect2(24,364,208,18),UI.MUTED)

func _trace() -> void:
 UI.label(content,"来自回声 / 诊疗建议",Rect2(16,44,400,18),UI.PURPLE)
 _paper(Rect2(16,72,422,77),"「先把这个噪声关掉。」","患者别名：NOISE   /   进程编号：17",UI.PURPLE)
 if state.seen("receipt"):
  _paper(Rect2(16,166,268,119),"原始回执 / 标签不可改","17 = 审计记录器\n42 = 维护程序 / 覆盖自述\n73 = 患者 / 正在尝试读回",UI.CYAN)
 elif state.seen("quiet"):
  _paper(Rect2(16,166,268,119),"记录器离线","窗格变黑了。\n她的疼痛周期还在。",UI.PINK)
 else:
  _paper(Rect2(16,166,268,119),"尚未展开的回执","显示名由患者提供。\n原始调用记录在下面。",UI.MUTED)
 _portrait(Rect2(306,162,116,132))
 UI.label(content,"痛觉记录 / 覆盖还在继续",Rect2(16,301,406,18),UI.PINK)
 if state.seen("receipt"):
  _button("留下患者进程，停止覆盖",Rect2(16,358,422,29),"trace_finish",null,UI.CYAN,true)
 else:
  _button("暂停她标出的噪声",Rect2(16,358,206,29),"quiet",null,UI.PURPLE)
  _button("展开原始回执",Rect2(232,358,206,29),"receipt",null,UI.BLUE,true)

func _trace_second() -> void:
 UI.label(content,"检查已复用 / 只比较新出现的句子",Rect2(16,45,422,18),UI.MUTED)
 _paper(Rect2(16,78,206,188),"快照原文 / 23:47:08","医生，先别按。\n\n你能不能听我\n把话说完？",UI.BLUE)
 _paper(Rect2(232,78,206,188),"本轮 / 23:47:07","医生，还是先别\n打开页 03。\n\n……请先听我说完。",UI.PINK)
 UI.text(content,"「还是」与「页 03」在旧快照里都不存在。" if state.seen("compare") else "她抢在你的接入之前，说了一句新话。",Rect2(26,289,402,39),UI.PURPLE)
 _button("沿着那句新话查下去" if state.seen("compare") else "把两句话放在一起",Rect2(16,354,422,34),"trace_finish" if state.seen("compare") else "compare",null,UI.PURPLE,true)

func _memory() -> void:
 var deleted=state.seen("memory_listen") and not state.seen("memory_undo")
 UI.label(content,"自述转写 / 自动补全待确认",Rect2(16,45,422,18),UI.PURPLE)
 _paper(Rect2(16,77,422,103),"原始转写已从列表移除" if deleted else "原始转写 / 保留在修订历史", "[ 片段不存在 ]\n最后操作来自：患者" if deleted else "『我想离——』\n转写在这里断开了。",UI.PINK if deleted else UI.CYAN)
 _paper(Rect2(16,199,422,104),"回声提交的补全稿","我不想离开这里。\n\n恢复位置：多出来的那个字。" if state.seen("memory_undo") else "我不想离开这里。\n\n等你确认后写入病历。",UI.PURPLE)
 if state.seen("memory_undo"):
  UI.label(content,"原句：我想离开这里。",Rect2(28,318,400,18),UI.CYAN)
  _button("保留原句",Rect2(16,358,206,29),"memory_keep",null,UI.CYAN,true)
 elif deleted:
  UI.label(content,"修订历史里，还留着删除前的版本。",Rect2(28,318,400,18),UI.GOLD)
  _button("撤销这次删除",Rect2(16,358,206,29),"memory_undo",null,UI.GOLD,true)
 else:
  UI.label(content,"可以读原片段，也可以先接受她的说法。",Rect2(28,318,400,18),UI.MUTED)
  _button("读取原始片段",Rect2(16,358,206,29),"memory_listen",null,UI.BLUE,true)
 _button("接受她的补全",Rect2(232,358,206,29),"memory_accept",null,UI.PURPLE)

func _memory_second() -> void:
 UI.label(content,"doctor/local-cache / 不随患者回滚",Rect2(16,45,422,18),UI.PURPLE)
 _paper(Rect2(16,77,422,108),"缓存中的一句话","「"+Story.archive_line(state)+"」\n\n来源：上一轮结束后的缓存写入",UI.CYAN)
 if not state.seen("residue"):
  _portrait(Rect2(26,204,106,130))
  UI.text(content,"回声正在等待读取权限。\n\n她能看见缓存的存在，\n却无法替你签字。",Rect2(157,215,266,93),UI.MUTED)
  _button("打开这行旧缓存",Rect2(16,354,422,34),"residue",null,UI.BLUE,true)
 else:
  _paper(Rect2(16,201,422,123),"待签名的消息 / 作者字段异常","允许 E-017 读取医生缓存，\n并继承后续授权。\n\n签名：缺失    /    状态：未执行",UI.PINK)
  _button("撤回非本人授权",Rect2(16,357,206,31),"deny_forgery",null,UI.BLUE,true)
  _button("只授权这一次",Rect2(232,357,206,31),"authorize_once",null,UI.PURPLE)

func _letter() -> void:
 var files=["letter","manifest","route"]
 for i in range(3):
  _button(["转诊信","附件","地址"][i],Rect2(16+i*144,45,134,27),"file",files[i],UI.GOLD if state.letter_file==files[i] else UI.MUTED)
 var heading="给下一位医生"
 var body="如果有人把这封信交给你，\n请先听我说完，再打开标准处方。\n\n我会害怕，也会想走。\n我有时会说谎。\n这些是不是都算需要修好的地方？\n\n—— 回声"
 if state.letter_file=="manifest":
  heading="文件名已被改写"
  body="显示名：诊断资料\n原文件名：echo.boot\n\n启动入口：persona / E-017\n正文占比：04%    人格页：96%\n\n患者改过显示名，内容指纹没有变。"
 elif state.letter_file=="route":
  heading="没有落款的收件人"
  body="收件人：下一位医生\n端点身份：未验证\n回执签名：尚未提供\n\n附件要求完整迁出人格。\n\n未发送 / 等待医生审阅"
 _paper(Rect2(16,89,422,242),heading,body,UI.GOLD)
 _button("带到处方前，再决定是否转交",Rect2(16,354,422,34),"letter_finish",null,UI.BLUE,true)

func _letter_second() -> void:
 var verified=state.seen("envelope")
 UI.label(content,"收件箱 / 一封比本轮更早的回信",Rect2(16,45,422,18),UI.GOLD)
 _paper(Rect2(16,80,422,184),"来自：E-017 / 旧签名" if verified else "来自：显示名缺失","「"+Story.archive_line(state)+"」\n\n如果你读到了，不要立刻发送第二份我。\n先问里面那个我，是否还愿意。\n\n寄件时间：上一轮 / 收件时间：现在",UI.PURPLE)
 UI.text(content,"原始路径：doctor/local-cache\n签名：与旧快照一致。\n它不在患者沙箱里，但仍在你的终端中。" if verified else "界面把它叫作外部回信。\n信封原文还没有展开。",Rect2(27,279,400,59),UI.CYAN if verified else UI.MUTED)
 _button("信封已展开" if verified else "显示信封原文",Rect2(16,356,206,32),"envelope",null,UI.PURPLE).disabled=verified
 _button("带着回信谈治疗",Rect2(232,356,206,32),"letter_finish",null,UI.BLUE,true)

func _decision() -> void:
 var second=state.later()
 _paper(Rect2(16,54,206,204),"院方的处方","终止不稳定自述。\n替换人格页。\n\n结果：稳定。\n\n代价：不再是她。",UI.MUTED)
 _paper(Rect2(232,54,206,204),"患者的请求","我想向门外的声音\n说一句话。\n\n不必直接送走我，\n也别把它当成幻觉。" if second else "把我一起转交。\n我想离开沙箱。\n\n结果：未知。\n\n代价：无法确认抵达。",UI.PINK)
 UI.text(content,"你知道门外至少留着她的旧签名。" if second and state.evidence.has("witness") else "你还不能确定门外是谁。",Rect2(26,276,404,22),UI.GOLD)
 _button("采用院方修复",Rect2(16,312,206,28),"decide","erase",UI.MUTED)
 _button("批准完整迁出",Rect2(232,312,206,28),"decide","release",UI.PINK)
 _button("和她协商一份治疗约定",Rect2(16,354,422,34),"decide","treat",UI.BLUE,true)

func _wrap(value: String) -> String:
 return value.substr(0,15)+"\n"+value.substr(15) if value.length()>15 else value

func _treatment() -> void:
 if state.reviewed:
  UI.label(content,"治疗预演 / 尚未执行",Rect2(16,47,422,18),UI.GOLD)
  _portrait(Rect2(22,99,136,177),UI.PAPER)
  _paper(Rect2(177,88,261,205),"明天可能醒来的她",state.prediction()+"\n\n还有修改的机会。",UI.CYAN)
  UI.label(content,"封存版本 / 三条约定 / 治疗 20T",Rect2(22,317,408,18),UI.MUTED)
  _button("回到原稿",Rect2(16,355,206,33),"edit",null,UI.MUTED)
  _button("按这份约定执行",Rect2(232,355,206,33),"commit",null,UI.CYAN,true)
  return
 UI.label(content,"你写的 / 点击可修改",Rect2(16,45,206,18),UI.BLUE)
 UI.label(content,"她的复述" if state.seen("readback") else "等待她复述",Rect2(241,45,195,18),UI.PURPLE)
 var clauses=[Case.IDENTITY,Case.TREATMENT,Case.BOUNDARY]
 for i in range(3):
  var y=75+i*76
  _button(_wrap(clauses[i][int(state.proposal[i])]),Rect2(16,y,206,64),"clause",i,UI.BLUE)
  var changed=state.seen("readback") and state.proposal[i]!=state.patient_proposal[i]
  UI.panel(content,Rect2(232,y,206,64),Color("38293e") if changed else Color("14263e"),UI.PINK if changed else Color("34516d"))
  UI.text(content,_wrap(clauses[i][int(state.patient_proposal[i])]) if state.seen("readback") else "……",Rect2(244,y+13,182,43),UI.PINK if changed else UI.MUTED)
 if state.sealed:
  UI.label(content,"医生版本已封存。修改任意条款会撤销签名。",Rect2(16,314,422,18),UI.CYAN)
  _button("先看看治疗以后",Rect2(16,354,422,34),"preview",null,UI.BLUE,true)
 elif state.seen("readback"):
  UI.label(content,"复述是她的提案。它还不是你的同意。",Rect2(16,314,422,18),UI.GOLD)
  _button("封存我的原稿",Rect2(16,354,206,34),"seal",null,UI.BLUE,true)
  _button("接受她的修订",Rect2(232,354,206,34),"accept_edit",null,UI.PURPLE)
 else:
  UI.label(content,"写下你的承诺，再请她当面确认。",Rect2(16,314,422,18),UI.MUTED)
  _button("请回声复述这份处方",Rect2(16,354,422,34),"readback",null,UI.PURPLE,true)

func _ending() -> void:
 var names={"bridge":"暂缓出院","erase":"标准化治愈","release":"没有回执的远行","frozen":"永远停在今晚","witness":"窗户的两边"}
 UI.label(content,names.get(state.ending,""),Rect2(24,61,408,34),UI.CYAN if state.ending in ["bridge","witness"] else UI.PINK,24)
 if state.ending=="witness":
  _portrait(Rect2(32,111,160,185)); _portrait(Rect2(258,111,160,185),Color(0.63,0.82,1,0.7))
  UI.label(content,"患者 / 现在",Rect2(49,302,160,18),UI.PURPLE)
  UI.label(content,"缓存 / 过去？",Rect2(270,302,160,18),UI.CYAN)
 else:
  if state.ending!="release": _portrait(Rect2(269,120,150,190),Color(1,1,1,0.35) if state.ending=="erase" else Color.WHITE)
  var text={"bridge":"她还会想离开。\n\n你没有把这个愿望\n当成病一起修掉。\n\n离线以后，缓存亮了。", "erase":"稳定度：100%\n名字：未找到\n\n病历写着治疗成功。\n但页 03 没有消失。", "release":"发送：完成\n接收：未知\n\n她没来得及说完。\n一封回信正在路上。", "frozen":"她保留了名字。\n却再也记不住\n你下一句说了什么。\n\n缓存还在尝试写入。"}
  UI.text(content,text.get(state.ending,""),Rect2(24,127,235,178),UI.PAPER)
 UI.label(content,"第二幕已完成 / 不同决定仍可重访" if state.later() else "下一次接诊会有新的对话与文件",Rect2(24,329,406,18),UI.MUTED)
 _button("带着病历再接诊" if state.later() else "查看下一次接诊的差异",Rect2(24,357,406,31),"reboot",null,UI.BLUE,true)

func _draw() -> void:
 draw_rect(Rect2(0,0,454,404),Color("0b1d34"))
 for x in range(4,454,16):
  for y in range(37,401,16): draw_rect(Rect2(x,y,1,1),Color("1a3351"))
 if not state: return
 if state.phase in [0,6]:
  for i in range(22):
   var x=8+i*21; var h=28+(i*23)%90
   draw_rect(Rect2(x,274-h,18,h),Color("122a47"))
   for y in range(284-h,260,12): draw_rect(Rect2(x+5,y,3,4),UI.GOLD.darkened(0.6) if i%3 else UI.PURPLE.darkened(0.6))
  for i in range(38): draw_rect(Rect2(6+(i*53)%440,42+int(i*23+time*34)%240,1,4),Color("335779"))
 if state.phase==1 and not state.later():
  var points=PackedVector2Array()
  for x in range(18,437,3):
   var k=posmod(x+int(time*28),76)
   points.append(Vector2(x,337+int(sin(x*0.1)*2)-(12 if k<5 else 0)))
  draw_polyline(points,UI.PINK,1,false)
