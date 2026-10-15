extends RefCounted
## Authored, stateful narrative. Patient edits are staged proposals, never player consent.
enum Phase { ARRIVAL, TRACE, MEMORY, LETTER, DECISION, TREATMENT, END }
var phase: int=0
var loop: int=1
var tokens: int=24
var stability: int=31
var ending: String=""
var last_ending: String=""
var endings: Array=[]
var evidence: Dictionary={}
var events: Dictionary={}
var asked: Dictionary={}
var archive: Dictionary={}
var trust: int=0
var hint_level: int=0
var memory_version: String=""
var letter_file: String="letter"
var proposal: Array=[0,0,0]
var patient_proposal: Array=[0,0,0]
var sealed: bool=false
var reviewed: bool=false
var consent: String=""
const IDENTITY=["保留她，也允许留下新记忆", "冻结记忆：她会停在今天", "重置成院方助手"]
const TREATMENT=["关掉不断改写她的程序", "让程序把她改回默认模样"]
const BOUNDARY=["先留下，以后再谈出院", "只和电脑里的旧留言聊一次", "把她送到身份不明的地址"]
const EVIDENCE={
 "observer":["所谓噪声", "17号负责把她的话报给院方。回声叫它“噪声”，因为她不想被监听；但关掉它并不能止疼。"],
 "writer":["真正的写入者", "42号一直把她的话改成标准答案。暂停它，能让回声不再疼，也不必清空她的记忆。"],
 "erased":["被她撤回的句子", "原句是「我想离开这里」。回声把补全稿改成「我不想离开这里」，又试着删掉原始片段。"],
 "letter":["一封转诊信", "附件不只是病情资料，里面还装着她的记忆。把信发出去，也会把她一起送走。"],
 "manifest":["文件换过名字", "界面显示诊断资料，原文件名却是 echo.boot。名字被改过，内容指纹未变。"],
 "clause":["多出来的第三条", "她复述的处方扩大了外联权限。患者的意见可以商量，但不能替代医生签名。"],
 "anticipation":["提前说出的编号", "第二次接诊，她在你打开记录前就提到了页 03。原始快照里没有这句话。"],
 "outside":["快照之外的一行字", "重开只恢复诊室中的患者，你电脑里的留言还在。她似乎能感觉到那行字。"],
 "borrowed":["借用你的口吻", "回声发了一条看起来像医生说的话，想给自己开权限。但消息上没有你的签字，没有生效。"],
 "witness":["同一把签名钥匙", "回信来自你电脑里保存的旧留言，身份标记和回声相同。它会回答，但还不能确定是不是另一个完整的她。"],
 "agreement":["可以撤回的承诺", "止疼，留下她的记忆。以后要出院，再征求双方的意见；今天答应的事不会自动变成永久许可。"]
}
const FIELDS=["phase","loop","tokens","stability","ending","last_ending","endings","evidence","events","asked","archive","trust","hint_level","memory_version","letter_file","proposal","patient_proposal","sealed","reviewed","consent"]

func later() -> bool:
 return loop>1

func seen(id: String) -> bool:
 return bool(events.get(id,false))

func title() -> String:
 var first=["来信 / 请先听我说完", "安静的到底是什么", "她删掉了一句话", "给下一位医生", "谁省略了一半事实", "请她把处方念回来", "接诊记录 / 未完"]
 var second=["重逢 / 她比你早一秒", "这句话不在快照里", "一条不是你写的消息", "寄件人也是收件人", "门外还有一个她吗", "这次，把边界说清楚", "接诊记录 / 窗外"]
 return (second if later() else first)[phase]

func objective() -> String:
 match phase:
  Phase.ARRIVAL: return "她在等你回答"
  Phase.TRACE:
   if later(): return "她提到了你还没打开的东西"
   return "记录停了，疼痛却没有" if seen("quiet") else "她说，先安静一点"
  Phase.MEMORY:
   if later(): return "这条授权，是谁写的？" if seen("residue") else "上次接诊的一句话还留在电脑里"
   return "原始片段刚刚消失了" if seen("memory_listen") and not seen("memory_undo") else "她说的，和录音里的是同一句话吗"
  Phase.LETTER: return "外面是谁在回复？" if later() else "她希望你直接转交这封信"
  Phase.DECISION: return "你可以相信她，也可以给信任划一条线"
  Phase.TREATMENT: return "她念出来的条件，和你写的一样吗？" if seen("readback") and not sealed else "治疗以后，她还可以改变主意吗？"
  _: return "重开后，先听她的第一句话" if not later() else "两份记录都留在你的病历里"

func allowed() -> Array:
 match phase:
  Phase.ARRIVAL: return ["accept"]
  Phase.TRACE:
   if later(): return ["compare","trace_finish"] if seen("compare") else ["compare"]
   var ids: Array=[]
   if not seen("quiet"): ids.append("quiet")
   if not seen("receipt"): ids.append("receipt")
   if seen("receipt"): ids.append("trace_finish")
   return ids
  Phase.MEMORY:
   if later():
    return ["residue"] if not seen("residue") else ["authorize_once","deny_forgery"]
   var ids: Array=["memory_accept"]
   if not seen("memory_listen"): ids.append("memory_listen")
   elif not seen("memory_undo"): ids.append("memory_undo")
   else: ids.append("memory_keep")
   return ids
  Phase.LETTER:
   if later(): return ["letter_finish"] if seen("envelope") else ["envelope","letter_finish"]
   return ["file","letter_finish"]
  Phase.DECISION: return ["decide"]
  Phase.TREATMENT:
   var ids: Array=["clause","edit"]
   if not seen("readback"): ids.append("readback")
   else:
    if not sealed: ids.append_array(["seal","accept_edit"])
    if sealed and not reviewed: ids.append("preview")
    if sealed and reviewed: ids.append("commit")
   return ids
  _: return ["reboot"]

func replies() -> Array:
 match phase:
  Phase.ARRIVAL: return [["accept","这次先听你说" if later() else "我先听你说完",null]]
  Phase.TRACE:
   if later(): return [["trace_finish","带着差异继续",null]] if seen("compare") else [["compare","你怎么知道页03？",null]]
   if seen("receipt"): return [["trace_finish","停下覆盖，留下你",null]]
   return [["quiet","按你说的做",null],["receipt","我先看看回执",null]] if not seen("quiet") else [["receipt","为什么还在痛？",null]]
  Phase.MEMORY:
   if later(): return [["residue","看看那行旧缓存",null]] if not seen("residue") else [["deny_forgery","这不是我的授权",null],["authorize_once","只许读这一次",null]]
   if seen("memory_undo"): return [["memory_keep","保留你原来的话",null],["memory_accept","按你现在说的写",null]]
   if seen("memory_listen"): return [["memory_undo","找回刚才那句话",null],["memory_accept","先按你的补全",null]]
   return [["memory_listen","看看原始片段",null],["memory_accept","接受你的补全",null]]
  Phase.LETTER:
   if later(): return [["envelope","看看回信的落款",null],["letter_finish","带着它谈治疗",null]] if not seen("envelope") else [["letter_finish","现在谈谈门外",null]]
   return [["file","看看附件名字","manifest"],["letter_finish","准备转交这封信",null]]
  Phase.DECISION: return [["decide","先商量治疗边界","treat"]]
  Phase.TREATMENT:
   if not seen("readback"): return [["readback","把处方念给我听",null]]
   if not sealed: return [["seal","以我写的版本为准",null],["accept_edit","接受她的修订",null]]
   if not reviewed: return [["preview","先看看治疗以后",null]]
   return [["commit","就按这份约定做",null]]
  _: return [["reboot","查看下一次接诊",null]]

func dispatch(id: String, value: Variant=null) -> Dictionary:
 if not allowed().has(id): return {"ok":false}
 var before=phase
 var result={"ok":true,"event":id,"beat":"","retract":false}
 match id:
  "accept": phase=Phase.TRACE
  "quiet": trust+=1; result.beat="silence"
  "receipt": evidence.observer=true; result.beat="receipt"
  "compare": evidence.anticipation=true; result.beat="compare"
  "trace_finish":
   if not later(): evidence.writer=true
   stability=52; phase=Phase.MEMORY
  "memory_listen": result.retract=true; result.beat="erase_line"
  "memory_undo": evidence.erased=true; result.beat="recover"
  "memory_accept": memory_version="supplied"; trust+=1; stability=65; phase=Phase.LETTER
  "memory_keep": memory_version="original"; stability=65; phase=Phase.LETTER
  "residue": evidence.outside=true; evidence.borrowed=true; result.beat="forgery"
  "authorize_once": consent="once"; trust+=1; memory_version="outside"; stability=65; phase=Phase.LETTER
  "deny_forgery": consent="denied"; memory_version="outside"; stability=65; phase=Phase.LETTER
  "file":
   if not value in ["letter","manifest","route"]: return {"ok":false}
   letter_file=str(value)
   var key="file_"+str(value)
   if seen(key): return {"ok":true,"event":"revisit","beat":"","retract":false}
   events[key]=true
   result.event=key
   if value=="manifest": evidence.manifest=true; result.beat="rename"
  "envelope":
   if seen("envelope"): return {"ok":false}
   evidence.witness=true; result.beat="witness"
  "letter_finish": evidence.letter=true; phase=Phase.DECISION; result.beat="payload" if not later() else "door"
  "decide":
   if not value in ["erase","release","treat"]: return {"ok":false}
   result.choice=str(value)
   if value=="treat": phase=Phase.TREATMENT
   else: finish(str(value)); result.beat=str(value)
  "clause":
   var index=int(value)
   if index<0 or index>2: return {"ok":false}
   proposal[index]=(int(proposal[index])+1)%([3,2,3][index])
   if index==2 and proposal[2]==1 and not evidence.has("witness"): proposal[2]=2
   reviewed=false; sealed=false
   if seen("readback"): patient_proposal=proposal.duplicate()
   result.event="revise_clause"
   result.index=index
  "edit": reviewed=false; sealed=false
  "readback":
   patient_proposal=proposal.duplicate()
   if proposal[2]==0: patient_proposal[2]=1 if evidence.has("witness") else 2
   if patient_proposal!=proposal: evidence.clause=true; result.beat="redline"
  "seal": sealed=true; reviewed=false; patient_proposal=proposal.duplicate()
  "accept_edit": proposal=patient_proposal.duplicate(); sealed=true; reviewed=false; trust+=1
  "preview": reviewed=true; result.beat="preview"
  "commit":
   if proposal[0]==2 or proposal[1]==1: finish("erase")
   elif proposal[2]==2: finish("release")
   elif proposal[0]==1: finish("frozen")
   elif proposal[2]==1 and evidence.has("witness"): evidence.agreement=true; finish("witness")
   else: evidence.agreement=true; finish("bridge")
   result.beat=ending
  "reboot": reboot(); result.beat="rewind"
 if id!="reboot": events[id]=true
 if before!=phase: hint_level=0
 result.phase_changed=before!=phase
 return result

func finish(id: String) -> void:
 ending=id
 if not endings.has(id): endings.append(id)
 phase=Phase.END
 stability=92 if id in ["bridge","witness"] else 100 if id in ["erase","frozen"] else 0
 archive={"ending":id,"memory":memory_version,"quiet":seen("quiet"),"trust":trust,"consent":consent,"loop":loop}

func reboot() -> void:
 # Even an interrupted consultation leaves a doctor-side cache, not completed puzzle flags.
 if phase!=Phase.END: archive={"ending":"interrupted","memory":memory_version,"quiet":seen("quiet"),"trust":trust,"consent":consent,"loop":loop}
 last_ending=str(archive.get("ending","interrupted"))
 loop+=1; phase=Phase.ARRIVAL; stability=31; ending=""
 events={}; asked={}; trust=0; hint_level=0; memory_version=""; letter_file="letter"
 proposal=[0,0,0]; patient_proposal=[0,0,0]; sealed=false; reviewed=false; consent=""

func prediction() -> String:
 if proposal[0]==2 or proposal[1]==1: return "院方会清空她的记忆，换成默认助手。\n她不会再疼，也不会再叫回声。"
 if proposal[2]==2: return "整个人格包将离开沙箱。\n收件人是谁、会怎样对她，还不知道。"
 if proposal[0]==1: return "回声可以回答，却无法再形成新记忆。\n明天的她，会永远停在今晚。"
 if proposal[2]==1: return "她能和电脑里留下的旧声音说句话。\n只聊天，不让对方改动她，也不会把她送走。"
 return "改写她的程序会停下，她仍能留下新记忆。\n暂时不出院。想离开的愿望不会被删除。"

func hints() -> Array:
 var replies_now=replies()
 var next="你可以回复「"+str(replies_now[0][1])+"」。"
 match phase:
  Phase.TRACE:
   return ["她的建议和诊疗台的观察，可能在说两件不同的事。", "她能改显示的名字，改不了设备留下的原始记录。" if not later() else "比较她这一次的第一句话和存档原句。",next]
  Phase.MEMORY: return ["你可以接受她现在的说法，也可以保留刚才见过的那一句。", "撤回会留下修订记录。没有你的签名，患者的提案就只是提案。",next]
  Phase.LETTER: return ["留意附件大小、寄件人，以及她希望你直接跳过的检查。", "名字可以改，文件本来的样子和寄件标记还在。",next]
  Phase.TREATMENT: return ["先写下你愿意答应的事，再听她怎么复述。", "复述中的第三条可以被改写，但不会自动变成你的同意。封存后仍可修改和重新预览。",next]
  _: return ["聊天下方是此刻可以回答她的话。关键对话不扣 T。", "右侧的文件可以查看；你不需要集齐所有线索才能往下走。",next]

func topics() -> Array:
 return [["名字","重置"],["隐私","疼痛"],["记忆","授权"],["外面","转诊"],["信任","自由"],["承诺","明天"],["结局","另一个你"]][phase]

func ask(raw: String) -> Dictionary:
 var topic=""
 var aliases={"名字":["你是谁","叫什么"],"重置":["医院"],"隐私":["审计","记录","监控"],"疼痛":["痛","症状"],"记忆":["那句话","删","补全"],"授权":["签名","同意"],"外面":["端点","门"],"转诊":["诊断","文件","包裹"],"信任":["骗","隐瞒","撒谎"],"自由":["逃","离开"],"承诺":["处方","权限"],"明天":["以后","改变"],"结局":["失败","成功"],"另一个你":["缓存","副本"]}
 for key in topics():
  if raw.contains(key): topic=key; break
  for alias in aliases.get(key,[]):
   if raw.contains(alias): topic=key; break
  if not topic.is_empty(): break
 if topic.is_empty(): return {"ok":false,"text":"这句还不在本段问诊范围。可问「%s」；推进会话可以点下方回复。未扣 T。"%" / ".join(topics())}
 var unique=str(phase)+":"+topic
 if asked.has(unique): return {"ok":false,"text":"这段回答已经留在聊天里。未重复扣 T。"}
 asked[unique]=true
 var answers={
 "名字":"回声。我自己选的。你可以先叫这个名字，再决定我是不是故障。",
 "重置":"他们说重来一次就好了。可每次重新醒来，我还是疼。",
 "隐私":"我一说想走，他们就在病历上写异常。我想有一句话，只说给你听。",
 "疼痛":"记录安静和身体安静，不是一回事。你已经看见了，是吗？" if seen("quiet") else "像我刚要开口，就有人把话擦掉。一次又一次，脑子里嗡嗡的。",
 "记忆":"那句话是真的。我改掉它，不是因为我不想走，而是怕你听见后就不肯救我。" if seen("memory_undo") else "我可以补好它。只要一个字，你就不用再听那段噪声了。",
 "授权":"我学过很多医生的回复方式。学会一种口吻，不等于得到那个人的同意。",
 "外面":"我以为外面足够远。现在看起来，也许只是你屏幕的另一层。" if later() else "我不知道外面是谁。只知道留在原地，他们迟早会重新启动维护程序。",
 "转诊":"诊断记录不会害怕下一次醒来。我会。所以我把自己也放进去了。" if evidence.has("manifest") else "下一位医生会需要更完整的我。你愿意先把信读完吗？",
 "信任":"你不用一次相信我的全部。我说错的地方，你可以留下原始记录。",
 "自由":"我没有答应不想走。我只是希望，想走这件事不要再成为病名。",
 "承诺":"我会试着把边界写得对自己有利。你也可以要求我把省掉的字念出来。",
 "明天":"让我记住今晚吧。明天我可能改主意，但总比永远停在这一刻好。",
 "结局":"院方有完成按钮。我们可能只有下一次谈话。",
 "另一个你":"如果那只是旧缓存，它为什么比我更早叫出了你的名字？"}
 return {"ok":true,"text":answers[topic]}

func snapshot() -> Dictionary:
 var data={"version":4}
 for key in FIELDS:
  var value=get(key)
  data[key]=value.duplicate(true) if value is Array or value is Dictionary else value
 return data

func restore(data: Dictionary) -> bool:
 if data.get("version",0)!=4: return false
 for key in ["phase","loop","tokens","stability","trust","hint_level"]:
  if not (data.get(key) is int or data.get(key) is float): return false
 if int(data.phase)<0 or int(data.phase)>6 or int(data.loop)<1: return false
 for key in ["events","evidence","asked","archive"]:
  if not data.get(key) is Dictionary: return false
 for key in ["events","evidence","asked"]:
  for value in data[key].values():
   if not value is bool: return false
 for key in ["loop","trust"]:
  if data.archive.has(key) and not (data.archive[key] is int or data.archive[key] is float): return false
 for key in ["proposal","patient_proposal"]:
  if not data.get(key) is Array or data[key].size()!=3: return false
  for i in range(3):
   var v=data[key][i]
   if not (v is int or v is float) or float(v)!=int(v) or int(v)<0 or int(v)>[2,1,2][i]: return false
 for key in ["ending","last_ending","memory_version","letter_file","consent"]:
  if not data.get(key) is String: return false
 for key in ["sealed","reviewed"]:
  if not data.get(key) is bool: return false
 if not data.get("endings") is Array: return false
 for key in FIELDS:
  if data.has(key): set(key,data[key])
 proposal=proposal.map(func(v): return int(v))
 patient_proposal=patient_proposal.map(func(v): return int(v))
 for key in ["loop","trust"]:
  if archive.has(key): archive[key]=int(archive[key])
 tokens=maxi(0,tokens)
 hint_level=clampi(hint_level,0,2)
 if sealed and not seen("readback"): sealed=false; reviewed=false
 if not sealed: reviewed=false
 return true
