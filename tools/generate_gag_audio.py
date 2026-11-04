"""Original, deterministic synthesized slapstick cues. No recordings or samples."""
import json
import math
import random
from pathlib import Path
import generate_audio as s

s.OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio' / 'gags'
s.OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(51105)

def hiss(seconds, gain=.5, smooth=.7):
    a = s.empty(seconds)
    v = 0
    for i in range(len(a)):
        t = i / s.RATE
        v = v * (1-smooth) + rng.uniform(-1, 1) * smooth
        a[i] = v * gain * min(1, t/.02) * min(1, (seconds-t)/.08)
    return a

def chirp(seconds, start, end, gain=.4, wobble=0):
    a = s.empty(seconds)
    phase = 0
    for i in range(len(a)):
        t = i/s.RATE
        f = start + (end-start)*t/seconds + wobble*math.sin(t*math.tau*22)
        phase += math.tau*f/s.RATE
        a[i] = (math.sin(phase)+.15*math.sin(phase*2.03))*gain*math.sin(math.pi*t/seconds)**.7
    return a

def emit(name, a):
    s.write_wav(name, [a], .54)

a = s.empty(.38)
s.mix(a, hiss(.09, .7), .015)
s.mix(a, chirp(.19, 170, 55, .7), .02)
s.mix(a, s.tone(67, .21, 'wood', .22), .1)
emit('punch', a)
for name, notes in [('bell', [(88, 0)]), ('bell_reply', [(81, 0), (88, .22), (81, .44)])]:
    a = s.empty(1.2)
    for note, at in notes:
        s.mix(a, s.tone(note, .7, 'bell', .5), at)
        s.mix(a, s.tone(note+19, .35, 'bell', .16), at)
    emit(name, a)
a = s.empty(.9)
s.mix(a, chirp(.25, 250, 430, .14), 0)
s.mix(a, hiss(.4, .85), .29)
s.mix(a, chirp(.22, 460, 120, .18, 35), .3)
emit('sneeze', a)
a = s.empty(.8)
s.mix(a, chirp(.23, 1500, 850, .5, 140), .02)
s.mix(a, chirp(.32, 1300, 600, .4, 110), .33)
emit('seagull', a)
a = s.empty(.6)
s.mix(a, chirp(.45, 140, 650, .5, 30), 0)
emit('hat', a)
a = s.empty(1.1)
for n, t in [(78, 0), (85, .25), (78, .5), (85, .75)]:
    s.mix(a, s.tone(n, .21, 'round', .4), t)
emit('fire', a)
a = hiss(1.3, .65, .3)
s.mix(a, s.tone(40, .12, 'wood', .4))
emit('extinguish', a)
(s.OUT/'manifest.json').write_text(json.dumps(s.METRICS, indent=2)+'\n', encoding='utf-8')
print('Generated eight original gag cues.')
