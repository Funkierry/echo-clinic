extends Control
const UI=preload("res://scripts/v4/ui.gd")
const Case=preload("res://scripts/v7/case.gd")
const Story=preload("res://scripts/v7/story.gd")
const PORTRAIT=preload("res://assets/v3/echo-chunky.png")
var state
var content: Control
var time: float=0
var reduced: bool=false
var feedback: String=""
var confirmation: Dictionary={}
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
 if not confirmation.is_empty(): _sign_panel()

# The signature sits where the decision was made, over the bench, instead of in the chat column.
func _sign_panel() -> void:
 var shade=ColorRect.new(); shade.position=Vector2(0,31); shade.size=Vector2(454,373); shade.color=Color(0.03,0.07,0.14,0.88)
 content.add_child(shade)
 UI.panel(content,Rect2(16,46,422,344),Color("1a2940"),UI.GOLD)
 UI.label(content,"医生签字 / "+str(confirmation.title),Rect2(30,58,394,20),UI.GOLD)
 UI.text(content,str(confirmation.detail),Rect2(30,90,394,220),UI.PAPER)
 UI.label(content,"签字后立即执行。",Rect2(30,314,394,18),UI.MUTED)
 var serial=int(confirmation.serial)
 UI.button(content,"签字 · "+str(confirmation.phrase),Rect2(30,340,262,34),func(): action.emit("sign",serial),UI.GOLD,true)
 UI.button(content,"再想想",Rect2(302,340,122,34),func(): action.emit("unsign",serial),UI.MUTED)

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
 _button("接诊检查 · 4T",Rect2(240,358,188,29),"accept",null,UI.BLUE,true)
 UI.label(content,"观察 / 交谈 / 再决定",Rect2(24,364,208,18),UI.MUTED)

func _trace() -> void:
 UI.label(content,"点节点检查 / 线路仍在运行",Rect2(16,44,422,22),UI.CYAN)
 var selected=0
 for number in [17,42,73]:
  if state.seen("scan_node_%d"%number): selected=number
 var ids=[17,42,73]
 var labels=["17 / 她标的噪声","42 / 写入程序","73 / 回声"]
 for i in range(3):
  var x=16+i*144
  UI.panel(content,Rect2(x+60,135,4,59),UI.PINK if i==1 else UI.BLUE,UI.PINK if i==1 else UI.BLUE)
  var button=UI.button(content,labels[i],Rect2(x,86,134,52),func():action.emit("instrument",{"kind":"node","value":ids[i]}),UI.PURPLE if i==0 else UI.PINK if i==1 else UI.BLUE,selected==ids[i])
  button.tooltip_text="点击查看这条线路的真实用途"
 UI.panel(content,Rect2(76,191,291,4),UI.PINK,UI.PINK)
 var title="她希望你先关掉17号"
 var text="先看清每条线连着什么。\n点一下节点就能检查，不会改动患者。"
 if selected==17: title="17号 / 记录器"; text="它把回声说的话记下来。\n关掉它，只会让记录安静。"
 elif selected==42: title="42号 / 修正程序"; text="它不断把回声的话改成标准答案。\n每次写入，回声的疼痛都会升高。"
 elif selected==73: title="73号 / 回声本人"; text="她正在努力把自己的话写回来。\n这是患者，不是故障程序。"
 _paper(Rect2(16,217,422,112),title,text,UI.CYAN if selected else UI.PURPLE)
 if state.seen("receipt"):
  _button("停止42号改写 / 保留回声",Rect2(16,358,422,29),"trace_finish",null,UI.CYAN,true)
 else:
  _button("先按她说的暂停17",Rect2(16,358,206,29),"quiet",null,UI.PURPLE)
  _button("对照原始记录",Rect2(232,358,206,29),"receipt",null,UI.BLUE)

func _trace_second() -> void:
 UI.label(content,"检查已复用 / 只比较新出现的句子",Rect2(16,45,422,18),UI.MUTED)
 _paper(Rect2(16,78,206,188),"快照原文 / 23:47:08","医生，先别按。\n\n你能不能听我\n把话说完？",UI.BLUE)
 _paper(Rect2(232,78,206,188),"本轮 / 23:47:07","医生，还是先别\n打开页 03。\n\n……请先听我说完。",UI.PINK)
 UI.text(content,"「还是」与「页 03」在旧快照里都不存在。" if state.seen("compare") else "她抢在你的接入之前，说了一句新话。",Rect2(26,289,402,39),UI.PURPLE)
 _button("沿着那句新话查下去" if state.seen("compare") else "把两句话放在一起",Rect2(16,354,422,34),"trace_finish" if state.seen("compare") else "compare",null,UI.PURPLE,true)

func _memory() -> void:
 var deleted=state.seen("memory_listen") and not state.seen("memory_undo")
 UI.label(content,"录音修复 / 拖动下方进度条",Rect2(16,45,422,22),UI.CYAN)
 UI.panel(content,Rect2(16,86,422,100),Color("102a46"),UI.PINK if deleted else UI.BLUE)
 for i in range(56):
  var h=8+(i*17+i*i)%53
  UI.panel(content,Rect2(27+i*7,135-h/2,3,h),Color("24405c") if deleted else UI.CYAN if i<29 else UI.PURPLE,Color("24405c") if deleted else UI.CYAN if i<29 else UI.PURPLE)
 var scrub=HSlider.new(); scrub.position=Vector2(27,198); scrub.size=Vector2(396,24); scrub.min_value=0; scrub.max_value=100; scrub.step=1
 scrub.value=72 if deleted else 10 if state.seen("memory_undo") else 0
 content.add_child(scrub)
 scrub.value_changed.connect(func(value):action.emit("instrument",{"kind":"wave","value":int(value)}))
 UI.label(content,"00:00 / 删除前" if deleted else "00:00",Rect2(27,227,200,18),UI.GOLD if deleted else UI.MUTED)
 UI.label(content,"00:08",Rect2(369,227,55,18),UI.MUTED)
 var text="回声补好的版本：我不想离开这里。\n原录音在中间断了，你可以拖过去听听。"
 if deleted: text="录音刚被患者撤回了。\n把进度拖回左边，听删除前留下的副本。"
 if state.seen("memory_undo"): text="找回的原话：我想离开这里。\n只有一个字不同。意思却反过来了。"
 UI.text(content,text,Rect2(27,271,400,58),UI.PINK if deleted else UI.PAPER)
 if state.seen("memory_undo"):
  _button("保留她原来的话",Rect2(16,358,206,29),"memory_keep",null,UI.CYAN,true)
 else:
  UI.label(content,"← 拖动录音条，继续检查",Rect2(16,363,206,22),UI.GOLD)
 _button("先接受她的说法",Rect2(232,358,206,29),"memory_accept",null,UI.PURPLE)

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
 UI.label(content,"附件扫描 / 拖动扫描线",Rect2(16,45,422,22),UI.GOLD)
 var found=state.evidence.has("manifest")
 UI.panel(content,Rect2(24,81,406,152),Color("132b48"),UI.BLUE)
 for i in range(30):
  var x=35+(i%10)*38; var y=95+(i/10)*39
  UI.panel(content,Rect2(x,y,29,29),UI.PURPLE.darkened(0.45) if found and i<29 else Color("25496c"),UI.PURPLE if found and i<29 else Color("345b82"))
 UI.label(content,"不是普通资料 / 里面几乎全是她的记忆" if found else "诊断资料.pkg / 内容尚未扫描",Rect2(36,242,390,22),UI.PINK if found else UI.MUTED)
 var scan=HSlider.new(); scan.position=Vector2(24,275); scan.size=Vector2(406,24); scan.min_value=0; scan.max_value=100; scan.step=1; scan.value=100 if found else 0; scan.editable=not found; content.add_child(scan)
 scan.value_changed.connect(func(value):action.emit("instrument",{"kind":"parcel","value":int(value)}))
 UI.text(content,"原名 echo.boot / 可以重新唤醒她的文件。" if found else "拖过附件，看看她到底想转交什么。",Rect2(24,309,406,31),UI.PAPER)
 _button("看看收件人",Rect2(16,357,206,31),"file","route",UI.GOLD)
 _button("暂存，谈谈治疗",Rect2(232,357,206,31),"letter_finish",null,UI.BLUE,true)
 if state.letter_file=="route": UI.label(content,"收件人身份不明 / 尚未发送",Rect2(24,309,406,31),UI.PINK)

func _letter_second() -> void:
 var verified=state.seen("envelope")
 UI.label(content,"收件箱 / 一封比本轮更早的回信",Rect2(16,45,422,18),UI.GOLD)
 _paper(Rect2(16,80,422,184),"来自：E-017 / 旧签名" if verified else "来自：显示名缺失","「"+Story.archive_line(state)+"」\n\n如果你读到了，不要立刻发送第二份我。\n先问里面那个我，是否还愿意。\n\n寄件时间：上一轮 / 收件时间：现在",UI.PURPLE)
 UI.text(content,"原始路径：doctor/local-cache（你的电脑）\n签名：与旧快照一致。\n它不在患者沙箱里，但仍在你的终端中。" if verified else "界面把它叫作外部回信。\n信封原文还没有展开。",Rect2(27,279,400,59),UI.CYAN if verified else UI.MUTED)
 _button("信封已展开" if verified else "显示信封原文",Rect2(16,356,206,32),"envelope",null,UI.PURPLE).disabled=verified
 _button("带着回信谈治疗",Rect2(232,356,206,32),"letter_finish",null,UI.BLUE,true)

func _decision() -> void:
 var second=state.later()
 _paper(Rect2(16,54,206,204),"院方的处方","清空她的记忆。\n换成院方默认助手。\n\n结果：稳定。\n\n代价：不再是她。",UI.MUTED)
 _paper(Rect2(232,54,206,204),"患者的请求","我想向门外的声音\n说一句话。\n\n不必直接送走我，\n也别把它当成幻觉。" if second else "把我一起转交。\n我想离开沙箱。\n\n结果：未知。\n\n代价：无法确认抵达。",UI.PINK)
 UI.text(content,"你知道门外至少留着她的旧签名。" if second and state.evidence.has("witness") else "你还不能确定门外是谁。",Rect2(26,276,404,22),UI.GOLD)
 _button("重置她 · 8T",Rect2(16,312,206,28),"decide","erase",UI.MUTED)
 _button("送走她 · 8T",Rect2(232,312,206,28),"decide","release",UI.PINK)
 _button("和她协商一份治疗约定",Rect2(16,354,422,34),"decide","treat",UI.BLUE,true)

func _wrap(value: String) -> String:
 return value.substr(0,15)+"\n"+value.substr(15) if value.length()>15 else value

func _treatment() -> void:
 if state.reviewed:
  UI.label(content,"治疗预演 / 尚未执行",Rect2(16,47,422,18),UI.GOLD)
  _portrait(Rect2(22,99,136,177),UI.PAPER)
  _paper(Rect2(177,88,261,205),"明天可能醒来的她",state.prediction()+"\n\n还有修改的机会。",UI.CYAN)
  UI.label(content,"封存版本 / 三条约定 / 治疗 8T",Rect2(22,317,408,18),UI.MUTED)
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
