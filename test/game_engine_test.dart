import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dream_garden/game_engine.dart';

void main() {
  test('all levels begin stable and playable', () {
    for (var level=1;level<=20;level++) {
      final game=GardenGame(level,random:Random(level));
      expect(game.board.length,49);
      expect(game.board.every((p)=>p!=null),true);
      expect(game.groups(),isEmpty);
      expect(game.hint(),isNotNull);
    }
  });
  test('a valid move spends one move and settles', () async {
    final game=GardenGame(1,random:Random(8));
    final move=game.hint()!;
    expect(await game.swap(move[0],move[1]),true);
    expect(game.moves,25);
    expect(game.score,greaterThanOrEqualTo(150));
    expect(game.groups(),isEmpty);
    expect(game.busy,false);
  });
  test('grid edges do not wrap', () {
    final game=GardenGame(1);
    expect(game.adjacent(6,7),false);
    expect(game.adjacent(0,7),true);
  });
  test('hammer clears soil without spending a move', () async {
    final game=GardenGame(3,random:Random(3));
    final before=game.moves;
    await game.hammer(game.soil.indexWhere((n)=>n>0));
    expect(game.moves,before);
    expect(game.soilCleared,greaterThan(0));
  });

  test('lightning links distant same-color pieces and spends exactly one move',()async{
    final game=GardenGame(1,random:Random(11));
    final color=game.board[0]!.color;
    final path=List.generate(49,(i)=>i).where((i)=>game.board[i]!.color==color).take(4).toList();
    final before=game.moves;final phases=<String>[];
    game.onFrame=(phase,indices)async{phases.add(phase);};
    expect(await game.chain(path),true);expect(game.moves,before-1);expect(phases,contains('lightning'));
    expect(game.collected[color],greaterThanOrEqualTo(path.length));expect(game.groups(),isEmpty);
  });
  test('invalid swaps roll back piece identities and do not spend a move',()async{
    final game=GardenGame(1,random:Random(4));
    List<int>? invalid;
    for(var a=0;a<48&&invalid==null;a++){
      final b=a+1;if(!game.adjacent(a,b))continue;
      final x=game.board[a];game.board[a]=game.board[b];game.board[b]=x;
      final bad=game.groups().isEmpty;game.board[b]=game.board[a];game.board[a]=x;
      if(bad)invalid=[a,b];
    }
    final ids=game.board.map((p)=>p!.id).toList();final before=game.moves;
    expect(await game.swap(invalid![0],invalid[1]),false);expect(game.board.map((p)=>p!.id),ids);expect(game.moves,before);
  });
  test('a bomb clears its full area and charge creates a rainbow',()async{
    final game=GardenGame(1,random:Random(12));game.board[24]!.power=Power.bomb;game.rainbowCharge=5;
    Set<int>? firstClear;game.onFrame=(phase,indices)async{if(phase=='clear')firstClear??=Set.of(indices);};
    expect(await game.activate(24),true);expect(firstClear!.length,greaterThanOrEqualTo(25));
    expect(game.board.any((p)=>p!.power==Power.rainbow),true);expect(game.rainbowCharge,0);
    expect(game.dropDistances.any((d)=>d>0),true);
  });
  test('rainbow swap selects the other piece color',()async{
    final game=GardenGame(1,random:Random(19));game.board[0]=Piece(0,power:Power.rainbow);game.board[1]=Piece(1);
    Set<int>? targets;game.onFrame=(phase,indices)async{if(phase=='lightning')targets=Set.of(indices);};
    final expected=List.generate(49,(i)=>i).where((i)=>game.board[i]!.color==1&&i!=1).toSet()..addAll([0,1]);
    await game.swap(0,1);expect(targets,expected);expect(game.busy,false);
  });
  test('many cascades across all levels remain full, stable, and playable',()async{
    for(var level=1;level<=20;level++){
      final game=GardenGame(level,random:Random(level+200));
      for(var n=0;n<8&&game.status==GameStatus.playing;n++){
        final hint=game.hint()!;if(hint[0]==hint[1]){await game.activate(hint[0]);}else{await game.swap(hint[0],hint[1]);}
        expect(game.board.every((p)=>p!=null),true);expect(game.groups(),isEmpty);expect(game.hint(),isNotNull);expect(game.busy,false);
      }
    }
  });
}
