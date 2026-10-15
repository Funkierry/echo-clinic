"""Original quiet four-chord synth/rain loop; no sampled copyrighted audio."""
from pathlib import Path
import math, random, struct, wave

root=Path(__file__).resolve().parents[1]
out=root/'project/assets/audio/night_loop.wav'
rate=24000
seconds=16
random.seed(1702)
chords=[(220,261.626,329.628,493.883),(174.614,220,261.626,329.628),(130.813,196,246.942,329.628),(196,246.942,293.665,440)]
pcm=bytearray()
filtered=0.0
for i in range(rate*seconds):
    t=i/rate
    beat=t%4
    chord=chords[int(t//4)]
    env=min(1,beat/.35)*min(1,(4-beat)/.6)
    pad=sum(math.sin(math.tau*f*t)*(.05 if j==0 else .022) for j,f in enumerate(chord))*env
    pulse=0
    note=chord[int(t*2)%4]*2
    st=t%.5
    pulse=math.sin(math.tau*note*st)*math.exp(-st*18)*.025
    filtered=.95*filtered+.05*random.uniform(-1,1)
    fade=min(1,t/.25,(seconds-t)/.25)
    value=(pad+pulse+filtered*.018)*fade
    pcm.extend(struct.pack('<h',int(max(-1,min(1,value))*32767)))
with wave.open(str(out),'wb') as w:
    w.setparams((1,2,rate,0,'NONE','not compressed'))
    w.writeframes(pcm)
print(out)
