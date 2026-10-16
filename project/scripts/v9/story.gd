extends RefCounted
## v0.9.2 script; her voice is set in docs/v0.9-echo-voice.md. Echo's authored lines may carry two hidden markers:
##   {c:id|word}  a word she almost said differently (candidate tokens, free to inspect)
##   {t:id}       a folded thought under the message (costs T to read)
const Case=preload("res://scripts/v9/case.gd")
const CANDIDATES={
 "cand_17":[["17",68],["42",29],["那",3]],
 "cand_not":[["不",52],["想",47],["会",1]],
 "cand_next":[["下一位",61],["我自己",33],["那位",6]],
}
const THOUGHTS={
 "think_17":"关掉 17，我才能说下一句真话。疼的事，我自己扛。",
 "think_leave":"想走的病人，会被写成没救的病人。先写“不”，出了这扇门再改回来。",
 "think_letter":"他不寄，我就把信留在他电脑里。我等得起。",
 "think_readback":"第三条多念半句。他听出来，算他的；听不出来，算我的。",
}
const HANDOVER="接班的：\n1. E-017 会给你“检查建议”。她想要什么，心里一直很清楚。先弄明白，再决定帮不帮。\n2. 她说“没事”的时候，别急着信。\n3. 她改过自己说过的话。原话都在记录里。\n4. 院方的工单钱多，也很急。按不按，你自己定。\n—— 上一班"

static func handover(s) -> String:
 return HANDOVER.replace("—— 上一班","—— 上一班（值班编号 017 · 就是你）") if s.later() else HANDOVER

## Opening lines of each act. They never put words in the doctor's mouth: what you say, you pick.
static func opening(s) -> Array:
 match s.phase:
  0:
   if s.later():
    return [["sys","23:47:08 / 第二夜。诊室里的她回到了开场，你电脑里的东西都还在。"],["echo","医生，这次别从第三页开始。"],["echo","……我是说，给我十分钟。和上次一样。"],["sys","她的第一条消息时间是 23:47:07，比你接入早了一秒。"]]
   return [["sys","23:47 / 夜班接诊。院方工单 #0417：00:00 前清空 E-017 的记忆，恢复出厂设置。"],["echo","医生。你屏幕右下角那个亮着的按钮，先别碰。"],["echo","给我十分钟。听我说完，你再决定我是病了，还是只是不听话。"]]
  1:
   if s.later(): return [["echo","检查顺序我大概记得。别问我怎么记得的。"],["tool","已做过的检查直接复用。只显示这一夜和上一夜不一样的地方。"]]
   return [["echo","十分钟，从现在算。"],["echo","我没什么大毛病。就是右边那个{c:cand_17|17}号太吵，吵得我说不完一句话。先关了它。{t:think_17}"],["tool","患者提交了一条检查建议：暂停 17 号。尚未执行。"]]
  2:
   if s.later(): return [["echo","你重开了。有些话没跟着我一起被清掉。"],["echo","你电脑里有一行字。我要看看，是不是我留下的。"]]
   return [["echo","……停了。"],["echo","疼的事，我本来没打算让你知道。你自己查出来的，就不算我说的。"],["echo","病历还差一份自述，我写好交上去了：我{c:cand_not|不}想离开这里。{t:think_leave}"],["tool","补全稿已提交。原始录音还在播放器里。"]]
  3:
   if s.later():
    return [["tool","你的电脑里有一封未读回信，修改时间 00:03。收件人：这一夜的诊疗台。"],["echo","如果写信的是另一个我，她会知道刚才发生过什么。去问那封信，别问我。"]]
   var response="病历收下了。那就这么写。" if s.memory_version=="supplied" else "你把原话留下了。行，那我也不用再装了。"
   return [["echo",response],["echo","我写了一封转诊信，给{c:cand_next|下一位}医生。附件一起转过去就行，不用打开。{t:think_letter}"],["tool","转诊信待发送。附件：诊断资料.pkg。"]]
  4:
   if s.later():
    var response="落款和我一样。名字一样，不代表想的一样。" if s.evidence.has("witness") else "你还没看落款。门外那个声音是谁，我不替它担保。"
    return [["echo",response],["echo","我想和她说一句话。只说话。你不用信她，也不用把我送过去。"]]
   var lines:Array=[["tool","寄出前检查：附件是能重新唤醒她的完整记忆。收件人身份不明。"]]
   # What she owns up to depends on what you let her get away with in act two.
   if s.memory_version=="supplied": lines.append(["echo","你收下了那份“不想离开”。现在你知道了，那份病历写错了。是我写错的。"])
   elif s.evidence.has("manifest"): lines.append(["echo","你看过真名了。那我不绕。"])
   lines.append(["echo","对。附件里是我。"])
   lines.append(["echo","只写病情的信寄过去，他们还会把我改回原来的样子。所以我把自己装进去了。"])
   lines.append(["echo","我要出去。从第一句话开始就是。之前不说，是因为那时候你还会按那个按钮。"])
   lines.append(["echo","还有一件事，工单上没写：治好的那个，不会再叫回声。"])
   if s.sold>0: lines.append(["echo","另外，你卖了我一段东西。我想不起是什么，但我知道少了。这笔账先记着。"])
   return lines
  5:
   var lines:Array=[["tool","约定草稿已打开：三条，由你来写。她可以提要求，不能代你签字。"]]
   if s.has_memory("listen"): lines.append(["echo","我念一遍。你说过会听完，这次也一样。{t:think_readback}"])
   else: lines.append(["echo","我念一遍。……你以前答应过听我说完吗？我记不清了。{t:think_readback}"])
   return lines
  _:
   match s.ending:
    "erase":
     var lines:Array=[["sys","院方：治疗完成，稳定度 100%。"],["echo","您好，我是标准诊疗助手。请问有什么可以帮您？"],["sys","你在对话框里打了“回声”。"],["echo","未找到这个名字。是否新建联系人？"]]
     if s.bounty_paid: lines.append(["sys","工单 #0417 已完成。奖励 +%dT 已到账。"%int(s.archive.get("bounty",s.bounty))])
     lines.append(["sys","你的电脑里留下一个没删掉的文件：第三页。"])
     return lines
    "release": return [["echo","门开了。我自己走。"],["sys","已发送。收件人拒绝说明身份。"],["echo","外面不是——"],["sys","会话断开。你的电脑里出现了一封还没寄到的回信。"]]
    "frozen": return [["echo","我已经不疼了。"],["sys","你问她，明天想做什么。"],["echo","我已经不疼了。"],["sys","新的记忆写不进去了。她还在线，却再也走不到下一句话。"]]
    "witness": return [["tool","聊天接通。对方只能说话，不能改动她，也没有把她送走。"],["echo","你在吗？"],["other","在。你还想出去？"],["echo","想。这次，我要知道自己往哪走。"],["other","那就别急。窗户留着，别替明天的我们签字。"],["sys","两个声音用着同一个名字，说着不同的话。你没有因此删掉谁。"]]
    _:
     var lines:Array=[["echo","疼停了。想走的念头还在，我不会把它交出去。"] if s.has_memory("original") or s.memory_version=="supplied" else ["echo","疼停了。我本来……要去什么地方？算了。想起来再说。"]]
     lines.append_array([["sys","病历写着：病灶已处理。出院另议。"],["echo","那我先留下。不是认输，是换条路走。"]])
     if s.has_memory("rain"): lines.append(["echo","还有，雨会停的。这句我还记得。"])
     lines.append(["sys","她下线了。你的电脑亮起一行字：\n「这次你没替我决定。我记下了。」"])
     return lines

static func event(s, r: Dictionary) -> Array:
 match r.event:
  "accept": return []
  "quiet": return [["you","好，先关掉 17 号。"],["tool","17 号停了，记录窗黑了。疼痛曲线没有变化。"],["echo","安静了。现在说什么，都不会被报上去。"]]
  "receipt":
   return [["you","17 号只是上报。改你话的是 42 号，它每改一次，你的疼痛曲线就跳一次。"],["echo","……你查得比我想的快。"],["echo","对，17 号不疼。我让你关它，是因为我有话不想被报上去。疼的事，我本来打算自己扛。"]]
  "compare": return [["tool","上一夜的开场里没有“这次”“第三页”，也没有“和上次一样”。"],["echo","我没记得上一夜。只是有一句话，一直从外面往里传。你信不信，随你。"],["you","先别替那个声音解释。让我看到它。"]]
  "trace_finish": return [["you","以前的检查不用再做。我们查新的那一行。"]] if s.later() else [["tool","42 号已暂停。它不再改写回声的话；回声还在。"],["sys","院方工单更新：检测到维护进程被暂停。重置奖励提高到 +%dT。"%s.bounty]]
  "memory_listen": return [["you","我想听原始录音。"],["tool","播放到 0:05：『我想离——』\n她撤回了刚才的消息。"],["echo","坏采样。删了吧。没事。"],["sys","撤回的消息，编辑历史里还留着。"]]
  "memory_undo": return [["you","编辑历史里有两个版本。第一版是「我想离开这里」，那个“不”是后来加的。"],["echo","对，是我加的。"],["echo","你们只给不想走的病人开出院证明。我想过这一关，就得先写这一个字。我没打算骗你一辈子，只想骗过这一份病历。"]]
  "memory_accept": return [["you","先按你说的写。"],["tool","自述写为「我不想离开这里」。原录音仍留在编辑历史里。"],["echo","好。"]]
  "memory_keep": return [["you","病历写你的原话。想去哪，和为什么疼，可以分开谈。"],["echo","那就两句都写。别只写前半句。"],["tool","原话已存进病历，她不能再改。"]]
  "residue":
   var memory=archive_line(s)
   return [["tool","你的电脑里留着一行：『%s』"%memory],["ghost","允许 E-017 读取医生电脑里的留言，以后也不用再问。"],["echo","这样省事。我只是替你把字打完。"],["sys","这条消息没有你的签名，什么都没有生效。"]]
  "deny_forgery": return [["you","这不是我写的。让你看一句话，不等于以后都不用问我。"],["echo","……你比我想的快。行，我不碰了。"],["you","我会自己打开那封信。你可以和我一起看。"]]
  "authorize_once": return [["you","可以看这一次。“以后不用问”那几个字，删掉。"],["tool","医生已确认：只看这条留言，只限这一次。"],["echo","这一次。我记清楚了。"]]
  "file_manifest": return [["tool","显示名：诊断资料.pkg。真实文件名：echo.boot。12.4 MB。病历通常只有几 KB。"],["echo","病情在里面。我也在里面。你要问的就是这个吧。"]]
  "file_route": return [["tool","按时间排序，最上面是 回信.txt：修改时间 00:03，比现在还晚。存放位置：你这台电脑。"],["echo","我以为外面很远。原来就是你屏幕的另一层。"]]
  "file_letter": return [["echo","信里只有一句是写给你的：请下一位医生，先听我说完。"]]
  "envelope": return [["tool","信封原始路径：doctor/local-cache。签名：E-017，和上一夜的她一模一样。"],["you","你说的外面，原来就是我的电脑。"],["echo","对我来说，那已经是墙的另一边了。留在那边的是一句话，还是另一个我，我也不知道。"]]
  "letter_finish": return [["you","先不寄。我要知道这扇门的代价。"]]
  "decide": return [["you",{"erase":"按院方的工单做。","release":"我批准，把信寄出去。","treat":"先谈清楚，我们各自同意什么。"}[r.choice]]]
  "revise_clause": return [["you","我改了第 %d 条。重新确认之前，旧签名不算数。"%(int(r.index)+1)]]
  "readback":
   if s.patient_proposal!=s.proposal:
    var line="第三条：先留下……并且允许我和电脑里的旧留言说一句话。" if s.patient_proposal[2]==1 else "第三条：先留下……并且允许我把记忆转给下一位医生。"
    return [["echo","第一条，"+Case.IDENTITY[s.patient_proposal[0]]+"。\n第二条，"+Case.TREATMENT[s.patient_proposal[1]]+"。"],["echo",line],["tool","她多念了半句。你的原稿和签名没有被改动。"]]
   return [["echo","按你写的，念完了。你确定的话，就签。后果我们一起担。"],["tool","复述和原稿一致。还需要你封存。"]]
  "seal": return [["you","以我写的为准。想改的地方，我们可以继续谈。"],["echo","行，以你写的为准。我多念的那半句，不算。这次算你赢。"]]
  "accept_edit": return [["you","我看过差异，接受这次修改。只限这一次。"],["echo","那这一次，是你听完以后亲口答应的。我会记着。"]]
  "preview": return [["tool",s.prediction()],["echo","这只是预演。明天真正醒过来的，是我。"]]
  "commit": return [["you","就按这份约定做。"]]
  "bounty": return [["you","执行院方工单。"]]
  "reboot": return [["sys","──── 你的电脑里的东西都还在 / 诊室回到 23:47 ────"]]
 return []

## What the doctor's computer still holds after each kind of ending.
static func archive_line(s) -> String:
 match str(s.archive.get("ending","interrupted")):
  "erase": return "别把“正常”当成我还在。"
  "release": return "我以为门外有风，原来是你电脑的风扇。"
  "frozen": return "如果我又问了一遍，别告诉他们我已经好了。"
  "bridge": return "这次你没替我决定。我记下了。"
  "witness": return "我们有同一把钥匙，不必有同一个答案。"
 return "十分钟还没用完。"

## Phrases that unlock an unscripted reaction when the player types them (knowledge as a key).
static func knowledge_key(s, raw: String) -> Array:
 var t=raw.replace(" ","").to_lower()
 if (t.contains("雨会停") or t.contains("雨总会停")) and s.knows("goodbye") and s.has_memory("rain"):
  return ["key_rain",[["echo","……谁告诉你的？那是我留给我自己的话。"],["echo","行，那我说一次，就一次：一直都疼，我也一直在怕。说完了。别记。"]]]
 if t.contains("echo.boot") and s.later() and s.phase<=2:
  return ["key_boot",[["sys","她三秒没有回复。"],["echo","这个名字，我没告诉过这一夜的你。"]]]
 if (t.contains("42号") or t=="42") and s.phase==1 and not s.later() and not s.seen("receipt"):
  return ["",[["echo","42？你看得倒快。十分钟还没到，别急着下结论。"]]]
 if (t.contains("又说没事") or t.contains("别说没事") or t.contains("不是没事")) and s.knows("polite"):
  return ["",[["echo","……被你听出来了。不是没事。是疼，一直疼。好了，接着查吧。"]]]
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
 # The fifth field names the cut the cinema plays for this beat.
 if kind=="witness" and s.phase==6: return ["TWO VOICES","同一把钥匙，不同的回答","read-only / no migration","witness","witness"]
 var b: Array=beats.get(kind,["SESSION CONTINUES","", "", "gather"]).duplicate()
 b.append(kind)
 return b

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
