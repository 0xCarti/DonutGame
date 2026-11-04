"""Original tactile Golden Hour audio. No samples or external melodies.
Run with Python3; writes only assets/audio/stand. Deterministic synthesis.
"""
import math, random, json
from pathlib import Path
import generate_audio as s
R=s.RATE
rng=random.Random(87124)
s.OUT=Path(__file__).resolve().parents[1]/'assets'/'audio'/'stand'
s.OUT.mkdir(parents=True,exist_ok=True)

def texture(seconds, gain=1, smooth=.35, pulse=0):
    out=s.empty(seconds); v=0
    for i in range(len(out)):
        t=i/R; v=v*(1-smooth)+rng.uniform(-1,1)*smooth
        env=min(1,t/.015)*min(1,(seconds-t)/.04)
        out[i]=v*gain*env*(.65+.35*math.sin(t*math.tau*pulse)**2 if pulse else 1)
    return out

def metal(seconds,pitch=1):
    out=s.empty(seconds)
    for f,g,d in [(630,.6,13),(1178,.25,19),(1937,.13,26),(3407,.06,35)]:
        for i in range(len(out)):
            t=i/R; out[i]+=math.sin(math.tau*f*pitch*t)*g*math.exp(-t*d)*min(1,t/.002)
    return out

def emit(name,a,peak=.55): s.write_wav(name,[a],peak)

def effects():
    a=texture(.55,.7,.65,17)
    for t in [.02,.09,.16,.27,.38]:s.mix(a,s.noise(.07,.65,42),t)
    emit('paper',a)
    a=s.empty(.42);s.mix(a,metal(.35),0,.4);s.mix(a,texture(.27,.6,.22,29),.06);emit('scoop',a,.57)
    a=s.empty(.65);s.mix(a,texture(.55,.3,.35,13),.04)
    for i in range(6):s.mix(a,s.tone(45+rng.randrange(10),.13,'wood',.42),.05+i*.055)
    emit('pour',a,.56)
    a=s.empty(.6)
    for t in [.02,.18,.34]:s.mix(a,texture(.19,.75,.9),t);s.mix(a,metal(.08,1.8),t,.08)
    emit('sugar',a,.48)
    a=texture(1.2,.6,.08,7)
    for i in range(6):s.mix(a,s.tone(39+i%3,.2,'round',.1),i*.13)
    emit('refill',a,.52)
    a=s.empty(.7)
    for i in range(4):s.mix(a,metal(.13,.6+i*.16),i*.07,.26)
    s.mix(a,s.tone(76,.35,'bell',.25),.3);emit('repair',a)
    a=s.empty(.85)
    for i in range(4):s.mix(a,metal(.13,.48+i%2*.12),i*.06,.3)
    for t in [.28,.49]:s.mix(a,s.tone(71,.19,'round',.55),t)
    emit('jam',a,.58)
    a=s.empty(.9)
    for n,t in [(79,0),(75,.21),(79,.46)]:s.mix(a,s.tone(n,.25,'round',.5),t)
    emit('overheat',a)
    a=s.empty(.45);s.mix(a,s.tone(72,.24,'wood',.5));s.mix(a,s.tone(76,.3,'bell',.27),.11);emit('attention',a,.47)
    a=s.empty(.6);s.mix(a,metal(.5,1.3),0,.3);s.mix(a,s.tone(84,.45,'bell',.25),.025);emit('customer',a,.48)
    a=s.empty(.46);s.mix(a,s.tone(60,.25,'wood',.5));s.mix(a,s.tone(55,.28,'wood',.45),.13);emit('reject',a,.48)

def loop(seconds,motor=False):
    out=s.empty(seconds);noise=[rng.uniform(-1,1) for _ in out];v=0
    for n in noise[-500:]:v=v*.88+n*.12
    for i,n in enumerate(noise):
        t=i/R;v=v*.88+n*.12
        out[i]=v*(.36 if motor else .65)
        if motor:out[i]+=.12*math.sin(math.tau*80*t)+.035*math.sin(math.tau*160*t)+.03*math.sin(math.tau*320*t)*(1+.2*math.cos(math.tau*t/seconds))
        else:out[i]*=.8+.2*math.sin(math.tau*t/seconds)
    return out

def pluck(note,seconds,gain=1):
    out=s.empty(seconds);f=s.hz(note)
    for i in range(len(out)):
        t=i/R;e=(1-math.exp(-t*120))*math.exp(-t*3.4)*min(1,(seconds-t)/.08)
        out[i]=(math.sin(math.tau*f*t)+.27*math.sin(math.tau*f*2*t)+.08*math.sin(math.tau*f*3*t))*e*gain
    return out

def music():
    beat=.6;duration=32*4*beat;left,right=s.empty(duration),s.empty(duration)
    chords=[(48,60,64,67),(45,57,60,64),(41,57,60,65),(43,55,59,62),(48,60,64,67),(50,57,62,65),(43,55,59,65),(48,55,60,64)]
    phrases=[[76,79,76,72],[76,72,69,72],[77,76,72,69],[74,71,67,71],[79,84,79,76],[77,74,77,81],[79,74,71,74],[76,72,67,72]]
    for bar in range(32):
        chord=chords[bar%8];base=bar*4*beat;section=bar//8
        for at,bass in [(0,chord[0]),(2,chord[0]+7)]:
            a=s.tone(bass,1.25,'bass',.27);s.mix(left,a,base+at*beat,wrap=True);s.mix(right,a,base+at*beat,.9,wrap=True)
        for b in range(4):
            a=texture(.12,.045,.9);s.mix(left,a,base+b*beat,wrap=True);s.mix(right,a,base+b*beat,.8,wrap=True)
            for j,n in enumerate(chord[1:]):
                a=pluck(n,1.3,.07);at=base+(b+.42+j*.035)*beat;s.mix(left,a,at,.7,wrap=True);s.mix(right,a,at,1,wrap=True)
        if section!=2 or bar%2==0:
            for i,n in enumerate(phrases[bar%8]):
                n+=12 if section==1 and i==3 else (-12 if section==3 and i==1 else 0)
                a=pluck(n,1.5,.16 if section!=2 else .1);at=base+(i*.87+(.14 if i%2 else 0))*beat
                s.mix(left,a,at,1,wrap=True);s.mix(right,a,at,.78,wrap=True);s.mix(right,a,at+.19,.13,wrap=True)
    s.write_wav('evening_theme',[left,right],.44)

if __name__=='__main__':
    effects();emit('fryer_loop',loop(4,True),.34);s.write_wav('evening_air',[loop(8),loop(8)],.23);music()
    (s.OUT/'manifest.json').write_text(json.dumps(s.METRICS,indent=2)+'\n',encoding='utf-8')
