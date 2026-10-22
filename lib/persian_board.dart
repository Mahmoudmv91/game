import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'garden_controller.dart';
import 'game_engine.dart';

const gemColors=[Color(0xffd7475c),Color(0xff31b7c7),Color(0xff68a54b),Color(0xffefba42),Color(0xffac80d2)];

void paintGem(Canvas c,Offset at,double diameter,int type,{Power? power,double opacity=1}) {
  c.save();c.translate(at.dx,at.dy);c.scale(diameter/64);
  if(opacity<1)c.saveLayer(const Rect.fromLTWH(-40,-40,80,80),Paint()..color=Colors.white.withValues(alpha:opacity));
  final color=gemColors[type];final body=Paint()..shader=ui.Gradient.linear(const Offset(-22,-25),const Offset(20,25),[Color.lerp(color,Colors.white,.34)!,color,Color.lerp(color,Colors.black,.18)!]);
  c.drawOval(const Rect.fromLTWH(-19,22,38,8),Paint()..color=Colors.black.withValues(alpha:.12)..maskFilter=const MaskFilter.blur(BlurStyle.normal,3));
  final path=Path();
  switch(type){
    case 0:
      path.moveTo(-5,-21);path.cubicTo(-36,-23,-32,23,-8,27);path.cubicTo(23,37,39,-13,12,-21);path.close();
      c.drawPath(path,body);
      c.drawPath(Path()..moveTo(-5,-22)..lineTo(-10,-31)..lineTo(-1,-27)..lineTo(5,-34)..lineTo(10,-26)..lineTo(18,-29)..lineTo(12,-20)..close(),Paint()..color=const Color(0xffa72f41));
      break;
    case 1:
      path.moveTo(0,-30);path.cubicTo(-7,-13,-26,1,-25,13);path.cubicTo(-23,38,24,38,25,12);path.cubicTo(25,0,7,-17,0,-30);c.drawPath(path,body);break;
    case 2:
      path.moveTo(-24,24);path.cubicTo(-32,-7,-13,-24,28,-29);path.cubicTo(29,10,9,30,-24,24);c.drawPath(path,body);
      c.drawPath(Path()..moveTo(-25,29)..lineTo(15,-14),Paint()..color=const Color(0xff3f7e39)..style=PaintingStyle.stroke..strokeWidth=3..strokeCap=StrokeCap.round);break;
    case 3:
      for(var i=0;i<10;i++){final a=-math.pi/2+i*math.pi/5,r=i.isEven?29.0:14.0;if(i==0)path.moveTo(math.cos(a)*r,math.sin(a)*r);else path.lineTo(math.cos(a)*r,math.sin(a)*r);}path.close();c.drawPath(path,body);break;
    default:
      for(var i=0;i<5;i++){c.save();c.rotate(i*math.pi*2/5);c.drawOval(const Rect.fromLTWH(-11,-30,22,34),body);c.restore();}
      c.drawCircle(Offset.zero,10,Paint()..color=const Color(0xffffd776));
  }
  c.drawOval(const Rect.fromLTWH(-16,-17,9,17),Paint()..color=Colors.white.withValues(alpha:.5)..maskFilter=const MaskFilter.blur(BlurStyle.normal,1));
  if(power!=null){
    c.save();c.translate(15,16);c.drawCircle(Offset.zero,15,Paint()..color=const Color(0xff193d48));
    c.drawCircle(Offset.zero,14,Paint()..color=const Color(0xffffd674)..style=PaintingStyle.stroke..strokeWidth=2);
    if(power==Power.rainbow){c.drawCircle(Offset.zero,10,Paint()..shader=ui.Gradient.sweep(Offset.zero,[Colors.red,Colors.amber,Colors.green,Colors.cyan,Colors.purple,Colors.red]));c.drawCircle(const Offset(-3,-3),3,Paint()..color=Colors.white.withValues(alpha:.8));}
    else if(power==Power.bomb){c.drawCircle(const Offset(-1,2),9,Paint()..color=const Color(0xff344653));c.drawPath(Path()..moveTo(1,-6)..quadraticBezierTo(0,-13,8,-10),Paint()..color=const Color(0xffffce6c)..style=PaintingStyle.stroke..strokeWidth=2);c.drawCircle(const Offset(9,-11),3,Paint()..color=Colors.orangeAccent);}
    else {for(var i=0;i<(power==Power.dynamite?3:1);i++){c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-8+i*6,-9,5,19),const Radius.circular(2)),Paint()..color=const Color(0xffe7744b));}c.drawCircle(const Offset(2,-11),3,Paint()..color=Colors.yellow);}
    c.restore();
  }
  if(opacity<1)c.restore();c.restore();
}

class GemPainter extends CustomPainter {
  GemPainter(this.type,{this.power});final int type;final Power? power;
  @override void paint(Canvas canvas,Size size)=>paintGem(canvas,Offset(size.width/2,size.height/2),math.min(size.width,size.height),type,power:power);
  @override bool shouldRepaint(covariant GemPainter old)=>old.type!=type || old.power!=power;
}

class PersianBoard extends FlameGame {
  PersianBoard(this.controller,{required this.onSelectionChanged});
  final GardenController controller;
  final void Function(int) onSelectionChanged;
  int selected=-1;
  final selectedChain=<int>[];
  Set<int> hints={},clearing={};
  String phase='idle';double clock=0,phaseAge=0,shake=0;
  GardenGame? _lastGame;
  Future<void> Function(String,Set<int>)? _sink;
  GardenGame get model=>controller.game;
  double get tile=>(math.min(size.x,size.y)-16)/7;
  Offset point(int index)=>Offset(8+(index%7+.5)*tile,8+(index~/7+.5)*tile);
  @override Color backgroundColor()=>Colors.transparent;
  @override Future<void> onLoad()async{_sink=animatePhase;controller.frameSink=_sink;_lastGame=model;}
  @override void onRemove(){if(controller.frameSink==_sink)controller.frameSink=null;super.onRemove();}
  @override void update(double dt){
    super.update(dt);clock+=dt;phaseAge+=dt;shake=math.max(0,shake-dt*15);
    if(_lastGame!=model){_lastGame=model;selected=-1;selectedChain.clear();hints={};clearing={};phase='idle';}
    if(!controller.chainMode && selectedChain.isNotEmpty){selectedChain.clear();onSelectionChanged(0);}
  }
  Future<void> animatePhase(String next,Set<int> indices)async{
    phase=next;phaseAge=0;clearing=next=='clear'?indices:{};
    if(next=='clear'){
      for(final i in indices){add(SparkBurst(point(i),gemColors[model.board[i]!.color],strong:model.powerCenters.isNotEmpty));}
      for(final i in model.powerCenters){add(Shockwave(point(i)));}
      if(model.powerCenters.isNotEmpty)shake=5;
      if(model.combo>0)add(FloatingPraise(Offset(size.x/2,size.y*.42),model.combo>1?'شگفت‌انگیز!':'چه ترکیبی!'));
    }
    if(next=='lightning'){add(ElectricLinks(indices.map(point).toList(),duration:.75));shake=2;}
    if(next=='charged'){for(final i in indices){add(Shockwave(point(i),color:Colors.cyanAccent));}add(FloatingPraise(Offset(size.x/2,size.y*.5),'گوی رنگین‌کمان آماده شد!'));}
    final ms=switch(next){'swap'=>180,'invalid'=>180,'clear'=>350,'fall'=>360,'lightning'=>650,'charged'=>550,'shuffle'=>300,_=>0};
    if(ms>0)await Future<void>.delayed(Duration(milliseconds:ms));
  }
  int? at(Offset p){if(p.dx<8||p.dy<8||p.dx>=8+tile*7||p.dy>=8+tile*7)return null;return ((p.dy-8)/tile).floor()*7+((p.dx-8)/tile).floor();}
  void selectChain(int i){
    if(model.busy)return;
    if(selectedChain.contains(i)){if(selectedChain.length>1&&selectedChain[selectedChain.length-2]==i){selectedChain.removeLast();onSelectionChanged(selectedChain.length);}return;}
    if(selectedChain.isNotEmpty && model.board[selectedChain.first]!.color!=model.board[i]!.color)return;
    selectedChain.add(i);controller.sound.play('select',volume:.28);onSelectionChanged(selectedChain.length);
  }
  Future<void> tap(Offset p,{bool hammer=false})async{
    if(model.busy||model.status!=GameStatus.playing)return;final i=at(p);if(i==null)return;
    hints={};if(hammer){await controller.hammer(i);return;}
    if(controller.chainMode){selectChain(i);return;}
    if(selected==i){selected=-1;if(model.board[i]!.power!=null)await controller.play(()=>model.activate(i));return;}
    if(selected<0 || !model.adjacent(selected,i)){selected=i;controller.sound.play('select');return;}
    final a=selected;selected=-1;await controller.play(()=>model.swap(a,i));
  }
  int? dragOrigin;
  void dragStart(Offset p){final i=at(p);dragOrigin=i;if(i!=null&&controller.chainMode){selectedChain.clear();selectChain(i);}}
  void dragUpdate(Offset p){if(controller.chainMode){final i=at(p);if(i!=null)selectChain(i);}}
  Future<void> dragEnd(Offset p)async{
    if(controller.chainMode){if(selectedChain.length>=3)await discharge();return;}
    final a=dragOrigin,b=at(p);dragOrigin=null;
    if(a!=null&&b!=null&&model.adjacent(a,b)){selected=-1;await controller.play(()=>model.swap(a,b));}
  }
  Future<void> discharge()async{final path=List<int>.of(selectedChain);selectedChain.clear();onSelectionChanged(0);await controller.discharge(path);}
  void hint(){hints=(model.hint()??[]).toSet();}
  void celebrate(){for(var i=0;i<8;i++){add(SparkBurst(Offset(size.x*(i+1)/9,size.y*.3),gemColors[i%5],strong:true));}}
  @override void render(Canvas canvas){
    if(size.x<=0 || model.board.isEmpty)return;
    canvas.save();if(shake>0)canvas.translate(math.sin(clock*90)*shake,math.cos(clock*72)*shake*.6);
    final area=Rect.fromLTWH(0,0,math.min(size.x,size.y),math.min(size.x,size.y));
    canvas.drawRRect(RRect.fromRectAndRadius(area,const Radius.circular(20)),Paint()..color=const Color(0xff174e58));
    canvas.drawRRect(RRect.fromRectAndRadius(area.deflate(3),const Radius.circular(18)),Paint()..color=const Color(0xffe4bb68)..style=PaintingStyle.stroke..strokeWidth=1.5);
    for(var i=0;i<49;i++){
      final p=point(i);final rect=Rect.fromCenter(center:p,width:tile-4,height:tile-4);
      final soil=model.soil[i];
      canvas.drawRRect(RRect.fromRectAndRadius(rect,const Radius.circular(10)),Paint()..shader=ui.Gradient.linear(rect.topLeft,rect.bottomRight,soil>0?[const Color(0xffc1c58a),soil>1?const Color(0xffac8656):const Color(0xff7b9d66)]:[const Color(0xfff8f2db),const Color(0xffe5dec6)]));
      if(soil>0){final stroke=Paint()..color=Colors.white.withValues(alpha:.16)..strokeWidth=2;for(var k=-1;k<5;k++){canvas.save();canvas.clipRRect(RRect.fromRectAndRadius(rect,const Radius.circular(10)));canvas.drawLine(Offset(rect.left+k*12,rect.bottom),Offset(rect.left+k*12+tile,rect.top),stroke);canvas.restore();}}
      if(selected==i||selectedChain.contains(i)||hints.contains(i)){
        final col=selectedChain.contains(i)?Colors.cyanAccent:const Color(0xffffcb66);
        canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(1),const Radius.circular(9)),Paint()..color=col..style=PaintingStyle.stroke..strokeWidth=2.5+math.sin(clock*6)*.6);
      }
      var position=p;var scale=1.0;var alpha=1.0;
      if(phase=='swap'||phase=='invalid'){
        final t=(phaseAge/.18).clamp(0.0,1.0);final eased=Curves.easeInOut.transform(t);
        if(i==model.swapA)position=Offset.lerp(point(model.swapB),p,eased)!;
        if(i==model.swapB)position=Offset.lerp(point(model.swapA),p,eased)!;
      }
      if(phase=='fall'){
        final t=(phaseAge/.36).clamp(0.0,1.0);position=p+Offset(0,-model.dropDistances[i]*tile*(1-Curves.easeOutCubic.transform(t)));
      }
      if(clearing.contains(i)){final t=(phaseAge/.35).clamp(0.0,1.0);scale=1.15*(1-t);alpha=1-t;}
      if(selected==i||selectedChain.contains(i))scale*=1.04+math.sin(clock*6)*.025;
      final cell=model.board[i];if(cell!=null)paintGem(canvas,position,(tile-9)*scale,cell.color,power:cell.power,opacity:alpha);
    }
    if(selectedChain.length>1)ElectricLinks.paintLinks(canvas,selectedChain.map(point).toList(),clock,.95);
    super.render(canvas);canvas.restore();
  }
}

class SparkBurst extends Component {
  SparkBurst(this.origin,this.color,{this.strong=false});final Offset origin;final Color color;final bool strong;
  double age=0;final random=math.Random();late final seeds=List.generate(strong?25:10,(_)=>(random.nextDouble()*math.pi*2,40+random.nextDouble()*110,2+random.nextDouble()*3));
  @override void update(double dt){age+=dt;if(age>1)removeFromParent();}
  @override void render(Canvas canvas){for(final s in seeds){final p=origin+Offset(math.cos(s.$1)*s.$2*age,math.sin(s.$1)*s.$2*age+60*age*age);canvas.drawCircle(p,s.$3*(1-age).clamp(0.0,1.0),Paint()..color=Color.lerp(color,Colors.white,.5)!.withValues(alpha:(1-age).clamp(0.0,1.0)));}}
}
class Shockwave extends Component {
  Shockwave(this.origin,{this.color=const Color(0xffffd985)});final Offset origin;final Color color;double age=0;
  @override void update(double dt){age+=dt;if(age>.75)removeFromParent();}
  @override void render(Canvas canvas){final t=(age/.75).clamp(0.0,1.0);canvas.drawCircle(origin,8+100*t,Paint()..color=color.withValues(alpha:1-t)..style=PaintingStyle.stroke..strokeWidth=9*(1-t)..maskFilter=const MaskFilter.blur(BlurStyle.normal,2));canvas.drawCircle(origin,35*(1-t),Paint()..color=color.withValues(alpha:(1-t)*.4)..maskFilter=const MaskFilter.blur(BlurStyle.normal,10));}
}
class ElectricLinks extends Component {
  ElectricLinks(this.points,{this.duration=.65});final List<Offset> points;final double duration;double age=0;
  @override void update(double dt){age+=dt;if(age>duration)removeFromParent();}
  @override void render(Canvas canvas)=>paintLinks(canvas,points,age,(1-age/duration).clamp(0.0,1.0));
  static void paintLinks(Canvas canvas,List<Offset> points,double time,double opacity){
    for(var i=1;i<points.length;i++){
      final a=points[i-1],b=points[i],delta=b-a;final normal=Offset(-delta.dy,delta.dx)/(delta.distance==0?1:delta.distance);
      final path=Path()..moveTo(a.dx,a.dy);
      for(var step=1;step<=9;step++){final t=step/9;final jitter=math.sin(step*5.7+time*55+i)*7*math.sin(t*math.pi);final p=Offset.lerp(a,b,t)!+normal*jitter;path.lineTo(p.dx,p.dy);}
      canvas.drawPath(path,Paint()..color=Colors.cyanAccent.withValues(alpha:opacity*.65)..style=PaintingStyle.stroke..strokeWidth=8..maskFilter=const MaskFilter.blur(BlurStyle.normal,5));
      canvas.drawPath(path,Paint()..color=Colors.white.withValues(alpha:opacity)..style=PaintingStyle.stroke..strokeWidth=2..strokeCap=StrokeCap.round);
      canvas.drawCircle(b,4,Paint()..color=Colors.white.withValues(alpha:opacity));
    }
  }
}
class FloatingPraise extends Component {
  FloatingPraise(this.origin,this.text);final Offset origin;final String text;double age=0;
  @override void update(double dt){age+=dt;if(age>1.3)removeFromParent();}
  @override void render(Canvas canvas){final painter=TextPainter(text:TextSpan(text:text,style:TextStyle(fontFamily:'GardenPersian',fontSize:21,fontWeight:FontWeight.bold,color:const Color(0xffffe6a4).withValues(alpha:(1-age/1.3).clamp(0.0,1.0)),shadows:const[Shadow(color:Color(0xff153d46),blurRadius:7)])),textDirection:TextDirection.rtl)..layout(maxWidth:350);painter.paint(canvas,origin-Offset(painter.width/2,age*45));}
}
