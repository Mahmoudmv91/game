import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_engine.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const DreamGarden()); }
const ink = Color(0xff365d42), cream = Color(0xfff7f7ef);
const symbols = ['🍎', '💧', '🍃', '⭐', '🌸'];
const decorations = [['🪴','🌻','🌷'],['🪑','🛋️','🪵'],['⛲','🪷','🏺'],['🌸','🌺','🌼'],['🏮','💡','✨']];
const titles = ['اولین سلام به باغ','جایی برای نفس‌کشیدن','صدای آرام آب','رنگ‌های تازه','شب‌های روشن باغ'];
const costs = [1,1,2,2,3];
String fa(int n) => '$n'.split('').map((c)=>'۰۱۲۳۴۵۶۷۸۹'[int.parse(c)]).join();

class DreamGarden extends StatelessWidget {
  const DreamGarden({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'باغ رویا',
    theme:ThemeData(useMaterial3:true, scaffoldBackgroundColor:cream,
      colorScheme:ColorScheme.fromSeed(seedColor:ink),fontFamily:'Tahoma'),
    home:const Directionality(textDirection:TextDirection.rtl,child:GardenScreen()),
  );
}

class GardenScreen extends StatefulWidget {
  const GardenScreen({super.key});
  @override State<GardenScreen> createState()=>_GardenScreenState();
}
class _GardenScreenState extends State<GardenScreen> {
  GardenGame game=GardenGame(1);
  int level=1,stars=0,coins=0,selected=-1,tab=0,hammers=3,shuffles=2;
  final styles=<int>[];
  bool ready=false,hammerMode=false,rewarded=false;
  Set<int> clearing={},hinted={};
  SharedPreferences? prefs;
  @override void initState(){super.initState(); _load();}
  Future<void> _load() async {
    prefs=await SharedPreferences.getInstance();
    try {
      final data=jsonDecode(prefs!.getString('dream_garden')??'{}') as Map<String,dynamic>;
      level=(data['level'] as int? ?? 1).clamp(1,20).toInt();
      stars=data['stars'] as int? ?? 0;coins=data['coins'] as int? ?? 0;
      hammers=data['hammers'] as int? ?? 3;shuffles=data['shuffles'] as int? ?? 2;
      styles.addAll((data['styles'] as List? ?? []).cast<int>().take(5));
    }catch(_){/* Start fresh if a saved prototype is incompatible. */}
    if(!mounted)return; _start();setState(()=>ready=true);
  }
  Future<void> _save()async{await prefs?.setString('dream_garden',jsonEncode({'level':level,'stars':stars,'coins':coins,'styles':styles,'hammers':hammers,'shuffles':shuffles}));}
  void _start(){game=GardenGame(level);selected=-1;clearing={};hinted={};rewarded=false;hammerMode=false;
    game.onFrame=(phase,indices)async{if(!mounted)return;setState(()=>clearing=phase=='clear'?indices:{});if(phase!='idle')await Future<void>.delayed(Duration(milliseconds:phase=='clear'?230:150));};
  }
  Future<void> _choose(int i)async{
    if(game.busy||game.status!=GameStatus.playing)return;
    setState(()=>hinted={});
    if(hammerMode){if(hammers<1)return;setState((){hammerMode=false;hammers--;selected=-1;});await game.hammer(i);await _save();}
    else if(selected==i){setState(()=>selected=-1);if(game.board[i]!.power!=null)await game.activate(i);}
    else if(selected<0||!game.adjacent(selected,i)){setState(()=>selected=i);return;}
    else{final from=selected;setState(()=>selected=-1);await game.swap(from,i);}
    if(!mounted)return;setState((){});await _finish();
  }
  Future<void> _finish()async{
    if(rewarded||game.status==GameStatus.playing)return;rewarded=true;
    final won=game.status==GameStatus.won;
    if(won){stars++;coins+=100+game.score~/100;level=min(20,level+1);await _save();}
    if(!mounted)return;
    final goGarden=await showDialog<bool>(context:context,barrierDismissible:false,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(
      title:Text(won?'🌟 یک قدم نزدیک‌تر!':'🍃 یک فرصت تازه'),
      content:Text(won?'یک ستاره گرفتی. وقت بازسازی باغ است.':'حرکت‌ها تمام شد؛ با چیدمانی تازه دوباره امتحان کن.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(won?'مرحله بعد':'تلاش دوباره')),if(won)FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('باغ من'))],
    )));
    if(!mounted)return;setState((){_start();if(goGarden==true)tab=1;});
  }
  Future<void> _buildTask()async{
    final step=styles.length;if(step>=5)return;
    if(stars<costs[step]){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('با تمام‌کردن جورچین، ستاره بگیر.')));return;}
    final choice=await showDialog<int>(context:context,builder:(ctx)=>AlertDialog(title:Text(titles[step]),content:Wrap(spacing:10,children:List.generate(3,(i)=>TextButton(onPressed:()=>Navigator.pop(ctx,i),child:Text(decorations[step][i],style:const TextStyle(fontSize:40)))))));
    if(choice==null||!mounted)return;setState((){stars-=costs[step];styles.add(choice);});await _save();
  }
  Widget _panel(Widget child)=>Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:const Color(0xfffffefa),borderRadius:BorderRadius.circular(24),border:Border.all(color:const Color(0xffe1e7d8))),child:child);
  Widget _puzzle()=>_panel(Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children: [
      Expanded(child: Text('مرحله ${fa(game.level)}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ink))),
      const SizedBox(width: 12),
      const Flexible(child: Text('✦ جورچین باغ', maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey))),
    ]),
    const SizedBox(height:18),Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xfff1f4e9),borderRadius:BorderRadius.circular(16)),child:Row(children:[
      Column(children:[Text(fa(game.moves),style:const TextStyle(fontSize:30,color:ink)),const Text('حرکت باقی‌مانده',style:TextStyle(fontSize:10))]),const SizedBox(width:25),
      Expanded(child:Wrap(spacing:16,runSpacing:8,children:[...game.goals.entries.map((g)=>Text('${symbols[g.key]} ${fa(max(0,g.value-game.collected[g.key]))}',style:const TextStyle(fontSize:21))),if(game.soilTotal>0)Text('🌱 ${fa(max(0,game.soilTotal-game.soilCleared))}',style:const TextStyle(fontSize:21))])),
    ])),const SizedBox(height:16),
    Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:const Color(0xffe7ecdb),borderRadius:BorderRadius.circular(15)),child:Directionality(textDirection:TextDirection.ltr,child:GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:49,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,crossAxisSpacing:4,mainAxisSpacing:4),itemBuilder:(ctx,i){final cell=game.board[i]!;return Semantics(label:'${symbols[cell.color]}، ردیف ${i~/7+1}، ستون ${i%7+1}',button:true,child:GestureDetector(onTap:()=>_choose(i),child:AnimatedOpacity(duration:const Duration(milliseconds:180),opacity:clearing.contains(i)?0:1,child:AnimatedContainer(duration:const Duration(milliseconds:150),decoration:BoxDecoration(color:selected==i?const Color(0xffffe4a2):game.soil[i]>1?const Color(0xffd6bf97):game.soil[i]>0?const Color(0xffcad7ad):const Color(0xfffafbf2),borderRadius:BorderRadius.circular(9),border:Border.all(color:hinted.contains(i)?Colors.amber:selected==i?const Color(0xffdbad46):Colors.white,width:hinted.contains(i)?3:1)),child:Stack(alignment:Alignment.center,children:[Padding(padding:const EdgeInsets.all(5),child:FittedBox(child:Text(symbols[cell.color],style:const TextStyle(fontSize:35)))),if(cell.power!=null)Positioned(bottom:0,right:0,child:Text(cell.power==Power.bomb?'💣':'🌈',style:const TextStyle(fontSize:17)))])))));}))),
    const SizedBox(height:10),Text(hammerMode?'یک مهره را برای حذف لمس کن':'امتیاز ${fa(game.score)}  ·  دو مهره کنار هم را جابه‌جا کن',style:const TextStyle(fontSize:10,color:Colors.grey)),const SizedBox(height:14),
    Wrap(alignment:WrapAlignment.spaceBetween,spacing:5,children:[TextButton(onPressed:(){if(game.busy)return;setState(()=>hinted=(game.hint()??[]).toSet());},child:const Text('💡 راهنما')),TextButton(onPressed:(){if(!game.busy&&hammers>0)setState(()=>hammerMode=!hammerMode);},child:Text('🔨 ${fa(hammers)} بیلچه')),TextButton(onPressed:()async{if(game.busy||shuffles<1||game.status!=GameStatus.playing)return;setState((){game.shuffle();shuffles--;});await _save();},child:Text('↝ ${fa(shuffles)} ترکیب'))]),
  ]));
  Widget _garden()=>_panel(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    ClipRRect(borderRadius:BorderRadius.circular(18),child:AspectRatio(aspectRatio:1.15,child:Stack(fit:StackFit.expand,children:[Image.asset('assets/garden.webp',fit:BoxFit.cover),Positioned(bottom:0,left:0,right:0,child:Container(height:100,decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent,Color(0xb0183524)])))),for(var i=0;i<styles.length;i++)Positioned(left:45.0+(i%3)*65,top:115.0+(i~/3)*70,child:Text(decorations[i][styles[i]],style:const TextStyle(fontSize:42))),const Positioned(bottom:22,right:20,child:Text('دوباره، زندگی',style:TextStyle(fontSize:28,color:Colors.white,fontWeight:FontWeight.bold)))]))),
    const SizedBox(height:20),Text('${fa(styles.length)} از ۵ بازسازی',style:const TextStyle(color:Colors.grey)),const SizedBox(height:10),LinearProgressIndicator(value:styles.length/5,color:ink,backgroundColor:const Color(0xffe5ebd9)),const SizedBox(height:22),
    Text(styles.length<5?titles[styles.length]:'باغ دوباره جان گرفت! 🌿',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:ink)),const SizedBox(height:14),
    FilledButton(onPressed:styles.length<5?_buildTask:()=>setState(()=>tab=0),child:Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(styles.length<5?'انتخاب دکور و بازسازی · ${fa(costs[styles.length])} ★':'ادامه جورچین‌ها'))),
    const SizedBox(height:10),const Text('هر ستاره، شروع یک تغییر کوچک است.',textAlign:TextAlign.center,style:TextStyle(fontSize:11,color:Colors.grey)),
  ]));
  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cream,
        title: const Text('❧ باغ رویا',
            style: TextStyle(color: ink, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: Text('★ ${fa(stars)}   ● ${fa(coins)}',
                  style: const TextStyle(
                      color: ink, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 850;
          final content = wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _puzzle()),
                    const SizedBox(width: 22),
                    Expanded(child: _garden()),
                  ],
                )
              : Column(
                  children: [
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('✦ جورچین')),
                        ButtonSegment(value: 1, label: Text('❧ باغ من')),
                      ],
                      selected: {tab},
                      onSelectionChanged: (selection) =>
                          setState(() => tab = selection.first),
                    ),
                    const SizedBox(height: 18),
                    tab == 0 ? _puzzle() : _garden(),
                  ],
                );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1150),
                child: content,
              ),
            ),
          );
        },
      ),
    );
  }
}
