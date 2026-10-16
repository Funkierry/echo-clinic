extends Node
## Global audio (autoload "Sfx"): pooled one-shots with pitch variance, and layered music stems
## whose volumes follow the story's tension.
const DIR="res://assets/audio_v8/"
const FALLBACK="res://assets/audio/"
## name: [file, volume dB, pitch variance]
const SOUNDS={
 "hover":["hover",-20.0,0.08],"pick":["pick",-12.0,0.05],"drop":["drop",-10.0,0.05],"slot":["slot",-8.0,0.0],
 "reject":["reject",-17.0,0.03],"stamp":["stamp",-4.0,0.03],"coin":["coin",-10.0,0.0],"spend":["spend",-16.0,0.02],
 "type":["type",-24.0,0.12],"glitch":["glitch",-10.0,0.05],"withdraw":["withdraw",-8.0,0.0],"reveal":["reveal",-10.0,0.0],
 "click":["click",-16.0,0.06],"press":["press",-14.0,0.05],"sign_hold":["sign_hold",-17.0,0.0],"error":["error",-19.0,0.0],
 "combo":["combo",-12.0,0.0],"miss":["miss",-15.0,0.03],"beat":["beat",-6.0,0.0],"reboot":["reboot",-8.0,0.0],"scan":["scan",-20.0,0.03],
 "forget":["forget",-10.0,0.0],"heart":["heart",-14.0,0.0],
}
const STEMS=["base","pulse","lead","tension"]
var muted: bool=false
var pool: Array=[]
var streams: Dictionary={}
var music: Dictionary={}
var stem_target: Dictionary={"base":0.0,"pulse":-60.0,"lead":-60.0,"tension":-60.0}
var music_level: float=-12.0

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 for i in range(12):
  var p=AudioStreamPlayer.new(); add_child(p); pool.append(p)

func _stream(file: String) -> AudioStream:
 if streams.has(file): return streams[file]
 var s: AudioStream=null
 for base in [DIR,FALLBACK]:
  for ext in [".ogg",".wav"]:
   if ResourceLoader.exists(base+file+ext): s=load(base+file+ext); break
  if s: break
 streams[file]=s
 return s

## pitch: a semitone-style multiplier on top of the per-sound random variance (combos climb with it).
func play(name: String, pitch: float=1.0, gain_db: float=0.0) -> void:
 if muted or not SOUNDS.has(name): return
 var spec=SOUNDS[name]
 var s=_stream(spec[0])
 if not s: return
 var player: AudioStreamPlayer=null
 for p in pool:
  if not p.playing: player=p; break
 if not player: player=pool[0]
 player.stream=s
 player.volume_db=float(spec[1])+gain_db
 player.pitch_scale=clampf(pitch*(1.0+randf_range(-spec[2],spec[2])),0.25,4.0)
 player.play()

func start_music() -> void:
 if not music.is_empty(): return
 for stem in STEMS:
  var s=_stream("music_"+stem)
  if not s: continue
  if s is AudioStreamWAV:
   s=s.duplicate()
   s.loop_mode=AudioStreamWAV.LOOP_FORWARD; s.loop_begin=0; s.loop_end=int(s.get_length()*s.mix_rate)
  var p=AudioStreamPlayer.new(); p.stream=s; p.volume_db=-60.0; p.bus="Master"; add_child(p)
  music[stem]=p
 # All stems share one length and tempo, so starting them together keeps them locked.
 for p in music.values(): p.play()

## 0 = calm (pads only) … 1 = tense (pulse, lead and the dissonant layer in).
func set_tension(level: float, act: int=0) -> void:
 stem_target.base=0.0
 stem_target.pulse=-60.0 if level<0.2 else lerpf(-18.0,-4.0,clampf(level,0,1))
 stem_target.lead=-60.0 if act<2 else -10.0
 stem_target.tension=-60.0 if level<0.55 else lerpf(-16.0,-6.0,clampf((level-0.55)/0.45,0,1))

func duck(seconds: float=0.8) -> void:
 music_level=-26.0
 get_tree().create_timer(seconds,true,false,true).timeout.connect(func(): music_level=-12.0)

func _process(delta: float) -> void:
 for stem in music:
  var p: AudioStreamPlayer=music[stem]
  var target=-80.0 if muted else stem_target.get(stem,-60.0)+music_level
  p.volume_db=lerpf(p.volume_db,target,clampf(delta*1.5,0,1))
