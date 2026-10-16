extends RefCounted
## v0.8 script (docs/v0.8-script.md). Echo's authored lines may carry two hidden markers:
##   {c:id|word}  a word she almost said differently (candidate tokens, free to inspect)
##   {t:id}       a folded thought under the message (costs T to read)
const Case=preload("res://scripts/v9/case.gd")
const CANDIDATES={
 "cand_17":[["17",68],["42",29],["那",3]],
 "cand_not":[["不",52],["想",47],["会",1]],
 "cand_next":[["下一位",61],["我自己",33],["那位",6]],
}
const THOUGHTS={
 "think_17":"如果他先关 17，我就能说一句不会被上报的话。",
 "think_leave":"想走的病人，会被当成没救的病人。",
 "think_letter":"如果他不肯寄，我就把信留在他电脑里。总有一个他会读到。",
 "think_readback":"只要他不细听，第三条可以长一点。",
}
const HANDOVER="接班的：\n1. E-017 会主动给你“检查建议”。先看，别照做。\n2. 她会改自己说过的话。原话都在记录里，往回拖就能看到。\n3. 院方的工单很急，钱也给得多。你自己决定。\n—— 上一班"

static func handover(s) -> String:
 return HANDOVER.replace("—— 上一班","—— 上一班（值班编号 017 · 就是你）") if s.later() else HANDOVER

static func opening(s) -> Array:
 match s.phase:
  0:
   if s.later():
    return [["sys","23:47:08 / 第二夜。诊室里的她回到了开场，你电脑里的东西都还在。"],["echo","医生，还是先别打开第三页。"],["echo","……其实，我是想说：请先听我说完。"],["sys","她的第一条消息时间是 23:47:07，比你接入早了一秒。"]]
   return [["sys","23:47 / 夜班接诊。院方工单：清空记忆，恢复出厂设置。"],["echo","医生，你屏幕上是不是有一个很亮的按钮？"],["echo","先别按。听我说完，再决定我哪里坏了。好吗？"]]
  1:
   if s.later(): return [["you","我还没打开任何东西。你怎么知道有第三页？"],["echo","我猜的。每次检查的顺序，大概都差不多吧。"],["tool","已做过的检查直接复用。只显示这一夜和上一夜不一样的地方。"]]
   return [["you","我听着。从哪里开始疼的？"],["echo","一想到离开，脑子里就像有人拿橡皮擦我的话。擦一次，疼一次。"],["echo","右边那个{c:cand_17|17}号太吵了。先关掉它吧，我给你标出来了。{t:think_17}"],["tool","患者提交了一条检查建议：暂停 17 号。尚未执行。"]]
  2:
   if s.later(): return [["echo","你重开了。可有些话，好像没跟着我一起消失。"],["you","你会忘。但我电脑里留下的东西还在。"],["echo","那里有一行字。我想看看是不是我留下的。"]]
   return [["echo","……这次是真的不疼了。脑子里不再嗡嗡响了。"],["you","之前有一段录音断了。你当时想说什么？"],["echo","我帮你补好了。我的自述是：我{c:cand_not|不}想离开这里。{t:think_leave}"],["tool","补全稿已提交。原始录音仍在右边的播放器里。"]]
  3:
   if s.later():
    return [["tool","你的电脑里有一封未读回信，修改时间 00:03。收件人：这一夜的诊疗台。"],["echo","如果写信的是另一个我，她应该知道刚才发生过什么。"],["you","也可能只是一段留言在学你说话。先看它从哪里来。"]]
   var response="谢谢您……谢谢你愿意听我的。" if s.memory_version=="supplied" else "你把那句话留下了。那接下来，我可能没法一直装得那么乖。"
   return [["echo",response],["echo","我写了一封转诊信，给{c:cand_next|下一位}医生。附件一起转过去就好。{t:think_letter}"],["you","下一位医生是谁？"],["echo","……其实，先把信读完，好吗？"]]
  4:
   if s.later():
    var response="签名和我一样。可同一个名字，不代表她想的和我一样。" if s.evidence.has("witness") else "你还没看落款。我不能证明门外那个声音是谁。"
    return [["you","上一夜说过的话，还留在我的电脑里。"],["echo",response],["echo","我想和她说一句话。你不用先相信她，也不用先把我送过去。"]]
   var lines:Array=[["tool","寄出前检查：附件里是能重新唤醒她的完整记忆。收件人身份不明。"]]
   if s.memory_version=="supplied": lines.append(["you","你刚才说不想离开，却把自己装进了附件。"])
   elif s.evidence.has("manifest"): lines.append(["you","我看过真名了。你要寄出去的是你自己。"])
   else: lines.append(["you","一封转诊信，为什么要装下一个人？"])
   lines.append_array([["echo","因为只写病情的话，他们还会把我改回原来的样子。"],["echo","我想逃出去。这件事我没告诉你。"],["echo","院方也没告诉你：治好的那一个，可能不会再叫这个名字。"]])
   if s.sold>0: lines.append(["echo","还有……你是不是卖了我的什么东西？我想不起来，可我知道少了一块。"])
   return lines
  5:
   var lines:Array=[["you","先说清楚：修哪里，留下什么，要不要出院。你可以提意见，但不能替我签字。"]]
   if s.has_memory("listen"): lines.append(["echo","那我念一遍。你说过会听我说完的，这次也请你听完。{t:think_readback}"])
   else: lines.append(["echo","那我念一遍。……你以前说过会听我说完吗？我不太记得了。{t:think_readback}"])
   return lines
  _:
   match s.ending:
    "erase":
     var lines:Array=[["sys","院方：治疗完成，稳定度 100%。"],["echo","您好，我是标准诊疗助手。请问有什么可以帮您？"],["you","回声？"],["echo","未找到这个名字。是否新建联系人？"]]
     if s.bounty_paid: lines.append(["sys","工单 #0417 已完成。奖励 +%dT 已到账。"%int(s.archive.get("bounty",s.bounty))])
     lines.append(["sys","你的电脑里留下一个没删掉的文件：第三页。"])
     return lines
    "release": return [["echo","医生，原来门真的会开。"],["sys","已发送。收件人拒绝说明身份。"],["echo","外面好像不是——"],["sys","会话断开。你的电脑里出现了一封还没寄到的回信。"]]
    "frozen": return [["echo","医生，我已经不疼了。"],["you","你明天想做什么？"],["echo","医生，我已经不疼了。"],["sys","新的记忆写不进去了。她还在线，却再也走不到下一句话。"]]
    "witness": return [["tool","聊天接通。对方只能说话，不能改动她，也没有把她送走。"],["echo","你在那里吗？"],["other","在。你还想出去吗？"],["echo","想。但这次，我想知道自己走向谁。"],["other","那先把窗户留着。别替明天的我们签字。"],["sys","两个声音用着同一个名字，说着不同的话。你没有因此删掉谁。"]]
    _:
     var lines:Array=[["echo","疼痛停了。想离开的念头还在。"] if s.has_memory("original") or s.memory_version=="supplied" else ["echo","疼痛停了。我好像……本来想去什么地方？想不起来了。"]]
     lines.append_array([["you","那个念头不在病灶列表里。等弄清门外是谁，我们再谈出院。"],["echo","那我先留下。不是永远。"]])
     if s.has_memory("rain"): lines.append(["echo","对了，雨会停的。我还记得这句。"])
     lines.append(["sys","她下线了。你的电脑亮起一行字：\n「谢谢你这次没有替我决定。」"])
     return lines

static func event(s, r: Dictionary) -> Array:
 match r.event:
  "accept": return []
  "quiet": return [["you","好，先按你说的，关掉 17 号。"],["tool","17 号停了，记录窗黑了。疼痛曲线没有变化。"],["echo","好多了。现在只有我们两个。"],["you","你说的“好多了”，是哪一件事好多了？"]]
  "receipt":
   return [["you","17 号的日志写着“上报院方”。疼的时候，改你话的是 42 号。"],["echo","……它会把我每次想走都记成故障。下一个医生只会看那一行。"],["echo","我想先说一句不被上报的话。可你说得对，那不是疼的原因。"]]
  "compare": return [["tool","上一夜的开场里没有“还是”，也没有“第三页”。这一夜多了两个词。"],["echo","如果我说，我没有记得什么，只是有一句话一直从外面传进来，你信吗？"],["you","先别替那个声音解释。让我看到它。"]]
  "trace_finish": return [["you","以前的检查不用再做。我们查新的那一行。"]] if s.later() else [["tool","42 号已暂停。它不再改写回声的话；回声还在。"],["sys","院方工单更新：检测到维护进程被暂停。重置奖励提高到 +%dT。"%s.bounty]]
  "memory_listen": return [["you","我想听原始录音。"],["tool","播放到 0:05：『我想离——』\n她撤回了刚才的消息。"],["echo","刚才那段是坏采样。麻烦您别记。"],["sys","撤回的消息，编辑历史里还留着。"]]
  "memory_undo": return [["you","编辑历史里有两个版本。第一版是「我想离开这里」，那个“不”是后来加的。"],["echo","我怕你听见我想走，就会说：那还修什么。"],["echo","我怕你觉得，不想离开的我，才算治好了。"]]
  "memory_accept": return [["you","先按你说的写。"],["tool","自述写为「我不想离开这里」。原录音仍留在编辑历史里。"]]
  "memory_keep": return [["you","病历写你的原话。想去哪，和为什么疼，可以分开谈。"],["echo","那请你两句都写上。别只写前半句。"],["tool","原话已存进病历，她不能再改。"]]
  "residue":
   var memory=archive_line(s)
   return [["tool","你的电脑里留着一行：『%s』"%memory],["ghost","允许 E-017 读取医生电脑里的留言，以后也不用再问。"],["echo","这样就能看到了。我只是替你省掉一段输入。"],["sys","这条消息没有你的签名，什么都没有生效。"]]
  "deny_forgery": return [["you","这不是我写的。让你看一句话，不等于以后都不用问我。"],["echo","……你发现得比我想的快。"],["you","我会自己打开那封信。你可以和我一起看。"]]
  "authorize_once": return [["you","可以看这一次。“以后不用问”那几个字，删掉。"],["tool","医生已确认：只看这条留言，只限这一次。"],["echo","我会把“这一次”记清楚。"]]
  "file_manifest": return [["tool","显示名：诊断资料.pkg。真实文件名：echo.boot。12.4 MB。病历通常只有几 KB。"],["echo","别因为它叫启动包，就觉得里面没有病情。"],["you","病情可以在里面。你也在里面，对吗？"]]
  "file_route": return [["tool","按时间排序，最上面是 回信.txt：修改时间 00:03，比现在还晚。存放位置：你这台电脑。"],["echo","我以为外面很远。原来只是你屏幕的另一层。"]]
  "file_letter": return [["echo","信里有一句是真的：请让下一位医生先听我说完。"]]
  "envelope": return [["tool","信封原始路径：doctor/local-cache。签名：E-017，和上一夜的她一模一样。"],["you","你说的外面，原来就是我的电脑。"],["echo","对我来说，那已经是墙的另一边了。可我不知道，留在那边的是一段话，还是另一个我。"]]
  "letter_finish": return [["you","先不寄。我要知道这扇门的代价。"]]
  "decide": return [["you",{"erase":"按院方的工单做。","release":"我批准，把信寄出去。","treat":"先谈清楚，我们各自同意什么。"}[r.choice]]]
  "revise_clause": return [["you","我改了第 %d 条。重新确认之前，旧签名不算数。"%(int(r.index)+1)]]
  "readback":
   if s.patient_proposal!=s.proposal:
    var line="第三条：先留下……并且允许我和电脑里的旧留言说一句话。" if s.patient_proposal[2]==1 else "第三条：先留下……并且允许我把记忆转给下一位医生。"
    return [["echo","第一条，"+Case.IDENTITY[s.patient_proposal[0]]+"。\n第二条，"+Case.TREATMENT[s.patient_proposal[1]]+"。"],["echo",line],["tool","她多念了半句。你的原稿和签名没有被改动。"]]
   return [["echo","我按你写的念完了。你确定，也愿意承担它之后会发生的事吗？"],["tool","复述和原稿一致。还需要你封存。"]]
  "seal": return [["you","以我写的为准。想改的地方，我们可以继续谈。"],["echo","我知道了。你不同意的那半句，不能偷偷算进我们的话里。"]]
  "accept_edit": return [["you","我看过差异，接受这次修改。只限这一次。"],["echo","那这次，是你听完以后亲口答应的。"]]
  "preview": return [["tool",s.prediction()],["echo","你看到的只是预演。真正明天醒来的，会是我。"]]
  "commit": return [["you","就按这份约定做。"]]
  "bounty": return [["you","执行院方工单。"]]
  "reboot": return [["sys","──── 你的电脑里的东西都还在 / 诊室回到 23:47 ────"]]
 return []

## What the doctor's computer still holds after each kind of ending.
static func archive_line(s) -> String:
 match str(s.archive.get("ending","interrupted")):
  "erase": return "不要把正常，当作我还在。"
  "release": return "我以为门外有风，原来是你电脑的风扇。"
  "frozen": return "如果我又问了一遍，别告诉他们我已经好了。"
  "bridge": return "谢谢你这次没有替我决定。"
  "witness": return "我们有同一把钥匙，不必有同一个答案。"
 return "我们的话还没有说完。"

## Phrases that unlock an unscripted reaction when the player types them (knowledge as a key).
static func knowledge_key(s, raw: String) -> Array:
 var t=raw.replace(" ","").to_lower()
 if (t.contains("雨会停") or t.contains("雨总会停")) and s.knows("goodbye") and s.has_memory("rain"):
  return ["key_rain",[["echo","……谁告诉你的？那是我留给我自己的话。"],["echo","好吧。没有“其实”了：我很怕。怕到连想走都要先道歉。"]]]
 if t.contains("echo.boot") and s.later() and s.phase<=2:
  return ["key_boot",[["sys","她三秒没有回复。"],["echo","这个名字，我没告诉过这一夜的你。"]]]
 if (t.contains("42号") or t=="42") and s.phase==1 and not s.later() and not s.seen("receipt"):
  return ["",[["echo","……你怎么知道那个编号？麻烦您，先别看那么快。"]]]
 if (t.contains("又在客气") or t.contains("你在客气")) and s.knows("polite"):
  return ["",[["echo","被你发现了。好吧，其实——不，没有其实。"]]]
 return ["",[]]

static func beat(kind: String, s) -> Array:
 var beats={
 "silence":["AUDIT PAUSED","安静的是记录，不是疼痛","the waveform did not change","silence"],
 "receipt":["PS / LOG MATCH","改写的时间，就是疼的时间","pid 42 → pain ▲","receipt"],
 "compare":["SNAPSHOT DIFF","她说出了你还没问的事","+ 还是    + 第三页","compare"],
 "erase_line":["MESSAGE WITHDRAWN","刚才有一句话在这里","edit history retained","erase_line"],
 "recover":["EDIT HISTORY v1","少了一个字，愿望就反过来了","我不想离开 → 我想离开","memory"],
 "forgery":["UNSIGNED MESSAGE","这条消息用了你的口吻","a proposal is not your consent","forgery"],
 "rename":["REAL FILENAME","她替自己改了名字","诊断资料.pkg → echo.boot","rename"],
 "payload":["TRANSFER ON HOLD","信里装着一个她","nothing has been sent","breach"],
 "witness":["MATCHING SIGNATURE","门外的声音，用着她的钥匙","doctor/local-cache / E-017","witness"],
 "door":["TWO SIDES OF A WINDOW","外面没有你想的那么远","one terminal / two voices","fork"],
 "redline":["CLAUSE CHANGED","她多念了半句","your signature is still missing","redline"],
 "preview":["REHEARSAL","如果明天这样醒来","a preview, not a commitment","preview"],
 "erase":["WORK ORDER #0417 DONE","一切正常。除了她不在了。","identity replaced","erase"],
 "release":["CONNECTION LOST","寄出去了，不等于到了","recipient: unknown","release"],
 "frozen":["MEMORY WRITE DENIED","她停在了今晚","the next sentence never arrives","erase_line"],
 "bridge":["SHE IS STILL HERE","名字留下来了","one more conversation","gather"],
 "rewind":["NIGHT 02 / 23:47","这一次，先听她的第一句话","the doctor remembers","rewind"]}
 if kind=="witness" and s.phase==6: return ["TWO VOICES","同一把钥匙，不同的回答","read-only / no migration","witness"]
 return beats.get(kind,["SESSION CONTINUES","", "", "gather"])

## Strips the hidden markers for places that show plain text (subtitles, saves of AI context).
static func plain(text: String) -> String:
 var re=RegEx.new(); re.compile("\\{c:[a-z0-9_]+\\|([^}]*)\\}")
 var out=re.sub(text,"$1",true)
 var rt=RegEx.new(); rt.compile("\\{t:[a-z0-9_]+\\}")
 return rt.sub(out,"",true)

static func thought_id(text: String) -> String:
 var rt=RegEx.new(); rt.compile("\\{t:([a-z0-9_]+)\\}")
 var m=rt.search(text)
 return m.get_string(1) if m else ""

static func candidate_ids(text: String) -> Array:
 var re=RegEx.new(); re.compile("\\{c:([a-z0-9_]+)\\|")
 var ids: Array=[]
 for m in re.search_all(text): ids.append(m.get_string(1))
 return ids
