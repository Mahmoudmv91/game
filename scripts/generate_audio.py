"""Original synthesized game effects and a soft plucked-string garden loop."""
from pathlib import Path
import math,random,struct,wave,subprocess
root=Path(__file__).resolve().parent.parent/'assets/audio';root.mkdir(parents=True,exist_ok=True)
sr=22050;random.seed(42)
def write(name,duration,fn):
 values=[]
 for i in range(int(sr*duration)):
  t=i/sr;v=max(-.96,min(.96,fn(t,duration)))
  values.append(struct.pack('<h',int(v*30000)))
 with wave.open(str(root/(name+'.wav')),'wb') as f:f.setparams((1,2,sr,0,'NONE','not compressed'));f.writeframes(b''.join(values))
def pluck(t,f,decay=9):return math.sin(2*math.pi*f*t)*math.exp(-t*decay)+.25*math.sin(2*math.pi*2.01*f*t)*math.exp(-t*decay*1.5)
write('select',.12,lambda t,d:.35*pluck(t,760,28))
write('swap',.18,lambda t,d:.28*math.sin(2*math.pi*(330*t+140*t*t))*math.exp(-t*20))
write('invalid',.21,lambda t,d:.2*math.sin(2*math.pi*160*t)*math.exp(-t*12))
write('match',.28,lambda t,d:.35*pluck(t,660,15)+.15*pluck(t,990,17))
write('cascade',.36,lambda t,d:.23*pluck(t,880,12)+.2*pluck(max(0,t-.07),1174,17))
write('explosion',.55,lambda t,d:(random.uniform(-1,1)*.6+math.sin(2*math.pi*(65*t-22*t*t))*.4)*math.exp(-t*9))
write('lightning',.55,lambda t,d:(random.uniform(-1,1)*.22+math.sin(2*math.pi*83*t)*math.sin(2*math.pi*1800*t)*.3)*math.exp(-t*5))
write('reward',.65,lambda t,d:sum(.15*pluck(t-j*.09, f,12) for j,f in enumerate([587,740,880,1174]) if t>=j*.09))
write('chest',.9,lambda t,d:sum(.18*pluck(t-j*.1,f,6) for j,f in enumerate([392,494,587,784,988]) if t>=j*.1))
write('build',.75,lambda t,d:.2*pluck(t,440,7)+.15*pluck(t,660,6)+.15*pluck(t,880,8))
write('win',1.0,lambda t,d:sum(.15*pluck(t-j*.12,f,5) for j,f in enumerate([587,740,880,1174,1480]) if t>=j*.12))
write('lose',.65,lambda t,d:.22*pluck(t,294,7)+(.18*pluck(t-.2,220,7) if t>.2 else 0))
notes=[293.66,311.13,369.99,392,440,466.16,554.37,587.33]
melody=[0,3,4,3,2,1,0,2,3,5,4,3,2,1,2,0]
def music(t,d):
 beat=.5;v=0
 for i,n in enumerate(melody):
  dt=t-i*beat
  if dt>=0:v+=.16*pluck(dt,notes[n],3.7)+.07*pluck(dt,notes[n]*2,5)
 return v
write('garden_music',8,music)
subprocess.run(['ffmpeg','-v','error','-y','-i',str(root/'garden_music.wav'),'-c:a','libvorbis','-q:a','3',str(root/'garden_music.ogg')],check=True)
(root/'garden_music.wav').unlink()
print('Created 12 effects and original garden music')
