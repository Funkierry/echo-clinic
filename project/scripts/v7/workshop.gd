extends Control
const UI=preload("res://scripts/v4/ui.gd")
var profile
var content: Control
var notice=""
var status: Label
signal changed
signal closed

func setup(p) -> void:
 profile=p; size=Vector2(1100,600)
 content=Control.new(); content.size=size; add_child(content)
 render()

func render() -> void:
 UI.clear(content)
 var shade=ColorRect.new(); shade.size=size; shade.color=Color(0.01,0.03,0.08,0.96); content.add_child(shade)
 UI.panel(content,Rect2(90,35,920,530),Color("0d2139"),UI.BLUE)
 UI.label(content,"夜班维修站",Rect2(112,53,360,30),UI.CYAN,24)
 UI.label(content,"钱包 %dT / 每单 +6T / 免费进入"%profile.balance,Rect2(585,62,360,22),UI.GOLD)
 UI.button(content,"×",Rect2(961,49,30,30),func():closed.emit(),UI.MUTED)
 UI.label(content,"灯芯 / 诊所的设备助手",Rect2(115,106,300,20),UI.PURPLE)
 UI.text(content,"「我把线路、节拍和存储都弄乱了。你修设备，我把省下的算力交给你。」\n三种设备各修一次，灯芯就能恢复说话。诊疗暂停在原处；工单随时续做。" if not profile.contacts.has("lamp") else "「现在这些小毛病，我能帮你盯着了。你空下来时，记得来聊天。」\n维修站长期开放。没有入场费、倒计时或失败罚款；工单可以稍后接着做。",Rect2(115,133,866,43),UI.PAPER)
 if profile.job.is_empty():
  var types=["route","signal","memory"]
  var titles=["01 / 接通线路","02 / 对齐节拍","03 / 清理坏块"]
  var tips=["转动接头，把入口连到出口。\n修的是线路，不用读代码。","拖动推杆，让三个信号归位。\n没有节奏判定，慢慢调就好。","点击格子，翻转它和相邻格。\n让坏块全部熄灭。"]
  for i in range(3):
   var x=115+i*290
   UI.panel(content,Rect2(x,207,270,211),Color("142e4a"),[UI.BLUE,UI.PURPLE,UI.CYAN][i])
   UI.label(content,titles[i],Rect2(x+15,226,245,24),[UI.BLUE,UI.PURPLE,UI.CYAN][i])
   UI.text(content,tips[i],Rect2(x+15,274,241,60),UI.PAPER)
   UI.button(content,"接单 · +6T",Rect2(x+15,366,240,34),func():profile.start_job(types[i]); changed.emit(); render(),[UI.BLUE,UI.PURPLE,UI.CYAN][i],true)
   UI.label(content,"已修复" if profile.work_types.has(types[i]) else "灯芯恢复进度 · 待修复",Rect2(x+10,436,250,20),UI.CYAN if profile.work_types.has(types[i]) else UI.MUTED)
  UI.text(content,notice if not notice.is_empty() else "修复设备 → 结算 6T → 接诊 / 聊天。任何时候都能回来，不用重开剧情。",Rect2(115,492,866,38),UI.GOLD)
  return
 var kind=str(profile.job.kind)
 UI.label(content,"工单 #%03d / %s"%[profile.job.id,{"route":"线路断开","signal":"信号失步","memory":"坏块干扰"}[kind]],Rect2(115,190,500,22),UI.CYAN)
 status=UI.label(content,"",Rect2(615,190,340,22),UI.GOLD)
 if kind=="route":
  UI.label(content,"入口 →",Rect2(120,248,84,24),UI.CYAN)
  UI.label(content,"→ 出口",Rect2(521,424,100,24),UI.CYAN)
  for i in range(9):
   var b=UI.button(content,"",Rect2(221+(i%3)*88,230+(i/3)*88,80,80),func():move(i),UI.BLUE)
   var mask=int(profile.job.data[i])
   b.draw.connect(func():
    for port in range(4):
     if mask&(1<<port): b.draw_line(Vector2(40,40),Vector2(40,40)+[Vector2(0,-40),Vector2(40,0),Vector2(0,40),Vector2(-40,0)][port],UI.CYAN,5)
    b.draw_rect(Rect2(35,35,10,10),UI.PAPER))
  UI.text(content,"点击转动接头\n\n把所有线路接成一条通路。\n亮线相接，才算接通。",Rect2(638,249,310,100),UI.PAPER)
 elif kind=="signal":
  for i in range(3):
   UI.label(content,["输入","缓存","输出"][i],Rect2(180+i*137,234,110,22),[UI.BLUE,UI.PURPLE,UI.CYAN][i])
   var slider=VSlider.new(); slider.min_value=0; slider.max_value=6; slider.step=1; slider.value=profile.job.data[i]
   slider.position=Vector2(208+i*137,275); slider.custom_minimum_size=Vector2(32,170); content.add_child(slider)
   var target_y=440-float(profile.job.target[i])/6.0*160
   UI.panel(content,Rect2(184+i*137,target_y,80,4),UI.CYAN,UI.CYAN)
   UI.label(content,"目标 %d"%profile.job.target[i],Rect2(180+i*137,461,110,20),UI.CYAN)
   slider.value_changed.connect(func(value):move(i,int(value),false))
  UI.text(content,"拖动三个推杆\n\n让推杆停在绿色刻线。\n三个信号归位后即可结算。",Rect2(638,249,310,100),UI.PAPER)
 else:
  for i in range(9):
   var bad=int(profile.job.data[i])==1
   UI.button(content,"×" if bad else "·",Rect2(221+(i%3)*88,230+(i/3)*88,80,80),func():move(i),UI.PINK if bad else UI.CYAN,bad)
  UI.text(content,"点击翻转坏块\n\n当前格和上下左右一起翻转。\n让所有粉色 × 熄灭。\n\n乱了也没关系，可以用辅助。",Rect2(638,249,310,130),UI.PAPER)
 UI.button(content,"辅助 / 修正一步",Rect2(638,391,320,34),assist,UI.MUTED)
 var claim=UI.button(content,"结算工单 · +6T",Rect2(638,446,320,40),claim_work,UI.GOLD,true)
 claim.name="ClaimWork"; claim.disabled=not profile.solved()
 UI.button(content,"暂存，回诊室",Rect2(638,509,320,29),func():closed.emit(),UI.BLUE)
 update_status()

func update_status() -> void:
 if profile.job.is_empty(): return
 status.text="修复完成 / 等待结算" if profile.solved() else "已操作 %d 次 / 随时可离开"%profile.job.moves
 var claim=content.get_node_or_null("ClaimWork")
 if claim: claim.disabled=not profile.solved()

func move(index: int,value: int=0,rebuild: bool=true) -> void:
 if not profile.move(index,value): return
 changed.emit()
 if rebuild: render()
 else: update_status()

func assist() -> void:
 if profile.job.is_empty() or profile.solved(): return
 var j=profile.job
 if j.kind=="route":
  for i in range(9):
   if int(j.data[i])!=int(j.target[i]): move(i); return
 elif j.kind=="signal":
  for i in range(3):
   if j.data[i]!=j.target[i]: move(i,int(j.target[i])); return
 else:
  # Only 512 possibilities; show one legal move from a real solution.
  for mask in range(1,512):
   var data=j.data.duplicate()
   for i in range(9):
    if mask&(1<<i): profile._toggle(data,i)
   if data.count(1)==0:
    for i in range(9):
     if mask&(1<<i): move(i); return

func claim_work() -> void:
 var lamp_before=profile.contacts.has("lamp")
 if not profile.claim_job(): return
 notice="结算成功 +6T。钱已入钱包；本工单不能重复领取。"
 if not lamp_before and profile.contacts.has("lamp"): notice="灯芯恢复了！它已经出现在左侧联系人中。+6T 已到账。"
 changed.emit(); render()
