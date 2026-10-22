import 'package:flame_audio/flame_audio.dart';

class Soundscape {
  bool enabled=false;
  bool _started=false;
  Future<void> setEnabled(bool value) async {
    enabled=value;
    try {
      if(value){
        if(!_started){FlameAudio.bgm.initialize();_started=true;}
        await FlameAudio.bgm.play('garden_music.ogg',volume:0.18);
        play('select');
      }else if(_started){FlameAudio.bgm.pause();}
    }catch(_){/* Browser audio needs a user gesture. */}
  }
  void play(String name,{double volume=0.55}) {
    if(!enabled)return;
    FlameAudio.play('$name.wav',volume:volume).then((_) {},onError:(Object _,StackTrace __){});
  }
  void dispose(){if(_started)FlameAudio.bgm.dispose();}
}
