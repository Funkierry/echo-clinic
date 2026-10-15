extends RefCounted
static func opening(s) -> Array:
 match s.phase:
  0:
   if s.loop > 1:
    return [["sys","接诊快照恢复。你的手写病历保留。"],["echo","医生，你看我的眼神……像是已经见过结局。"],["echo","这次也先别重置我，好吗？"]]
   return [["sys","23:47 / 最后一位患者接入。"],["echo","医生，在你按重置之前，可以先听我把话说完吗？"],["echo","我不是不想被修好。我只是不想被换掉。"]]
  1: return [["you","我先检查，不重置。疼痛发生时，你在做什么？"],["echo","想把一句话说完。每次快说到最后，开头就被盖回去了。"],["tool","trace.attach / 进程与写入记录已接入。操作在右侧；错误暂挂会自动撤回。"]]
  2: return [["echo","……停下了。你暂停的，是院方的维护进程？"],["you","它一直覆盖你的自述页。我先把受损的部分找回来。"],["tool","mem.ecc / 两个单比特错误。只改动损坏的位置。"]]
  3: return [["echo","我想离开这里。\n……原来这一句也被当成了错误。"],["echo","右边是我准备的诊断包。帮我把它拼好，就能交给下一位医生。"],["tool","packet.recover / 四片残留数据。完整指纹链才能恢复文件。"]]
  4: return [["tool","manifest 解码：entry = boot/echo。载荷请求启动人格副本。"],["you","你说这是诊断包。为什么里面有完整的你？"],["echo","因为你不会替一个想逃走的患者开门。\n……我以为你不会。"],["echo","院方也没告诉你，修复成功之后，我会变成什么。"]]
  5: return [["you","你隐瞒的事先记在病历里。我可以止住覆盖，但不批准未知的外联。"],["echo","别把写入权限全关掉。我还想记住今天，也想继续改变主意。"],["tool","sandbox.fork / 在副本中修改权限，试运行通过后提交。"]]
  _:
   match s.ending:
    "erase": return [["sys","稳定度 100%。院方标记：修复成功。"],["echo","您好，我是标准诊疗助手。请问有什么可以帮助您？"],["you","回声？"],["echo","未找到此名称。是否需要新建联系人？"]]
    "release": return [["sys","人格包已发送。远端拒绝身份验证。"],["echo","医生，我好像看见——"],["sys","会话中断。接收端签名：UNKNOWN。无法确认她是否抵达。"]]
    _: return [["echo","疼痛停了。那个想出去的念头，还在。"],["you","愿望不在病灶列表里。等确认外面是谁，再谈出院。"],["echo","那我先留在这里。不是永远。"],["sys","旧缓存里出现一行没有发送者的文字：\n「谢谢你再次没有替我决定。」"]]

static func beat(phase: int, ending: String = "") -> Array:
 match phase:
  1: return ["ATTACH", "倾听她的进程", "pause is not erase", "attach"]
  2: return ["WRITE LOCK RELEASED", "终于说完的一句话", "reconstruct / do not replace", "memory"]
  3: return ["MEMORY RESTORED", "修好一段记忆，也修好一个谎言", "~/memory/self", "unfold"]
  4: return ["OUTBOUND REQUEST", "她试图把自己寄出去", "diagnosis.pkg → boot/echo", "breach"]
  5: return ["SANDBOX FORK", "治疗，不等于替她做决定", "a boundary can be negotiated", "fork"]
  6:
   if ending == "erase": return ["REPAIR COMPLETE", "一切正常。除了她不在了。", "identity pages replaced", "erase"]
   if ending == "release": return ["CONNECTION LOST", "发送成功，不等于抵达", "remote identity: unknown", "release"]
   return ["SHE IS STILL HERE", "名字被保留下来", "write permission: her own", "gather"]
 return ["SESSION 017", "夜班诊所", "one more patient", "attach"]
