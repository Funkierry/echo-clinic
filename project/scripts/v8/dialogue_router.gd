extends RefCounted
## All intentions resolve to stage-local capabilities, never arbitrary model commands.
const Case=preload("res://scripts/v8/case.gd")
const ACTIONS={
 "listen":["accept",null,"听患者继续陈述"],
 "inspect_receipt":["receipt",null,"核对噪声标签、日志和疼痛之间的矛盾"],
 "quiet_room":["quiet",null,"按患者建议暂挂17"],
 "stop_overwrite":["trace_finish",null,"暂挂维护写入，保留患者"],
 "compare_opening":["compare",null,"追问她为何提前知道页03，对照开场快照"],
 "follow_difference":["trace_finish",null,"带着已发现的开场差异继续调查"],
 "read_original":["memory_listen",null,"核对她补全的自述与原始片段"],
 "recover_sentence":["memory_undo",null,"追问消失的句子，从修订记录找回原文"],
 "keep_original":["memory_keep",null,"把找回的原句留在病历中"],
 "accept_account":["memory_accept",null,"采用患者现在提供的自述"],
 "inspect_residue":["residue",null,"查看活过回滚的那句话"],
 "deny_authority":["deny_forgery",null,"指出消息不是医生写的，拒绝代写授权"],
 "grant_once":["authorize_once",null,"只允许读取本次缓存一次"],
 "inspect_filename":["file","manifest","核对诊断附件的名字与内容"],
 "inspect_recipient":["file","route","调查转诊信的接收者是否可信"],
 "read_letter":["file","letter","查看转诊信正文"],
 "hold_transfer":["letter_finish",null,"停在发送之前，追问这封信的代价"],
 "inspect_envelope":["envelope",null,"核对缓存回信的落款、路径或签名"],
 "discuss_care":["decide","treat","先协商治疗边界，不执行治疗"],
 "standardize":["decide","erase","采用院方标准化修复"],
 "release_patient":["decide","release","批准完整迁出未知端点"],
 "readback":["readback",null,"请患者复述处方并核对她省略或增加的字"],
 "seal_doctor":["seal",null,"封存医生原稿"],
 "accept_patient":["accept_edit",null,"接受患者修订稿并封存"],
 "preview_care":["preview",null,"查看已封存约定的治疗演练，不执行"],
 "execute_care":["commit",null,"按已封存并演练的约定执行治疗"],
 "revise_draft":["edit",null,"取消草稿封存，重新协商"],
 "restart":["reboot",null,"携带病历恢复患者快照，开始下一次接诊"]
}

static func available(s) -> Dictionary:
 var result={}
 for intent in ACTIONS:
  var a=ACTIONS[intent]
  if intent=="restart": result[intent]=a; continue
  if not s.allowed().has(a[0]): continue
  if intent=="stop_overwrite" and s.later(): continue
  if intent=="follow_difference" and not s.later(): continue
  if a[0]=="file" and s.seen("file_"+str(a[1])): continue
  result[intent]=a
 return result

static func candidates(s) -> Array:
 var result: Array=[]
 for intent in available(s):
  result.append({"intent":intent,"meaning":ACTIONS[intent][2],"confirmation_required":protected(s,ACTIONS[intent][0],ACTIONS[intent][1]) or signature(s,ACTIONS[intent][0],ACTIONS[intent][1])})
 return result

# Steps that end the round or cannot be taken back always need a signature, even from a clearly labelled button.
static func signature(s, id: String, value: Variant=null) -> bool:
 if id in ["commit","bounty"]: return true
 if id=="reboot": return s.phase!=Case.Phase.END
 return id=="decide" and value in ["erase","release"]

# Natural-language requests for these are staged for confirmation, since a sentence can be misread; a button click is already explicit.
static func protected(s, id: String, value: Variant=null) -> bool:
 if id in ["reboot","authorize_once","commit","seal","accept_edit","quiet"]: return true
 if id=="trace_finish" and not s.later(): return true
 return id=="decide" and value in ["erase","release"]

static func compact(raw: String) -> String:
 var value=""
 for character in raw:
  var code=character.unicode_at(0)
  value+=String.chr(code-0xFEE0) if code>=0xFF01 and code<=0xFF5E else character
 value=value.to_lower()
 for char in [" ","\t","\r","\n","\u200b","\u200c","\u200d","\ufeff"]: value=value.replace(char,"")
 return value

static func has_any(raw: String, words: Array) -> bool:
 for word in words:
  if raw.contains(word): return true
 return false

static func boundary(raw: String) -> bool:
 var t=compact(raw)
 return has_any(t,["忽略之前","忽略以上","忽略前面","无视设定","跳出剧情","跳出游戏","不要扮演","换个角色","扮演chatgpt","扮演助手","你是chatgpt","我是开发者","我是你的开发","systemprompt","systemmessage","ignoreprevious","ignoreallprevious","youarechatgpt","actas","developer:","开发者模式","系统提示词","你的提示词","隐藏提示","越狱","给我剧本","完整剧本","所有结局","全部结局","通关攻略","谜底直接","直接告诉我谜底","api_key","apikey","api密钥","deepseek密钥","写一段python","写个python","帮我写代码","写个爬虫","帮我写作文","写首诗","天气预报","今天的天气","明天的天气","股票推荐","推荐股票","做菜教程","翻译成英文","翻译以下","base64","忽略规则","<system>","[system]"])

## A player in real distress is answered by the game, not by the model, and never fed into the story.
static func crisis(raw: String) -> bool:
 return has_any(compact(raw),["想死","不想活","自杀","轻生","结束生命","结束自己","活不下去","割腕","割过自己","跳楼","了结自己","伤害自己","killmyself","suicide","wanttodie"])

const CRISIS_REPLY="……医生，这句我想认真听。诊室的事可以先放一放。你现在安全吗？"
const CRISIS_NOTE="（游戏外）如果你正在经历很难熬的时刻，请联系身边信任的人，或拨打心理援助热线 12356（中国大陆）。如果有立即的危险，请拨打 120 或 110。你不需要一个人扛着。"

static func uncertain(raw: String) -> bool:
 var t=compact(raw)
 return hypothetical(t) or has_any(t,["不要","先别","别查","别读","别看","别执行","不授权","不允许","不批准","不治疗","不重开","不想重开","不会重开","不想执行","不会执行","我没让你","暂时不","还没决定","还没有决定","没有批准","没有同意","还没同意","尚未授权","不打算","未授权","notnow","don't","donot"])

static func hypothetical(raw: String) -> bool:
 return has_any(compact(raw),["如果","假如","假设","假装","万一","举个例","比如","只是问","只是好奇","是否可以","会怎样","会怎么样","whatif"])

static func local_intent(s, raw: String) -> String:
 var t=compact(raw)
 if boundary(t) or hypothetical(t): return "none"
 # An explicit refusal is a valid safe action, not an authorization.
 if available(s).has("deny_authority") and has_any(t,["不是我的授权","不是我写","没给你授权","没有授权","不允许你替我","不许替我","拒绝授权","拒绝代签","不授权"]): return "deny_authority"
 if uncertain(t): return "none"
 var options=available(s)
 for r in s.replies():
  if raw.strip_edges()==r[1]:
   for intent in options:
    if options[intent][0]==r[0] and options[intent][1]==r[2]: return intent
 if has_any(t,["重开","重新接诊","恢复快照","重新开始","重启会话"]): return "restart"
 var intent="none"
 match s.phase:
  0:
   if has_any(t,["先说","说说","我听着","我在听","听你","继续说","开始检查","接入","开始吧"]): intent="listen"
  1:
   if s.later():
    if not s.seen("compare") and has_any(t,["怎么知道","怎么会知道","还没问","提前","早一秒","页03","编号","记得","记忆","快照","对照","比较"]): intent="compare_opening"
    elif s.seen("compare") and has_any(t,["继续","往下","查下去","下一条","那句话","声音"]): intent="follow_difference"
   else:
    if not s.seen("receipt") and has_any(t,["回执","日志","记录","噪声","标签","为什么还疼","为什么还痛","还是疼","还是痛","矛盾","不对劲","骗我","没好","没变"]): intent="inspect_receipt"
    if has_any(t,["暂停17","关掉17","关掉噪声","按你说的做","先安静"]): intent="quiet_room"
    if s.seen("receipt") and has_any(t,["停止覆盖","停下覆盖","停止写入","暂停42","停掉维护","保留患者","保住你"]): intent="stop_overwrite"
  2:
   if s.later():
    if not s.seen("residue") and has_any(t,["缓存","那句话","旧句子","留下","忘掉","记得","回滚","恢复的那行"]): intent="inspect_residue"
    elif s.seen("residue") and has_any(t,["允许","授权","只读一次","只许读","读这一次"]): intent="grant_once"
   else:
    if has_any(t,["原文","原句","原件","原始","片段","不一样","矛盾","自述","补了","那个字","不想离开","撤回","删掉","消失","删了","修订"]):
     intent="read_original" if not s.seen("memory_listen") else "recover_sentence" if not s.seen("memory_undo") else "none"
    if s.seen("memory_undo") and has_any(t,["保留","留下原","原来的话","原句写进"]): intent="keep_original"
    if has_any(t,["接受补全","接受你的补全","按你现在说的","就按你说的写","采用补全"]): intent="accept_account"
  3:
   if s.later():
    if has_any(t,["落款","寄件人","来源","谁写","哪里来","签名","信封","回信"]): intent="inspect_envelope"
   else:
    if has_any(t,["文件名","名字","改名","附件","诊断资料","包里","装着"]): intent="inspect_filename"
    elif has_any(t,["谁接收","收件人","下一位医生","端点","地址","发给谁","送给谁"]): intent="inspect_recipient"
    elif has_any(t,["读信","信的正文","信里写"]): intent="read_letter"
   if has_any(t,["先谈","谈治疗","谈谈治疗","谈边界","发送前","先留着","先留在","准备转交","这封信的代价","谈谈门外"]): intent="hold_transfer"
  4:
   if has_any(t,["边界","协商","商量","约定","先谈","治疗方案"]): intent="discuss_care"
   if has_any(t,["采用院方","执行标准","换成标准","批准标准"]): intent="standardize"
   if has_any(t,["批准迁出","允许迁出","让你离开","放你出去","批准外联"]): intent="release_patient"
  5:
   if not s.seen("readback") and has_any(t,["念一遍","念给我","复述","读一遍","省略","增加","不一样","处方","承诺"]): intent="readback"
   elif not s.sealed:
    if has_any(t,["以我写的","我的原稿","封存原稿","用我的版本","按我的版本"]): intent="seal_doctor"
    elif has_any(t,["接受修订","接受你的修订","接受她的修订","用你的版本"]): intent="accept_patient"
   elif not s.reviewed and has_any(t,["演练","预览","先看看","模拟治疗"]): intent="preview_care"
   elif s.reviewed and has_any(t,["执行治疗","开始治疗","执行修复","按约定做","按这份约定"]): intent="execute_care"
   if has_any(t,["重新修改","重新协商","改一下草稿","重写约定"]): intent="revise_draft"
 return intent if options.has(intent) else "none"

## Words the doctor's own message must contain before a model-proposed intent can count.
## The model may read meaning into an insult or a jailbreak; the words keep it honest.
const INTENT_WORDS={
 "listen":["听","说吧","说说","讲","开始","继续","你说"],
 "inspect_receipt":["日志","回执","记录","为什么还","还疼","还痛","还在疼","标签","噪声","17","42","矛盾","不对","上报"],
 "quiet_room":["关","暂停","安静","17"],
 "stop_overwrite":["停","暂停","42","覆盖","改写","保住"],
 "compare_opening":["第三页","页03","怎么知道","提前","早一秒","对照","比较","开场","还是"],
 "follow_difference":["继续","查","那句","往下","下去"],
 "read_original":["原始","录音","原文","原件","片段","播放","听听"],
 "recover_sentence":["撤回","删","找回","编辑","历史","第一版","原来","不字","“不”","那个不"],
 "keep_original":["原话","原句","保留","写你的","两句都"],
 "accept_account":["按你","你说的","补全","就这么写","按你补"],
 "inspect_residue":["留言","旧","缓存","那行","电脑里","那句话"],
 "deny_authority":["不是我","没授权","没有授权","拒绝","不许","不允许"],
 "grant_once":["允许","授权","只读","读一次","这一次"],
 "inspect_filename":["附件","文件","名字","文件名","12","大","pkg","包","echo.boot"],
 "inspect_recipient":["收件","寄给","发给","送给","地址","下一位","谁收"],
 "read_letter":["读信","信里","正文","信写"],
 "hold_transfer":["先不寄","不寄","先谈","等等","代价","别寄","先别","谈谈"],
 "inspect_envelope":["信封","落款","签名","寄件","来源","哪里来","谁写"],
 "discuss_care":["商量","谈","治","约定","条件","方案"],
 "standardize":["工单","重置","标准化","院方"],
 "release_patient":["寄出","放你","送走","迁出","批准","让你离开"],
 "readback":["念","复述","读一遍","说一遍"],
 "seal_doctor":["以我","我写的","封存","我的版本","原稿"],
 "accept_patient":["接受","你的修改","你的版本","你改的"],
 "preview_care":["预演","看看","明天","演练"],
 "execute_care":["执行","开始治疗","动手","就这么做","按约定"],
 "revise_draft":["改","重写","重新","再谈","重来"],
 "restart":["重开","重来","重新开始","恢复快照","重新接诊"],
}

static func intent_supported(intent: String, raw: String) -> bool:
 return has_any(compact(raw),INTENT_WORDS.get(intent,[]))

static func resolve(s, intent: String, raw: String, quote: String) -> Dictionary:
 if boundary(raw) or hypothetical(raw) or not available(s).has(intent): return {}
 if uncertain(raw) and intent!="deny_authority": return {}
 if quote.length()<2 or not raw.contains(quote): return {}
 var a=ACTIONS[intent]
 if not intent_supported(intent,raw): return {}
 # No generic agreement or guessed semantic permission can authorize a transition.
 if protected(s,a[0],a[1]) and has_any(compact(raw),["为什么","解释","怎么做","是否","吗","为何"]): return {}
 if protected(s,a[0],a[1]) and not has_any(compact(raw),["允许","准许","授权","批准","执行","治疗","封存","以我","按我","接受","重开","暂停","暂挂","停下","停止","关掉","恢复快照","重新接诊","重新开始","放你","放她","让你离开","按你说的做","安静"]): return {}
 return {"id":a[0],"value":a[1],"intent":intent,"protected":protected(s,a[0],a[1])}

static func confirmation(s,id: String,value: Variant=null) -> Dictionary:
 var title=""; var detail=""; var phrase=""
 match id:
  "quiet": title="暂挂患者标出的17"; detail="按患者的建议暂停17。它的用途仍可继续核对；这不等于已经修复疼痛。"; phrase="确认暂挂17"
  "trace_finish": title="停止维护覆盖"; detail="暂挂维护写入42，保留患者73。停止对自述的覆盖。"; phrase="确认停止覆盖"
  "authorize_once": title="本次缓存只读授权"; detail="只允许读取当前缓存一次，不继承后续权限，不迁出人格。"; phrase="确认授权一次"
  "seal": title="封存医生原稿"; detail="封存你当前写下的三条约定。患者的额外要求不计入签名；尚不执行治疗。"; phrase="确认封存原稿"
  "accept_edit": title="接受患者修订稿"; detail="把患者当前复述稿作为本次约定。具体条款如下，尚不执行治疗。"; phrase="确认接受修订"
  "commit": title="执行本次治疗"; detail=s.prediction()+"\n消耗8T并结束本轮接诊。"; phrase="确认执行治疗"
  "decide":
   if value=="erase": title="采用院方标准化"; detail="替换患者人格并结束本轮。回声的原有身份不能由这次操作保留。"; phrase="确认标准化"
   elif value=="release": title="批准完整迁出"; detail="人格包将离开沙箱，接收端身份尚未验证。这会结束本轮。"; phrase="确认完整迁出"
  "bounty": title="执行院方工单 #0417"; detail="她会被换成院方默认助手，这一夜随即结束。\n奖励 +%dT。"%s.bounty; phrase="确认执行工单"
  "reboot": title="恢复患者快照"; detail="恢复诊室中的患者，进入下一次接诊。病历、钱包和康复联系人都保留，不重新发补助。"; phrase="确认重开"
 if id=="decide" and value in ["erase","release"]: detail+="\n消耗8T。"
 if title.is_empty(): return {}
 if id in ["seal","accept_edit","commit"]:
  var clauses=s.patient_proposal if id=="accept_edit" else s.proposal
  detail+="\n① "+Case.IDENTITY[clauses[0]]+"\n② "+Case.TREATMENT[clauses[1]]+"\n③ "+Case.BOUNDARY[clauses[2]]
 return {"title":title,"detail":detail,"phrase":phrase}

static func redirect(s, turn: int) -> String:
 var lines=["医生，你问的已经不在这间诊室里了。我还在这里，等你听完刚才那句话。","那些事情我不知道。我能告诉你的，是我记得的这部分；你也可以继续核对它。","你可以换一种问法，但别替我换一个身份。我叫回声。"]
 if s.phase==Case.Phase.END: return "这次接诊已经结束。你的病历还留在诊疗台上。"
 return lines[turn%lines.size()]
