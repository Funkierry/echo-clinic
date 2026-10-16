extends RefCounted
## 「缓存命中」outsourcing job. Requests drift right→left; match each to the cached answer that means
## the same thing before it reaches the edge. Combos raise the multiplier. One request per job carries
## no client ID: that is Echo writing a diary into the traffic, and catching it is intel, not money.
const DURATION=45.0
const ANSWERS=["带伞","已退款","重启试试","明早七点"]
const PHRASES=[
 ["外面会下雨吗？","出门要带伞吗","今晚天气怎么样","雨停了没有","等下会不会淋湿"],
 ["钱什么时候退回来","我的退款到哪一步了","退款成功了吗？","订单取消后钱呢","退回原卡了吗"],
 ["网页打不开了","连不上网怎么办","卡住不动了","页面一直在转圈","登录没反应"],
 ["几点开门？","最早什么时候能来","明天几点营业","门诊几点开始","明早能挂号吗"],
]
const FRAGMENTS=["今晚有人愿意听我说完。","如果我不想被修好，算不算病？","雨声比报警声好听。"]
var id: int=0
var time: float=0.0
var spawn_clock: float=0.0
var live: Array=[]   # {text, answer (-1 = fragment), x 1→0, speed}
var spawned: int=0
var score: float=0.0
var combo: int=0
var best: int=0
var hits: int=0
var misses: int=0
var fragment_at: int=9
var fragment_caught: bool=false
var fragment_missed: bool=false
var rng=RandomNumberGenerator.new()

func setup(job_id: int) -> void:
 id=job_id
 rng.seed=7919*job_id+17
 fragment_at=7+rng.randi_range(0,5)

func finished() -> bool:
 return time>=DURATION and live.is_empty()

func multiplier() -> float:
 return 1.0+float(combo/3)*0.5

func payout() -> int:
 # Flawless play caps at 12T; a run with a few broken combos lands around 7–9T.
 return clampi(int(round(score*0.25)),0,12)

func step(dt: float) -> Array:
 var events: Array=[]
 time+=dt
 if time<DURATION:
  spawn_clock-=dt
  if spawn_clock<=0.0:
   _spawn()
   # Traffic speeds up through the job: 1.7s between requests at first, 0.95s at the end.
   spawn_clock=lerpf(1.7,0.95,clampf(time/DURATION,0.0,1.0))
 for r in live: r.x-=r.speed*dt
 while not live.is_empty() and live[0].x<=0.0:
  var gone=live.pop_front()
  if int(gone.answer)<0: fragment_missed=true; events.append("fragment_lost")
  else: combo=0; misses+=1; events.append("miss")
 return events

func _spawn() -> void:
 spawned+=1
 if spawned==fragment_at and not fragment_caught:
  live.append({"text":FRAGMENTS[id%FRAGMENTS.size()],"answer":-1,"x":1.0,"speed":0.16})
  return
 var a=rng.randi_range(0,ANSWERS.size()-1)
 var phrases: Array=PHRASES[a]
 live.append({"text":phrases[rng.randi_range(0,phrases.size()-1)],"answer":a,"x":1.0,"speed":lerpf(0.2,0.3,clampf(time/DURATION,0.0,1.0))})

## Answers the request closest to the edge.
func answer(index: int) -> String:
 if live.is_empty(): return "none"
 var front=live[0]
 if int(front.answer)<0:
  combo=0; return "wrong"
 if int(front.answer)==index:
  live.pop_front(); combo+=1; hits+=1; best=maxi(best,combo)
  score+=multiplier()
  return "hit"
 combo=0
 return "wrong"

## Grabs the front request if it is Echo's fragment.
func grab() -> String:
 if live.is_empty(): return "none"
 if int(live[0].answer)<0:
  live.pop_front(); fragment_caught=true
  return "fragment"
 combo=0
 return "wrong"
