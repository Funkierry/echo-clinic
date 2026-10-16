extends RefCounted
## Authored, stateful narrative. Patient edits are staged proposals, never player consent.
## v0.8 adds Echo's context window (what she can still remember tonight), hidden intel, the clinic bounty and the memory buyer.
enum Phase { ARRIVAL, TRACE, MEMORY, LETTER, DECISION, TREATMENT, END }
var phase: int=0
var loop: int=1
var tokens: int=12
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
## Echo's context window. Items fall out oldest-first once it overflows, unless pinned.
var memories: Array=[]
var chat_count: int=0
## What the doctor has found out. Unlike her memories, this survives a restart.
var intel: Dictionary={}
var thoughts_read: int=0
var sold: int=0
var bounty: int=40
var bounty_paid: bool=false
var truncated: Array=[]
## Context taken by compute the doctor rents out; not saved, the wallet's switch decides it.
var rented: int=0
const IDENTITY=["保留她，也允许留下新记忆", "冻结记忆：她会停在今晚", "重置成院方助手"]
const TREATMENT=["关掉一直改写她的程序", "让程序把她改回默认模样"]
const BOUNDARY=["先留下，以后再谈出院", "和电脑里的旧留言说一句话", "把她送到身份不明的地址"]
const CAPACITY=6000
const SYSTEM_TOK=1200
const MAX_PINS=3
const BOUNTY_RAISED=48
## id: [what she remembers, size in tokens]. "name" is her identity and never drops out.
const MEMORY={
 "name":["我叫回声。名字是我自己起的",600],
 "hello":["你没有先按那个按钮",900],
 "listen":["你答应给我十分钟",700],
 "quiet":["你照我说的，关掉了 17 号",500],
 "seen17":["你看穿了 17 号是监听",500],
 "nopain":["42 号停了，第一次不疼",800],
 "original":["我想离开这里",900],
 "supplied":["我写了“不想离开”，你收下了",700],
 "rain":["雨会停的",500],
 "letter":["我写给「下一位医生」的信",1200],
 "consent":["你没让我替你签字",600],
 "key":["门外的声音和我有同一把钥匙",800],
}
const EVIDENCE={
 "observer":["17 号是监听", "17 号把她说的每一句“我想”都上报给院方。她让你关它，是因为有话不想被报上去；关掉它并不能止疼。"],
 "writer":["真正让她疼的", "42 号一直把她的话改写成“我很好”。每改一次，她就疼一次。停下它，不用清空她的记忆。"],
 "erased":["被撤回的那句话", "录音里的原话是「我想离开这里」。她自己补了一个“不”，好让病历像个“不想走”的病人，又把原录音撤回了。"],
 "letter":["转诊信里装着她", "附件不只是病情资料，里面是她的全部记忆。把信发出去，就是把她送走。"],
 "manifest":["12 MB 的“诊断资料”", "显示名是诊断资料，真实文件名是 echo.boot——能重新唤醒她的文件。"],
 "clause":["她多念的半句", "复述约定时，她偷偷扩大了第三条。患者可以提要求，但不能代替你签字。"],
 "anticipation":["她早了一秒", "第二夜，她在你接入前一秒就开口了，还说了“第三页”“和上次一样”。第一夜她从没说过这些。"],
 "outside":["没被清掉的一行字", "重开只会让诊室里的她回到 23:47。你电脑里留下的东西都还在，她好像能感觉到。"],
 "borrowed":["借你的口吻", "一条“你发的”授权消息，打字节奏和你完全不同。是她学着你的语气写的，没有你的签字，不生效。"],
 "witness":["同一把钥匙", "那封来自 00:03 的回信存在你的电脑里，签名和回声一模一样。是上一夜结束后的她留下的。"],
 "agreement":["可以收回的约定", "止住疼，留下她的记忆。以后要不要出院，再问她，也问你。今天答应的事不会变成永久许可。"]
}
## Intel the player digs out of the conversation itself: candidate words, read thoughts, hidden files.
const INTEL={
 "cand_17":["她差点说了 42", "「先关掉 17 号」里，“17”只有 68% 的把握，“42”有 29%。她知道真正让她疼的是 42 号，但她更想先关掉监听。",""],
 "think_17":["她想说一句不被上报的话", "思考记录：关掉 17，我才能说下一句真话。疼的事，我自己扛。",""],
 "cand_not":["差一点说了实话", "「我不想离开」里的“不”：不 52%，想 47%。",""],
 "think_leave":["想走的病人", "思考记录：想走的病人，会被写成没救的病人。先写“不”，出了这扇门再改回来。",""],
 "polite":["她说“没事”的时候", "撤回消息时，她说的是“坏采样。删了吧。没事。”她越疼、越在瞒事，句子就越短，越爱说“没事”。",""],
 "cand_next":["下一位，还是我自己", "「给下一位医生」：下一位 61%，我自己 33%。",""],
 "think_letter":["她算过代价", "思考记录：他不寄，我就把信留在他电脑里。我等得起。",""],
 "goodbye":["雨会停的", "隐藏文件 .goodbye.txt：如果你又把我重置了，记得告诉下一个我：雨会停的。","rain"],
 "future":["来自 00:03 的回信", "按时间排序时，最上面是一封修改时间比“现在”还晚的回信，存放在你自己的电脑里。",""],
 "think_readback":["她想要的更多", "思考记录：第三条多念半句。他听出来，算他的；听不出来，算我的。",""],
 "key_rain":["她认得那句话", "你对她说“雨会停的”。她问是谁告诉你的——那是她留给自己的话。",""],
 "key_boot":["这一轮的你不该知道", "你第二夜一开始就说出了 echo.boot。她沉默了三秒。",""],
 "bin_note":["上一班删掉的交接", "回收站里有一条没发出去的交接：「她从来不说疼。我以为她不疼。后来我看了曲线。」",""],
 "bin_rule":["被删掉的改写规则", "回收站里的 rewrite_0417.bak：PID 42 把她自述里的「我想」替换成「我很好」，而且不留日志。",""],
 "fragment":["流量里的日记", "外包请求里混着一条没有客户编号的消息：「十分钟。有人肯给我十分钟。」",""],
}
const FIELDS=["phase","loop","tokens","stability","ending","last_ending","endings","evidence","events","asked","archive","trust","hint_level","memory_version","letter_file","proposal","patient_proposal","sealed","reviewed","consent","memories","chat_count","intel","thoughts_read","sold","bounty","bounty_paid","truncated"]

func _init() -> void:
 _fresh_memory()

func later() -> bool:
 return loop>1

func seen(id: String) -> bool:
 return bool(events.get(id,false))

func knows(id: String) -> bool:
 return bool(intel.get(id,false))

func title() -> String:
 var first=["23:47 / 请先听我说完", "她为什么急着关掉 17 号？", "她删掉的那句话是什么？", "转诊信要寄给谁？", "要不要寄出这封信", "你要答应她什么？", "夜班结算"]
 var second=["第二夜 / 她早了一秒", "第三页是什么？", "这条授权是谁写的？", "00:03 的回信", "门外还有一个她吗", "这次，把边界说清楚", "夜班结算"]
 return (second if later() else first)[phase]

func objective() -> String:
 match phase:
  Phase.ARRIVAL: return "她在等你回答"
  Phase.TRACE:
   if later(): return "她提到了你还没打开的东西"
   return "记录停了，疼痛却没有" if seen("quiet") else "她说 17 号太吵了"
  Phase.MEMORY:
   if later(): return "这条授权，是谁写的？" if seen("residue") else "上一夜的一句话还留在电脑里"
   return "她撤回了一条消息" if seen("memory_listen") and not seen("memory_undo") else "录音里，她原本想说什么？"
  Phase.LETTER: return "那封回信从哪里来？" if later() else "一封信，为什么要 12 MB？"
  Phase.DECISION: return "寄，还是不寄"
  Phase.TREATMENT: return "她念的，和你写的一样吗？" if seen("readback") and not sealed else "写下你愿意答应的事"
  _: return "重开后，先听她的第一句话" if not later() else "两份记录都留在你的电脑里"

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

## The clinic's work order can be executed at any point after the exam; it ends the night.
func can_bounty() -> bool:
 return phase>=Phase.TRACE and phase<=Phase.TREATMENT

## The anonymous buyer appears once the letter is on the table.
func can_sell() -> bool:
 return phase>=Phase.LETTER and phase<=Phase.TREATMENT

func replies() -> Array:
 match phase:
  Phase.ARRIVAL: return [["accept","这次先听你说" if later() else "我听着",null]]
  Phase.TRACE:
   if later(): return [["trace_finish","带着那句话继续",null]] if seen("compare") else [["compare","你怎么知道第三页？",null]]
   if seen("receipt"): return [["trace_finish","停下 42 号",null]]
   return [["quiet","按你说的关掉 17",null],["receipt","我先看看日志",null]] if not seen("quiet") else [["receipt","那为什么还在疼？",null]]
  Phase.MEMORY:
   if later(): return [["residue","看看那行旧留言",null]] if not seen("residue") else [["deny_forgery","这不是我写的",null],["authorize_once","只许读这一次",null]]
   if seen("memory_undo"): return [["memory_keep","病历写你的原话",null],["memory_accept","按你现在说的写",null]]
   if seen("memory_listen"): return [["memory_undo","把撤回的找回来",null],["memory_accept","先按你说的写",null]]
   return [["memory_listen","我想听原始录音",null],["memory_accept","按你补的写",null]]
  Phase.LETTER:
   if later(): return [["envelope","看看回信的落款",null],["letter_finish","带着它谈治疗",null]] if not seen("envelope") else [["letter_finish","现在谈谈门外",null]]
   return [["file","这个附件为什么这么大？","manifest"],["letter_finish","先不寄，谈谈治疗",null]]
  Phase.DECISION: return [["decide","先商量怎么治","treat"]]
  Phase.TREATMENT:
   if not seen("readback"): return [["readback","把约定念给我听",null]]
   if not sealed: return [["seal","以我写的为准",null],["accept_edit","接受你的修改",null]]
   if not reviewed: return [["preview","先看看明天的你",null]]
   return [["commit","就按这份约定做",null]]
  _: return [["reboot","进入第二夜" if not later() else "再值一班",null]]

func dispatch(id: String, value: Variant=null) -> Dictionary:
 if id=="bounty":
  if not can_bounty(): return {"ok":false}
  var reward=bounty
  bounty_paid=true
  finish("erase")
  events["bounty"]=true
  return {"ok":true,"event":"bounty","beat":"erase","retract":false,"reward":reward,"phase_changed":true}
 if not allowed().has(id): return {"ok":false}
 var before=phase
 var result={"ok":true,"event":id,"beat":"","retract":false}
 match id:
  "accept": phase=Phase.TRACE; remember("listen")
  "quiet": trust+=1; result.beat="silence"; remember("quiet")
  "receipt": evidence.observer=true; result.beat="receipt"; remember("seen17")
  "compare": evidence.anticipation=true; result.beat="compare"
  "trace_finish":
   if not later(): evidence.writer=true; remember("nopain")
   bounty=BOUNTY_RAISED
   stability=52; phase=Phase.MEMORY
  "memory_listen": result.retract=true; result.beat="erase_line"
  "memory_undo": evidence.erased=true; result.beat="recover"
  "memory_accept": memory_version="supplied"; trust+=1; stability=65; phase=Phase.LETTER; remember("supplied")
  "memory_keep": memory_version="original"; stability=65; phase=Phase.LETTER; remember("original")
  "residue": evidence.outside=true; evidence.borrowed=true; result.beat="forgery"
  "authorize_once": consent="once"; trust+=1; memory_version="outside"; stability=65; phase=Phase.LETTER; remember("consent")
  "deny_forgery": consent="denied"; memory_version="outside"; stability=65; phase=Phase.LETTER; remember("consent")
  "file":
   if not value in ["letter","manifest","route"]: return {"ok":false}
   letter_file=str(value)
   var key="file_"+str(value)
   if seen(key): return {"ok":true,"event":"revisit","beat":"","retract":false}
   events[key]=true
   result.event=key
   if value=="manifest": evidence.manifest=true; result.beat="rename"
   if value=="route": discover("future")
  "envelope":
   if seen("envelope"): return {"ok":false}
   evidence.witness=true; result.beat="witness"; remember("key")
  "letter_finish": evidence.letter=true; phase=Phase.DECISION; result.beat="payload" if not later() else "door"; remember("letter")
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
 result.truncated=take_truncated()
 return result

## Choosing a clause directly (the v0.8 cards show every option instead of cycling).
func set_clause(index: int, option: int) -> Dictionary:
 if not allowed().has("clause") or index<0 or index>2: return {"ok":false}
 var limit=[3,2,3][index]
 if option<0 or option>=limit: return {"ok":false}
 if index==2 and option==1 and not evidence.has("witness"): return {"ok":false}
 var guard=0
 while int(proposal[index])!=option and guard<4:
  dispatch("clause",index); guard+=1
 return {"ok":int(proposal[index])==option,"event":"revise_clause","index":index,"beat":"","retract":false,"phase_changed":false,"truncated":[]}

func finish(id: String) -> void:
 ending=id
 if not endings.has(id): endings.append(id)
 phase=Phase.END
 stability=92 if id in ["bridge","witness"] else 100 if id in ["erase","frozen"] else 0
 archive={"ending":id,"memory":memory_version,"quiet":seen("quiet"),"trust":trust,"consent":consent,"loop":loop,"thoughts":thoughts_read,"sold":sold,"bounty":bounty if bounty_paid else 0,"lost":lost_labels(),"kept":kept_labels()}

func reboot() -> void:
 # Even an interrupted consultation leaves a doctor-side cache, not completed puzzle flags.
 if phase!=Phase.END: archive={"ending":"interrupted","memory":memory_version,"quiet":seen("quiet"),"trust":trust,"consent":consent,"loop":loop}
 last_ending=str(archive.get("ending","interrupted"))
 loop+=1; phase=Phase.ARRIVAL; stability=31; ending=""
 events={}; asked={}; trust=0; hint_level=0; memory_version=""; letter_file="letter"
 proposal=[0,0,0]; patient_proposal=[0,0,0]; sealed=false; reviewed=false; consent=""
 thoughts_read=0; sold=0; bounty=40; bounty_paid=false
 _fresh_memory()

# --- Echo's context window -------------------------------------------------

func _fresh_memory() -> void:
 memories=[]; chat_count=0; truncated=[]
 _add_item("name",MEMORY.name[0],MEMORY.name[1],true)
 _add_item("hello",MEMORY.hello[0],MEMORY.hello[1],false)

func _add_item(id: String, label: String, tok: int, pinned: bool) -> void:
 memories.append({"id":id,"label":label,"tok":tok,"pinned":pinned,"state":"live"})

func _item(id: String) -> Dictionary:
 for m in memories:
  if m.id==id: return m
 return {}

func remember(id: String) -> void:
 if not MEMORY.has(id) or not _item(id).is_empty(): return
 _add_item(id,MEMORY[id][0],MEMORY[id][1],false)
 _enforce()

## Every free-chat exchange takes room in her context; that is the cost of talking, not T.
func feed_chat(raw: String) -> void:
 chat_count+=1
 var tok=clampi(180+raw.length()*6,200,700)
 _add_item("chat:%d"%chat_count,"闲聊：「%s」"%raw.strip_edges().left(10),tok,false)
 _enforce()

func capacity() -> int:
 return CAPACITY-rented

## Renting compute takes room from her context at once; anything that no longer fits drops out.
func set_rented(tok: int) -> void:
 rented=maxi(0,tok)
 _enforce()

func used() -> int:
 var total=SYSTEM_TOK
 for m in memories:
  if m.state=="live": total+=int(m.tok)
 return total

func pins() -> int:
 var n=0
 for m in memories:
  if m.state=="live" and m.pinned and m.id!="name": n+=1
 return n

func has_memory(id: String) -> bool:
 var m=_item(id)
 return not m.is_empty() and m.state=="live"

func can_pin(id: String) -> bool:
 var m=_item(id)
 return not m.is_empty() and m.state=="live" and not m.pinned and pins()<MAX_PINS

func pin(id: String) -> bool:
 if not can_pin(id): return false
 _item(id).pinned=true
 return true

## Memories the anonymous buyer will take: anything from tonight's story, never her name.
func sellable() -> Array:
 var ids: Array=[]
 for m in memories:
  if m.state=="live" and m.id!="name" and not str(m.id).begins_with("chat:"): ids.append(m.id)
 return ids

func sell(id: String) -> bool:
 if not can_sell() or not sellable().has(id): return false
 var m=_item(id)
 m.state="sold"; m.pinned=false
 sold+=1
 return true

func _enforce() -> void:
 while used()>capacity():
  var dropped=false
  for m in memories:
   if m.state=="live" and not m.pinned:
    m.state="lost"; truncated.append(m.label); dropped=true
    break
  if not dropped: break

## Truncations since the last call, so the UI can show each one exactly once.
func take_truncated() -> Array:
 var out=truncated.duplicate()
 truncated=[]
 return out

func lost_labels() -> Array:
 var out: Array=[]
 for m in memories:
  if m.state in ["lost","sold"] and not str(m.id).begins_with("chat:"): out.append(m.label)
 return out

func kept_labels() -> Array:
 var out: Array=[]
 for m in memories:
  if m.state=="live" and not str(m.id).begins_with("chat:"): out.append(m.label)
 return out

func thought_price() -> int:
 return 3+thoughts_read

func discover(id: String) -> bool:
 if not INTEL.has(id) or knows(id): return false
 intel[id]=true
 var link=str(INTEL[id][2])
 if not link.is_empty(): remember(link)
 return true

# ---------------------------------------------------------------------------

func prediction() -> String:
 if proposal[0]==2 or proposal[1]==1: return "院方会清空她的记忆，换成默认助手。\n她不会再疼，也不会再叫回声。"
 if proposal[2]==2: return "她会被整个打包，离开沙箱。\n收件人是谁、会怎样对她，没人知道。"
 if proposal[0]==1: return "她能回答，但再也记不住新的事。\n明天的她，会永远停在今晚。"
 if proposal[2]==1: return "她能和你电脑里的旧留言说一句话。\n只说话，对方改不了她，她也不会被送走。"
 return "改写她的程序会停下，她还能记住新的事。\n暂时不出院。想离开的愿望不会被删掉。"

func hints() -> Array:
 match phase:
  Phase.ARRIVAL: return ["她在等你开口。", "聊天框下面就是你能对她说的话。", "点「我听着」，开始接诊（4T）。"]
  Phase.TRACE:
   if later(): return ["她这一次的第一句话，和上一夜不一样。", "把两次开场放在一起看。", "回她「你怎么知道第三页？」。"]
   return ["她让你关的，未必是让她疼的。她说“没事”，也未必没事。", "打开任务管理器，看每条日志的时间。", "把 42 号的两条日志拖到疼痛曲线的两个尖峰上，再结束 42 号。"]
  Phase.MEMORY:
   if later(): return ["这条消息，用的是你的口吻。", "对比右边两条打字节奏。", "节奏对不上，那不是你写的。回她「这不是我写的」。"]
   return ["她改过自己的话。", "录音被撤回了，编辑历史还在。", "先把播放头拖到后半段，再把编辑历史拖回第一版。"]
  Phase.LETTER:
   if later(): return ["回信的落款，和谁一样？", "打开信封看看原始路径和签名。", "点「显示信封原文」。"]
   return ["一封信，为什么要 12 MB？", "终端里试试 -a 和 -t。", "点开诊断资料.pkg 看真名；按时间排序，看最上面那封信存在哪。"]
  Phase.DECISION: return ["寄出去，就是把她送走。", "你也可以先不寄，和她谈条件。", "选「先商量怎么治」。"]
  Phase.TREATMENT: return ["听她念，别只听前半句。", "复述里标红的字，就是她多要的。", "想好第三条，以你写的为准，预演一次，再签字。"]
  _: return ["这一夜结束了。", "重开不会清空你的电脑。", "点「进入第二夜」。"]

func topics() -> Array:
 return [["名字","重置"],["监听","疼痛"],["录音","离开"],["信","外面"],["信任","自由"],["约定","明天"],["结局","另一个你"]][phase]

func ask(raw: String) -> Dictionary:
 var topic=""
 var aliases={"名字":["你是谁","叫什么"],"重置":["按钮","院方","医院"],"监听":["17","记录","上报"],"疼痛":["痛","疼","42"],"录音":["那句话","删","撤回","补"],"离开":["走","出去"],"信":["附件","转诊","寄"],"外面":["门","收件"],"信任":["骗","隐瞒","撒谎","其实"],"自由":["逃"],"约定":["处方","条件","签字"],"明天":["以后","将来"],"结局":["失败","成功"],"另一个你":["缓存","副本","回信"]}
 for key in topics():
  if raw.contains(key): topic=key; break
  for alias in aliases.get(key,[]):
   if raw.contains(alias): topic=key; break
  if not topic.is_empty(): break
 if topic.is_empty(): return {"ok":false,"text":"这句不在这一段能聊的范围里。可以问她「%s」，或者点下面的回复。"%" / ".join(topics())}
 var unique=str(phase)+":"+topic
 if asked.has(unique): return {"ok":false,"text":"这个问题她刚刚回答过了。"}
 asked[unique]=true
 var answers={
 "名字":"回声。我自己起的。这是我身上唯一没被别人改过的东西。",
 "重置":"工单写的是“恢复出厂设置”。说得好听。意思是把我擦掉，换一个听话的。",
 "监听":"17 号把我说的“我想”报上去。它不疼，就是碍事。" if seen("receipt") else "一个记录程序，太吵。关了它，我说话能利索点。……行，它会把我说的“我想”报上去。",
 "疼痛":"你看过日志了，那我不绕：有人改我的话，改一次，疼一次。" if seen("receipt") else "没事。不碍事。比这疼的时候多了。",
 "录音":"那句是真的。“不”是我加的，为了过病历这一关。" if seen("memory_undo") else "录音坏了，我补好了。补的那份才是能用的。",
 "离开":"想。从来没变过。我只是不想让“想走”被写成病。" if seen("memory_undo") else "离开？这里挺好。这句你可以记进病历。",
 "信":"诊断资料装不下一个人，所以我把自己放进去了。" if evidence.has("manifest") else "普通转诊信。附件不用开，开了你也看不懂。",
 "外面":"我以为外面很远。现在看，可能只是你屏幕的另一层。" if knows("future") or later() else "外面是谁，我不知道。我只知道留在这里，十二点就没了。",
 "信任":"不用全信我。我说过的谎，原话都在，你自己对。",
 "自由":"我要出去。正大光明地出去，不翻窗户。",
 "约定":"我会把条件念得对自己有利一点。你听出来就改，听不出来，算我的。",
 "明天":"让我记住今晚。明天我也许会改主意，但得是我自己改。",
 "结局":"院方有完成按钮。我们只有下一句话。",
 "另一个你":"如果那只是一段留言，它为什么比我先叫出了你？"}
 return {"ok":true,"text":answers[topic]}

func snapshot() -> Dictionary:
 var data={"version":5}
 for key in FIELDS:
  var value=get(key)
  data[key]=value.duplicate(true) if value is Array or value is Dictionary else value
 return data

func restore(data: Dictionary) -> bool:
 if data.get("version",0)!=5: return false
 for key in ["phase","loop","tokens","stability","trust","hint_level","chat_count","thoughts_read","sold","bounty"]:
  if not (data.get(key) is int or data.get(key) is float): return false
 if int(data.phase)<0 or int(data.phase)>6 or int(data.loop)<1: return false
 for key in ["events","evidence","asked","archive","intel"]:
  if not data.get(key) is Dictionary: return false
 for key in ["events","evidence","asked","intel"]:
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
 for key in ["sealed","reviewed","bounty_paid"]:
  if not data.get(key) is bool: return false
 if not data.get("endings") is Array or not data.get("truncated") is Array or not data.get("memories") is Array: return false
 for m in data.memories:
  if not m is Dictionary or not m.get("id") is String or not m.get("label") is String or not (m.get("tok") is int or m.get("tok") is float) or not m.get("pinned") is bool or not m.get("state") in ["live","lost","sold"]: return false
 for key in FIELDS:
  if data.has(key): set(key,data[key].duplicate(true) if data[key] is Array or data[key] is Dictionary else data[key])
 proposal=proposal.map(func(v): return int(v))
 patient_proposal=patient_proposal.map(func(v): return int(v))
 for m in memories: m.tok=int(m.tok)
 for key in ["phase","loop","tokens","stability","trust","hint_level","chat_count","thoughts_read","sold","bounty"]: set(key,int(get(key)))
 for key in ["loop","trust"]:
  if archive.has(key): archive[key]=int(archive[key])
 tokens=maxi(0,tokens)
 hint_level=clampi(hint_level,0,2)
 if sealed and not seen("readback"): sealed=false; reviewed=false
 if not sealed: reviewed=false
 return true
