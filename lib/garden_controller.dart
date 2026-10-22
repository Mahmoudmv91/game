import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_engine.dart';
import 'soundscape.dart';

const taskTitles=['گل‌های حیاط','نیمکت زیر درخت انار','حوض فیروزه‌ای','باغچه زعفران','فانوس‌های شبانه'];
const taskCosts=[1,1,2,2,3];
const taskChoices=[['شمعدانی','لاله','گل سرخ'],['گردویی','سنتی','فیروزه‌ای'],['لاجورد','فیروزه','مرمر'],['بنفش','طلایی','گل‌بهی'],['مسی','آبی','زرین']];
const taskStories=[
 'بوی شمعدانی همیشه من را یاد حیاط مادربزرگ می‌اندازد. حالا باغ یک نفس تازه کشید!',
 'این نیمکت برای چای عصرانه است؛ قول بده وقتی باغ آماده شد، اینجا یک استکان چای بنوشیم.',
 'صدای آب برگشت! می‌گویند هرکس کنار این حوض آرزو کند، یک روز به آرزویش می‌رسد.',
 'گل‌های زعفران مثل ستاره‌های کوچکی روی زمین می‌درخشند. چه انتخاب قشنگی کردی!',
 'ببین چطور فانوس‌ها روشن شدند... این باغ حالا یک خانه پر از قصه است. ممنون که همراه من بودی.'
];
const introLines=[
 'سلام! من ترنجم. به باغ فیروزه خوش آمدی؛ اینجا باغ قدیمی مادربزرگ من است.',
 'حوض خاموش شده و باغچه‌ها منتظر رسیدگی‌اند. با جورکردن مهره‌ها ستاره می‌گیریم و باغ را زنده می‌کنیم.',
 'ترکیب چهار مهره ترقه می‌سازد؛ پنج مهره بمب و شش مهره دینامیت! انفجارها گوی رنگین‌کمان را شارژ می‌کنند.',
 'دو هدیه هم داری: یک صندوقچه خوش‌آمد و رشته آذرخش. با آذرخش چند مهره هم‌رنگ را انتخاب کن تا با برق به هم وصل شوند. بزن بریم!'
];

class GardenController extends ChangeNotifier {
  GardenController({Soundscape? sound}):sound=sound??Soundscape();
  final Soundscape sound;
  SharedPreferences? _prefs;
  GardenGame game=GardenGame(1);
  int level=1,stars=0,coins=200,lives=5,hammers=3,shuffles=2,lightning=2,chests=1,wins=0;
  final styles=<int>[];
  bool ready=false,introSeen=false,chainMode=false;
  int outcomeSerial=0;
  GameStatus? outcome;
  DateTime? nextLife;
  Future<void> Function(String,Set<int>)? frameSink;
  bool _rewarded=false;
  Future<void> initialize() async {
    _prefs=await SharedPreferences.getInstance();
    try {
      final data=jsonDecode(_prefs!.getString('dream_garden')??'{}') as Map<String,dynamic>;
      int get(String key,int fallback)=>(data[key] as num?)?.toInt()??fallback;
      level=get('level',1).clamp(1,20);stars=max(0,get('stars',0));coins=max(0,get('coins',200));
      lives=get('lives',5).clamp(0,5);hammers=max(0,get('hammers',3));shuffles=max(0,get('shuffles',2));
      lightning=max(0,get('lightning',2));chests=max(0,get('chests',1));wins=max(0,get('wins',0));
      styles.addAll((data['styles'] as List? ??[]).cast<int>().take(5).map((v)=>v.clamp(0,2)));
      introSeen=data['introSeen']==true;
      nextLife=DateTime.tryParse(data['nextLife'] as String? ??'');
    }catch(_){/* A previous prototype save can be migrated by missing-key defaults. */}
    refillLives();start();ready=true;notifyListeners();
  }
  void start(){
    _rewarded=false;outcome=null;chainMode=false;game=GardenGame(level);game.onFrame=_frame;notifyListeners();
  }
  void refillLives(){
    final now=DateTime.now();
    while(nextLife!=null && !now.isBefore(nextLife!) && lives<5){lives++;nextLife=nextLife!.add(const Duration(minutes:30));}
    if(lives>=5)nextLife=null;
  }
  Future<void> _frame(String phase,Set<int> indices) async {
    if(phase=='swap')sound.play('swap');
    if(phase=='invalid')sound.play('invalid');
    if(phase=='lightning')sound.play('lightning');
    if(phase=='charged')sound.play('reward');
    if(phase=='clear')sound.play(game.powerCenters.isNotEmpty?'explosion':game.combo>0?'cascade':'match');
    notifyListeners();await frameSink?.call(phase,indices);
  }
  Future<bool> play(Future<bool> Function() action) async {
    refillLives();if(lives<=0 || game.busy || game.status!=GameStatus.playing)return false;
    final accepted=await action();if(accepted)await _finish();notifyListeners();return accepted;
  }
  Future<void> _finish()async{
    if(_rewarded || game.status==GameStatus.playing)return;
    _rewarded=true;outcome=game.status;outcomeSerial++;
    if(game.status==GameStatus.won){
      stars++;coins+=100+game.score~/100+game.moves*5;wins++;
      if(wins%3==0)chests++;
      level=min(20,level+1);sound.play('win');
    }else{lives=max(0,lives-1);nextLife??=DateTime.now().add(const Duration(minutes:30));sound.play('lose');}
    await save();
  }
  Future<bool> hammer(int index)async{
    if(hammers<=0)return false;
    final ok=await play(()=>game.hammer(index));if(ok){hammers--;await save();notifyListeners();}return ok;
  }
  Future<bool> discharge(List<int> path)async{
    if(lightning<=0)return false;
    final ok=await play(()=>game.chain(path));if(ok){lightning--;chainMode=false;await save();notifyListeners();}return ok;
  }
  Future<bool> shuffle()async{
    if(shuffles<=0 || !game.shuffle())return false;
    shuffles--;sound.play('swap');await _frame('shuffle',{});await save();return true;
  }
  void toggleChain(){if(game.busy || lightning<=0)return;chainMode=!chainMode;sound.play('select');notifyListeners();}
  Future<void> buildTask(int style)async{
    final i=styles.length;if(i>=5 || stars<taskCosts[i])return;
    stars-=taskCosts[i];styles.add(style.clamp(0,2));sound.play('build');await save();notifyListeners();
  }
  Future<Map<String,int>?> openChest()async{
    if(chests<=0)return null;
    chests--;coins+=150;hammers++;shuffles++;lightning++;lives=min(5,lives+1);
    if(lives==5)nextLife=null;
    sound.play('chest');await save();notifyListeners();
    return {'coins':150,'hammer':1,'shuffle':1,'lightning':1};
  }
  Future<bool> buyLife()async{
    if(coins<150)return false;coins-=150;lives=min(5,lives+1);await save();start();return true;
  }
  Future<void> markIntroSeen()async{introSeen=true;await save();}
  Future<void> save()async{
    await _prefs?.setString('dream_garden',jsonEncode({'level':level,'stars':stars,'coins':coins,'lives':lives,
      'hammers':hammers,'shuffles':shuffles,'lightning':lightning,'chests':chests,'wins':wins,
      'styles':styles,'introSeen':introSeen,'nextLife':nextLife?.toIso8601String()}));
  }
  @override void dispose(){sound.dispose();super.dispose();}
}
