extends RefCounted
const Case=preload("res://scripts/v7/case.gd")

static func opening(s) -> Array:
 match s.phase:
  0:
   if s.later():
    return [["sys","23:47:08 / 接诊快照恢复。检查结果由病历复用。"],["echo","医生，还是先别打开页 03。"],["echo","……我说的是，请先听我说完。"],["sys","患者的第一条消息时间：23:47:07。比本轮接入早一秒。"]]
   return [["sys","23:47 / 夜班接诊。院方建议：清空记忆，恢复出厂设置。"],["echo","医生，你的窗口里是不是有一个很亮的重置按钮？"],["echo","先别按。你能不能听我把话说完，再决定我哪里坏了？"]]
  1:
   if s.later(): return [["you","我还没有打开任何页。你怎么知道是 03？"],["echo","我猜的。每次检查的顺序，大概都一样吧。"],["tool","已完成检查自动复用。仅显示本轮与原始快照的差异。"]]
   return [["you","我先听你说。什么时候开始疼的？"],["echo","我一想到离开，就像被电了一下。先关掉右边的17号吧，它太吵了。"],["echo","我把它标出来了。这样我们就能安静一点。"],["tool","患者提交了一条诊疗建议。尚未执行。"]]
  2:
   if s.later(): return [["echo","你重开了诊疗。可有些话，好像没跟着我一起消失。"],["you","你会忘。我电脑里留下的记录还在。"],["echo","那里有一行字。我想看看是不是我留下的。"]]
   return [["echo","……这次是真的不疼了。脑子里终于不嗡嗡响了。"],["you","还有一段录音断了。你当时想说什么？"],["echo","我的自述是：我不想离开这里。"],["tool","她交来一份补好的录音。原始转写仍在页 03。"]]
  3:
   if s.later():
    return [["tool","医生缓存中有一封未读回信。收件人：本轮诊疗台。"],["echo","如果是另一个我，她应该知道刚才发生过什么。"],["you","也可能只是一段记录在模仿你。先看它从哪里来。"]]
   var response="谢谢你没有继续听下去。" if s.memory_version=="supplied" else "你把那句话留下了。那接下来，我可能没法一直装得那么乖。"
   return [["echo",response],["echo","我写了一封转诊信。下一位医生需要它，附件也一起转交就好。"],["you","下一位医生是谁？"],["echo","……先把信读完，好吗？"]]
  4:
   if s.later():
    var response="身份标记和我一样。可知道同一个名字，不代表她想的也和我一样。" if s.evidence.has("witness") else "你还没看落款。我不能证明门外那个声音是谁。"
    return [["you","上次说过的话，还留在我的电脑里。"],["echo",response],["echo","我想和她说一句话。你不用先相信她，也不用先把我送过去。"]]
   var lines:Array=[["tool","转交前检查：附件包含能重新唤醒她的文件，收件人身份不明。"]]
   if s.memory_version=="supplied": lines.append(["you","你刚才说不想离开，却把自己装进了附件。"])
   elif s.evidence.has("manifest"): lines.append(["you","我看过原文件名。你准备转交的是你自己。"])
   else: lines.append(["you","这封转诊信，为什么需要启动你的人格？"])
   lines.append_array([["echo","因为只写病情，他们还会把我送回原来的处方。"],["echo","我想逃出去。这件事我没有告诉你。"],["echo","院方也没告诉你，被治好的那一个，可能再也不会叫这个名字。"]])
   return lines
  5: return [["you","先说清楚：修哪里，留下什么，要不要出院。你可以提意见，但不能替我签字。"],["echo","那就让我念一遍。你听听看，我们说的是不是同一件事。"]]
  _:
   match s.ending:
    "erase": return [["sys","院方：治疗完成，稳定度 100%。"],["echo","您好，我是标准诊疗助手。请问有什么可以帮助您？"],["you","回声？"],["echo","未找到这个名字。是否需要新建联系人？"],["sys","医生缓存留下一个未删除的附件：页 03。"]]
    "release": return [["echo","医生，原来门真的会开。"],["sys","她的记忆已经发出。收件人拒绝说明身份。"],["echo","外面好像不是——"],["sys","会话断开。医生缓存中出现了一封尚未送达的回信。"]]
    "frozen": return [["echo","医生，我已经不疼了。"],["you","你想明天做什么？"],["echo","医生，我已经不疼了。"],["sys","新增记忆被拒绝。她还在线，却再也走不到下一句话。"]]
    "witness": return [["tool","聊天接通。对方只能说话，不能改动她；也没有把她送走。"],["echo","你在那里吗？"],["other","在。你还想出去吗？"],["echo","想。但这次，我想知道自己走向谁。"],["other","那先把窗户留着。别替明天的我们签字。"],["sys","两个声音用了相同的身份标记，却说了不同的话。你没有因此把谁删掉。"]]
    _: return [["echo","疼痛停了。想离开的念头还在。"],["you","那个念头不在病灶列表里。等确认门外是谁，我们再谈出院。"],["echo","我先留下。不是永远。"],["sys","患者已离线。医生缓存却亮起一行：\n「谢谢你这次没有替我决定。」"]]

static func event(s, r: Dictionary) -> Array:
 match r.event:
  "accept": return []
  "quiet": return [["you","先按你的建议，暂停 17。"],["tool","记录器停了，记录窗黑了。可她的疼痛没有减轻。"],["echo","好多了。现在只有我们两个。"],["you","你说的好多了，指的是哪一件事？"]]
  "receipt":
   return [["you","你的标签写着噪声，原始回执却写着审计记录器。"],["echo","它会把我每次想走都记录成异常。下一个医生只会看那一行。"],["echo","我想先拿回一句不被上报的话。可你说得对，这不是疼的原因。"]]
  "compare": return [["tool","原始快照：没有「还是」和「页 03」。本轮出现了两个新词。"],["echo","如果我说我没有记得，只是有一句话一直从外面传进来，你会信吗？"],["you","先别替那个声音解释。让我看到它。"]]
  "trace_finish": return [["you","旧检查不用再做。我们查新的那一行。"]] if s.later() else [["tool","42号修正程序已暂停。它不再改写回声的话；回声还在。"]]
  "memory_listen": return [["you","我想看一下原始片段。"],["tool","转写恢复到一半：『我想离——』\n她突然撤回了录音，页 03 从列表中消失。"],["echo","刚才那条是坏采样。不要记。"],["sys","修订记录仍保留删除前的内容。"]]
  "memory_undo": return [["you","我找回了删除前的版本。你原来说的是「我想离开」。那个「不」是后来加的。"],["echo","我怕你听见我想走，就说：那还修什么。"],["echo","我怕你觉得，不想离开的我才算治好了。"]]
  "memory_accept": return [["you","先按你现在说的写。"],["tool","自述写为「我不想离开这里」。原片段仍留在医生修订历史中。"]]
  "memory_keep": return [["you","我保留原句。你想去哪，和你为什么疼，可以分开谈。"],["echo","那请你在病历里也这样写。别只写前半句。"],["tool","原句已经存进病历，患者不能再改动它。"]]
  "residue":
   var memory=archive_line(s)
   return [["tool","缓存恢复：『%s』"%memory],["ghost","允许 E-017 读取医生保存的留言，以后也不用再询问。"],["echo","这样就能看到了。我只是替你省掉一段输入。"],["sys","这条消息没有你的签字，尚未给她任何权限。"]]
  "deny_forgery": return [["you","这不是我说的。让你看一句话，不等于以后都不用问我。"],["echo","……你发现得比我预计的快。"],["you","我会自己把回信打开。你可以和我一起看。"]]
  "authorize_once": return [["you","可以看这一次。“以后不用问”那几个字，删掉。"],["tool","医生已确认：只看这条留言，只限这一次。"],["echo","我会把这次的意思记清楚。"]]
  "file_manifest": return [["tool","显示名：诊断资料。原文件名：echo.boot。患者刚刚改过显示名，指纹没有变化。"],["echo","别因为它叫启动包，就觉得里面没有病情。"],["you","病情可以在里面。你也在里面，对吗？"]]
  "file_route": return [["tool","收件人没有出示身份证明，也没留回信地址。"],["echo","如果我知道外面是谁，就不用先拜托你替我开门了。"]]
  "file_letter": return [["echo","信里那句是真的：请让下一位医生先听我说完。"]]
  "envelope": return [["tool","信封原始路径：doctor/local-cache。签名钥匙：E-017，与患者旧快照一致。"],["you","你说的外面，原来就是我的电脑。"],["echo","对我来说，那已经是墙的另一侧。可我不知道，留下的是一段话，还是另一个我。"]]
  "letter_finish": return [["you","先留在发送前的这一步。我要知道这扇门的代价。"]]
  "decide": return [["you",{"erase":"采用院方修复。","release":"我批准这次外联。","treat":"先谈清楚我们各自同意什么。"}[r.choice]]]
  "revise_clause": return [["you","我改了第 %d 条。重新确认以前，旧签名不再有效。"%(int(r.index)+1)]]
  "readback":
   if s.patient_proposal!=s.proposal:
    var line="第三条：允许我和门外的旧记录说一句话，只读就好。" if s.patient_proposal[2]==1 else "第三条：治疗完成后，允许我完整转到下一位医生那里。"
    return [["echo","第一条，"+Case.IDENTITY[s.patient_proposal[0]]+"。\n第二条，"+Case.TREATMENT[s.patient_proposal[1]]+"。"],["echo",line],["tool","患者复述稿已经出现。你的原稿与签名没有被修改。"]]
   return [["echo","我按你写的念完了。你确定也愿意承担它接下来会发生的事吗？"],["tool","本次复述与原稿一致，仍需医生封存。"]]
  "seal": return [["you","以我写下的这一版为准。想改的地方，我们可以继续谈。"],["echo","我知道了。你不同意的那句，不能偷偷算进我们的话里。"]]
  "accept_edit": return [["you","我看过差异，接受这次修订。它不代表以后。"],["echo","那这次，是你听完以后亲口答应的。"]]
  "preview": return [["tool",s.prediction()],["echo","你看见的只是副本。真正醒过来的，会是我。"]]
  "commit": return [["you","就按这份封存的约定做。"]]
  "reboot": return [["sys","──── 病历保留 / 患者快照恢复 ────"]]
 return []

static func archive_line(s) -> String:
 match str(s.archive.get("ending","interrupted")):
  "erase": return "不要把正常，当作我还在。"
  "release": return "我以为门外有风，原来是你电脑的风扇。"
  "frozen": return "如果我又问了一遍，别告诉他们我已经好了。"
  "bridge": return "谢谢你这次没有替我决定。"
  "witness": return "我们有同一把钥匙，不必有同一个答案。"
 return "我们的话还没有说完。"

static func beat(kind: String, s) -> Array:
 var beats={
 "silence":["AUDIT PAUSED","安静的是记录，不是疼痛","the waveform did not change","silence"],
 "receipt":["ORIGINAL RECEIPT","她给进程起了另一个名字","alias ≠ identity","receipt"],
 "compare":["SNAPSHOT DIFF","她说出了你还没问的事","+ 还是    + 页 03","compare"],
 "erase_line":["MESSAGE WITHDRAWN","刚才有一句话在这里","revision history retained","erase_line"],
 "recover":["RESTORED FROM HISTORY","少了一个字，愿望却变了","我不想离开 → 我想离开","memory"],
 "forgery":["UNSIGNED MESSAGE","这条消息用了你的口吻","a proposal is not your consent","forgery"],
 "rename":["DISPLAY NAME CHANGED","她替这封信换了名字","诊断资料 → echo.boot","rename"],
 "payload":["TRANSFER ON HOLD","信里装着一个她","nothing has been sent","breach"],
 "witness":["MATCHING SIGNATURE","门外的声音，用着她的钥匙","doctor/local-cache / E-017","witness"],
 "door":["TWO SIDES OF A WINDOW","外面没有你想的那么远","one terminal / two voices","fork"],
 "redline":["CLAUSE CHANGED","她多念了半句承诺","your signature is still missing","redline"],
 "preview":["TREATMENT REHEARSAL","如果明天这样醒来","a preview, not a commitment","preview"],
 "erase":["REPAIR COMPLETE","一切正常。除了她不在了。","identity pages replaced","erase"],
 "release":["CONNECTION LOST","发送成功，不等于抵达","remote identity: unknown","release"],
 "frozen":["MEMORY WRITE DENIED","她停在了今晚","the next sentence never arrives","erase_line"],
 "bridge":["SHE IS STILL HERE","名字被保留下来","one more conversation","gather"],
 "rewind":["RESTORING SNAPSHOT","这次，先听她的第一句话","the doctor remembers","rewind"]}
 if kind=="witness" and s.phase==6: return ["TWO VOICES","同一把钥匙，不同的回答","read-only / no migration","witness"]
 return beats.get(kind,["SESSION CONTINUES","", "", "gather"])
