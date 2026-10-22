import 'dart:convert';
import 'package:dream_garden/garden_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('welcome chest grants inventory once and persists across restart',()async{
    SharedPreferences.setMockInitialValues({});final c=GardenController();await c.initialize();
    expect(await c.openChest(),isNotNull);expect(c.coins,350);expect(c.lightning,3);expect(await c.openChest(),isNull);
    final restored=GardenController();await restored.initialize();expect(restored.coins,350);expect(restored.chests,0);expect(restored.hammers,4);c.dispose();restored.dispose();
  });
  test('restoration requires stars, charges once, and saves chosen style',()async{
    SharedPreferences.setMockInitialValues({'dream_garden':jsonEncode({'stars':2,'styles':[1]})});
    final c=GardenController();await c.initialize();await c.buildTask(2);expect(c.stars,1);expect(c.styles,[1,2]);
    await c.buildTask(0);expect(c.styles,[1,2]);
    final restored=GardenController();await restored.initialize();expect(restored.styles,[1,2]);c.dispose();restored.dispose();
  });
  test('invalid lightning costs neither a booster nor a move',()async{
    SharedPreferences.setMockInitialValues({});final c=GardenController();await c.initialize();final moves=c.game.moves;
    expect(await c.discharge([0,0,0]),false);expect(c.lightning,2);expect(c.game.moves,moves);c.dispose();
  });
  test('elapsed regeneration restores only earned lives',()async{
    SharedPreferences.setMockInitialValues({'dream_garden':jsonEncode({'lives':1,'nextLife':DateTime.now().subtract(const Duration(minutes:31)).toIso8601String()})});
    final c=GardenController();await c.initialize();expect(c.lives,3);expect(c.nextLife!.isAfter(DateTime.now()),true);c.dispose();
  });
}
