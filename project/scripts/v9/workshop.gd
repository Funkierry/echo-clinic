extends Control
## 夜班外包 · 缓存命中. Full-screen overlay; the clinic waits underneath.
const UI=preload("res://scripts/v9/ui.gd")
const Job=preload("res://scripts/v9/cache_job.gd")
const Juice=preload("res://scripts/v9/juice.gd")
const LANE=Rect2(150,250,800,150)
var profile
var case_state
var content: Control
var lane: Control
var hud: Label
var job=null
var notice=""
var result_amount: int=0
var reduced: bool=false
var flash: float=0.0
var flash_color: Color=UI.CYAN
signal changed
signal closed
signal intel_found(id: String)

func setup(p,s=null) -> void:
 profile=p; case_state=s; size=Vector2(1100,600)
 content=Control.new(); content.size=size; add_child(content)
 render()

func render() -> void:
 UI.clear(content)
 var shade=ColorRect.new(); shade.size=size; shade.color=Color(0.01,0.02,0.05,0.97); content.add_child(shade)
 UI.panel(content,Rect2(90,35,920,530),UI.BG,UI.CYAN)
 UI.tab(content,"night-shift / outsourcing",Vector2(104,28))
 UI.label(content,"夜班外包 · 缓存命中",Rect2(112,53,420,30),UI.CYAN,22)
 UI.label(content,"钱包 %dT   今晚还能接 %d 单"%[profile.balance,Profile_jobs_left()],Rect2(585,62,360,22),UI.GOLD)
 UI.button(content,"×",Rect2(961,49,30,30),_close,UI.MUTED)
 var lamp=profile.contacts.has("lamp")
 UI.label(content,"灯芯 / L-003 · 诊所的设备助手",Rect2(115,100,400,20),UI.PURPLE,12)
 var intro="「这些请求都在问同样的事，只是说法不同。帮我把它们对上号，省下来的算力归你。」" if not lamp else "「今晚的流量我帮你盯着。对上一个，省一份算力。」"
 UI.text(content,intro+"\n完成 %d 单外包后，灯芯会恢复说话。（已完成 %d 单）"%[3,profile.completed] if not lamp else intro,Rect2(115,124,866,44),UI.PAPER)
 if job==null:
  _menu()
 else:
  _play_view()

func Profile_jobs_left() -> int:
 return maxi(0,3-int(profile.jobs_tonight))

func _menu() -> void:
 UI.panel(content,Rect2(115,190,866,250),Color(1,1,1,0.02),UI.LINE)
 var rules="规则\n· 请求从右往左流过来。按下和它意思相同的缓存回答（也可以按 1–4）。\n· 连续答对，倍率会升高；答错或漏掉，倍率归零。\n· 偶尔会混进一条没有客户编号的粉色请求。别回答它，按空格或点「抓取」把它截下来。\n· 每单 45 秒，最多赚 12T。一夜最多接 3 单。"
 UI.text(content,rules,Rect2(135,205,826,130),UI.PAPER)
 if not notice.is_empty(): UI.text(content,notice,Rect2(135,345,826,40),UI.GOLD)
 var b=UI.button(content,"接单 · 开始 45 秒" if profile.can_take_job() else "今晚的外包已经接满了",Rect2(135,392,300,36),_start,UI.CYAN,true)
 b.disabled=not profile.can_take_job()
 b.name="StartJob"
 UI.button(content,"回诊室",Rect2(455,392,200,36),_close,UI.BLUE)

func _start() -> void:
 if not profile.can_take_job(): return
 job=Job.new(); job.setup(profile.next_job_id())
 notice=""
 changed.emit()
 render()

func _play_view() -> void:
 hud=UI.label(content,"",Rect2(115,190,866,22),UI.GOLD,13)
 lane=Control.new(); lane.position=LANE.position; lane.size=LANE.size; lane.mouse_filter=MOUSE_FILTER_IGNORE; content.add_child(lane)
 lane.draw.connect(_draw_lane)
 UI.label(content,"缓存 ←",Rect2(LANE.position.x-60,LANE.position.y+LANE.size.y/2-10,60,20),UI.DIM,11)
 for i in range(4):
  var b=UI.button(content,"%d  %s"%[i+1,Job.ANSWERS[i]],Rect2(150+i*162,430,150,40),func(): _answer(i),[UI.BLUE,UI.CYAN,UI.PURPLE,UI.GOLD][i])
  b.name="Answer%d"%i
 var grab=UI.button(content,"空格  抓取",Rect2(150+4*162,430,152,40),_grab,UI.PINK)
 grab.name="Grab"
 UI.text(content,"按住节奏，先答最左边那条。",Rect2(150,488,700,24),UI.MUTED)

func _draw_lane() -> void:
 if job==null: return
 var w=LANE.size.x; var h=LANE.size.y
 lane.draw_rect(Rect2(0,0,w,h),Color(UI.LINE,0.25))
 lane.draw_line(Vector2(0,0),Vector2(0,h),Color(UI.PINK,0.7),2.0)
 for i in range(job.live.size()):
  var r=job.live[i]
  var x=float(r.x)*(w-180)
  var y=18+(i%3)*42
  var fragment=int(r.answer)<0
  var col=UI.PINK if fragment else (UI.PAPER if i==0 else UI.MUTED)
  var box=Rect2(x,y,176,32)
  lane.draw_rect(box,Color(col,0.12 if i>0 else 0.22))
  lane.draw_rect(box,Color(col,0.8),false,1.0)
  lane.draw_string(UI.sans(),Vector2(x+8,y+21),str(r.text),HORIZONTAL_ALIGNMENT_LEFT,164,12,col)
  lane.draw_string(UI.mono(),Vector2(x+8,y-3),"client: —" if fragment else "client: #%04d"%(1000+(i*37+job.spawned*13)%9000),HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color(col,0.6))
 if flash>0.0: lane.draw_rect(Rect2(0,0,w,h),Color(flash_color,flash*0.25))

func _process(delta: float) -> void:
 if job==null: return
 flash=maxf(0.0,flash-delta*3.0)
 for e in job.step(delta):
  if e=="miss":
   flash=1.0; flash_color=UI.PINK
   Sfx.play("miss"); Juice.shake(3.0)
 if is_instance_valid(hud):
  hud.text="剩余 %02ds   连击 %d   倍率 ×%.1f   预计 +%dT   %s"%[maxi(0,int(Job.DURATION-job.time)),job.combo,job.multiplier(),job.payout(),"已截获碎片" if job.fragment_caught else ""]
 if is_instance_valid(lane): lane.queue_redraw()
 if job.finished(): _finish()

func _unhandled_key_input(event: InputEvent) -> void:
 if job==null or not event is InputEventKey or not event.pressed or event.echo: return
 if event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4]: _answer(event.keycode-KEY_1); get_viewport().set_input_as_handled()
 elif event.keycode==KEY_SPACE: _grab(); get_viewport().set_input_as_handled()

func _answer(i: int) -> void:
 if job==null: return
 var r=job.answer(i)
 flash=1.0; flash_color=UI.CYAN if r=="hit" else UI.PINK
 var b=content.get_node_or_null("Answer%d"%i)
 if r=="hit":
  # Each hit in a combo climbs in pitch, like chips stacking up.
  Sfx.play("combo",1.0+minf(job.combo,14)*0.055)
  if b:
   Juice.punch(b,0.14)
   Juice.float_text(b.get_global_rect().get_center()+Vector2(0,-24),"×%.1f"%job.multiplier(),UI.GOLD if job.combo>=3 else UI.CYAN,14+mini(job.combo,8))
   if job.combo>0 and job.combo%3==0: Juice.burst(b.get_global_rect().get_center(),UI.GOLD,14)
 elif r=="wrong":
  Sfx.play("miss"); Juice.shake(2.5)

func _grab() -> void:
 if job==null: return
 var r=job.grab()
 flash=1.0; flash_color=UI.PURPLE if r=="fragment" else UI.PINK
 if r=="fragment":
  Sfx.play("reveal"); Juice.burst(lane.get_global_rect().position+Vector2(60,60),UI.PURPLE,26)
 elif r=="wrong": Sfx.play("miss")

func _finish() -> void:
 var amount=job.payout()
 var caught=job.fragment_caught
 var lamp_before=profile.contacts.has("lamp")
 profile.credit_job(job.id,amount)
 notice="外包 #%03d 完成：答对 %d，最高连击 %d，+%dT。"%[job.id,job.hits,job.best,amount]
 if caught:
  notice+="\n截获一条没有客户编号的消息：「%s」灯芯：「咦，这条像是有人在流量里写日记。」"%Job.FRAGMENTS[job.id%Job.FRAGMENTS.size()]
  intel_found.emit("fragment")
 if not lamp_before and profile.contacts.has("lamp"): notice+="\n灯芯恢复了说话，已经出现在左侧休息室。"
 job=null
 changed.emit(); render()

func _close() -> void:
 # Leaving mid-job forfeits it but does not use up a slot.
 job=null
 closed.emit()
