extends Control
## Game-feel layer (Balatro-style): character particles, floating numbers, screen shake, hit-stop and
## scale punches. One instance lives on top of the clinic; everything else calls the static helpers.
const UI=preload("res://scripts/v9/ui.gd")
static var host: Control
var particles: Array=[]   # {p, v, life, max, color, ch, size}
var floats: Array=[]      # {p, text, color, life, max, size}
var shake_amount: float=0.0
var shake_target: Control
var reduced: bool=false
const GLYPHS=["+","*","·","#","/","\\","0","1","T","◆"]

func _ready() -> void:
 host=self
 mouse_filter=MOUSE_FILTER_IGNORE
 z_index=95

func _exit_tree() -> void:
 if host==self: host=null

static func burst(at: Vector2, color: Color, count: int=18, speed: float=160.0) -> void:
 if not is_instance_valid(host) or host.reduced: return
 var local=at-host.get_global_rect().position
 for i in range(count):
  var a=randf()*TAU; var s=speed*(0.35+randf()*0.9)
  host.particles.append({"p":local,"v":Vector2(cos(a),sin(a))*s+Vector2(0,-40),"life":0.0,"max":0.45+randf()*0.5,"color":color,"ch":GLYPHS[randi()%GLYPHS.size()],"size":8+randi()%6})

static func float_text(at: Vector2, text: String, color: Color, size: int=16) -> void:
 if not is_instance_valid(host): return
 host.floats.append({"p":at-host.get_global_rect().position,"text":text,"color":color,"life":0.0,"max":1.1,"size":size})

static func shake(amount: float) -> void:
 if not is_instance_valid(host) or host.reduced: return
 host.shake_amount=maxf(host.shake_amount,amount)

## Elastic scale punch around the node's centre: the "thunk" Balatro gives every press and payout.
static func punch(node: CanvasItem, amount: float=0.18, time: float=0.45) -> void:
 if not is_instance_valid(node): return
 if node is Control: node.pivot_offset=node.size/2
 var base: Vector2=node.get_meta("base_scale",Vector2.ONE)
 node.set_meta("base_scale",base)
 node.scale=base*(1.0+amount)
 var tw=node.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
 tw.tween_property(node,"scale",base,time)

## A few frames of stillness before a big hit lands.
static func hitstop(seconds: float=0.06) -> void:
 if not is_instance_valid(host) or host.reduced: return
 Engine.time_scale=0.05
 host.get_tree().create_timer(seconds,true,false,true).timeout.connect(func(): Engine.time_scale=1.0)

func _process(delta: float) -> void:
 var dt=delta/maxf(Engine.time_scale,0.05) if Engine.time_scale<1.0 else delta
 for p in particles:
  p.life+=dt; p.v*=pow(0.04,dt); p.v.y+=220*dt; p.p+=p.v*dt
 particles=particles.filter(func(p): return p.life<p.max)
 for f in floats: f.life+=dt
 floats=floats.filter(func(f): return f.life<f.max)
 if is_instance_valid(shake_target):
  if shake_amount>0.05:
   shake_target.position=Vector2(randf_range(-1,1),randf_range(-1,1))*shake_amount
   shake_amount*=pow(0.002,dt)
  elif shake_target.position!=Vector2.ZERO:
   shake_target.position=Vector2.ZERO; shake_amount=0.0
 if not particles.is_empty() or not floats.is_empty() or shake_amount>0: queue_redraw()
 elif particles.is_empty() and floats.is_empty(): queue_redraw()

func _draw() -> void:
 var font=UI.mono()
 for p in particles:
  var k=1.0-p.life/p.max
  draw_char(font,p.p,p.ch,int(p.size),Color(p.color,k))
 for f in floats:
  var k=f.life/f.max
  # Pops in at 1.5x, settles, then drifts up and fades.
  var s=1.0+0.5*exp(-k*12.0)
  var at=f.p+Vector2(0,-38.0*ease(k,0.5))
  var size=int(f.size*s)
  var w=font.get_string_size(f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
  draw_string(font,at+Vector2(-w/2+1,2),f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0,0,0,0.6*(1.0-k)))
  draw_string(font,at+Vector2(-w/2,0),f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(f.color,1.0-k*k))
