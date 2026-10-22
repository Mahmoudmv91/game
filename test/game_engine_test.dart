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
    expect(game.moves,23);
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
}
