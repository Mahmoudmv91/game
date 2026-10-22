import 'dart:math';

enum Power { firecracker, bomb, dynamite, rainbow }
enum GameStatus { playing, won, lost }

class Piece {
  Piece(this.color, {this.power}) : id = ++_serial;
  static int _serial = 0;
  final int id;
  final int color;
  Power? power;
}

class GardenGame {
  GardenGame(this.level, {Random? random}) : random = random ?? Random() {
    moves = max(20, 26 - level ~/ 4);
    goals = {level % 5: level == 1 ? 9 : 10 + min(level, 15),
      (level + 2) % 5: level == 1 ? 9 : 10 + min(level, 15)};
    for (var i = 0; i < 49; i++) {
      int color;
      do { color = this.random.nextInt(5); }
      while ((i % 7 > 1 && board[i-1]!.color == color && board[i-2]!.color == color) ||
          (i >= 14 && board[i-7]!.color == color && board[i-14]!.color == color));
      board.add(Piece(color));
    }
    for (var i = 0; i < (level > 1 ? min(4 + level * 2, 25) : 0); i++) {
      soil[(i * 11 + 9) % 49] = level > 4 && i % 3 == 0 ? 2 : 1;
    }
    soilTotal = soil.fold(0, (a, b) => a+b);
    if (hint() == null) shuffle();
  }
  final int level;
  final Random random;
  final board = <Piece?>[];
  final soil = List<int>.filled(49, 0);
  final collected = List<int>.filled(5, 0);
  final dropDistances = List<double>.filled(49, 0);
  late final Map<int,int> goals;
  late final int soilTotal;
  late int moves;
  int score=0, soilCleared=0, rainbowCharge=0, combo=0;
  int swapA=-1, swapB=-1;
  bool busy=false;
  GameStatus status=GameStatus.playing;
  Set<int> powerCenters={}, lightningTargets={};
  Power? effectPower;
  Future<void> Function(String phase, Set<int> indices)? onFrame;
  final _rainbowColors=<int,int>{};

  bool adjacent(int a,int b) => a>=0 && b>=0 && a<49 && b<49 &&
      (a%7-b%7).abs()+(a~/7-b~/7).abs()==1;
  bool near(int a,int b) => a>=0 && b>=0 && a<49 && b<49 && a!=b &&
      (a%7-b%7).abs()<=1 && (a~/7-b~/7).abs()<=1;
  void _exchange(int a,int b) { final c=board[a];board[a]=board[b];board[b]=c; }
  List<List<int>> groups() {
    final result=<List<int>>[];
    for(var axis=0;axis<2;axis++) {
      for(var line=0;line<7;line++) {
        var run=<int>[];
        for(var p=0;p<=7;p++) {
          final i=axis==1?p*7+line:line*7+p;
          final cell=p<7?board[i]:null;
          if(run.isNotEmpty && (cell==null || cell.color!=board[run.first]!.color)) {
            if(run.length>=3)result.add(List.of(run));run=[];
          }
          if(cell!=null)run.add(i);
        }
      }
    }
    return result;
  }
  List<int>? hint() {
    for(var a=0;a<49;a++) {
      if(board[a]?.power!=null)return[a,a];
      for(final b in[a+1,a+7]) {
        if(!adjacent(a,b))continue;
        _exchange(a,b);final valid=groups().isNotEmpty;_exchange(a,b);
        if(valid)return[a,b];
      }
    }
    return null;
  }
  bool shuffle() {
    if(busy || status!=GameStatus.playing)return false;
    return _shuffle();
  }
  bool _shuffle() {
    for(var n=0;n<200;n++) {
      board.shuffle(random);
      if(groups().isEmpty && hint()!=null)return true;
    }
    return false;
  }
  Future<void> _frame(String phase,[Set<int> indices=const{}]) async {
    await onFrame?.call(phase,indices);
  }
  Future<bool> swap(int a,int b) async {
    if(busy || status!=GameStatus.playing || !adjacent(a,b))return false;
    busy=true;swapA=a;swapB=b;
    try {
      _exchange(a,b);await _frame('swap');
      final specials=[a,b].where((i)=>board[i]!.power!=null).toList();
      if(specials.isEmpty && groups().isEmpty) {
        _exchange(a,b);await _frame('invalid',{a,b});return false;
      }
      moves--;_rainbowColors.clear();final forced=<int>{};
      for(final i in specials) {
        forced.add(i);
        if(board[i]!.power==Power.rainbow) {
          final other=i==a?b:a;
          _rainbowColors[i]=board[other]!.color;
          for(var j=0;j<49;j++) {
            if(board[other]!.power==Power.rainbow || board[j]!.color==board[other]!.color) {
              forced.add(j);
              if(j!=i && board[other]!.power!=null && board[other]!.power!=Power.rainbow) {
                board[j]!.power=board[other]!.power;
              }
            }
          }
          lightningTargets=Set.of(forced);await _frame('lightning',forced);
        }
      }
      await _resolve(forced,b);_finish();return true;
    } finally {busy=false;await _frame('idle');}
  }
  Future<bool> activate(int index) async {
    if(index<0 || index>=49 || busy || status!=GameStatus.playing || board[index]!.power==null)return false;
    busy=true;
    try {
      moves--;_rainbowColors.clear();final forced=<int>{index};
      if(board[index]!.power==Power.rainbow) {
        for(var i=0;i<49;i++){if(board[i]!.color==board[index]!.color)forced.add(i);}
        lightningTargets=Set.of(forced);await _frame('lightning',forced);
      }
      await _resolve(forced,-1);_finish();return true;
    } finally {busy=false;await _frame('idle');}
  }
  Future<bool> hammer(int index) async {
    if(index<0 || index>=49 || busy || status!=GameStatus.playing)return false;
    busy=true;
    try{_rainbowColors.clear();await _resolve({index},-1);_finish();return true;}
    finally{busy=false;await _frame('idle');}
  }
  Future<bool> chain(List<int> path) async {
    if(busy || status!=GameStatus.playing || path.length<3 || path.toSet().length!=path.length ||
        path.any((i)=>i<0 || i>=49))return false;
    final color=board[path.first]!.color;
    if(path.any((i)=>board[i]!.color!=color))return false;
    busy=true;
    try {
      moves--;_rainbowColors.clear();lightningTargets=path.toSet();
      await _frame('lightning',path.toSet());await _resolve(path.toSet(),-1);_finish();return true;
    } finally {busy=false;await _frame('idle');}
  }
  int radius(Power p)=>switch(p){Power.firecracker=>1,Power.bomb=>2,Power.dynamite=>3,Power.rainbow=>0};
  Future<void> _resolve(Set<int> forced,int preferred) async {
    for(var chain=0;chain<50;chain++) {
      combo=chain;final matches=groups();
      // Intersecting lines form one T/L cluster, so five-piece shapes create bombs too.
      for(var a=0;a<matches.length;a++){
        for(var b=a+1;b<matches.length;b++){
          if(matches[a].any(matches[b].contains)){
            matches[a]={...matches[a],...matches[b]}.toList();matches.removeAt(b);a=-1;break;
          }
        }
      }
      if(forced.isEmpty && matches.isEmpty)break;
      final clear=<int>{...forced,...matches.expand((x)=>x)};
      final creations=<int,Power>{};
      if(forced.isEmpty) {
        for(final g in matches) {
          if(g.length<4)continue;
          final at=g.contains(preferred)?preferred:g[g.length~/2];
          if(board[at]!.power==null)creations[at]=g.length==4?Power.firecracker:g.length==5?Power.bomb:Power.dynamite;
        }
      }
      powerCenters={};effectPower=null;final processed=<int>{};
      while(clear.difference(processed).isNotEmpty) {
        final i=clear.difference(processed).first;processed.add(i);
        final cell=board[i]!;final power=cell.power;
        if(power==null)continue;
        powerCenters.add(i);effectPower=power;
        if(power==Power.rainbow) {
          final color=_rainbowColors[i]??cell.color;
          for(var j=0;j<49;j++){if(board[j]!.color==color)clear.add(j);}
        }else{
          rainbowCharge=min(6,rainbowCharge+1);
          final r=radius(power);
          for(var dy=-r;dy<=r;dy++) {
            for(var dx=-r;dx<=r;dx++) {
              final y=i~/7+dy,x=i%7+dx;
              if(y>=0 && y<7 && x>=0 && x<7)clear.add(y*7+x);
            }
          }
        }
      }
      clear.removeAll(creations.keys);score+=clear.length*50*(chain+1);
      for(final i in clear){collected[board[i]!.color]++;if(soil[i]>0){soil[i]--;soilCleared++;}}
      await _frame('clear',clear);
      final oldPositions=<int,int>{for(var i=0;i<49;i++)board[i]!.id:i};
      for(final e in creations.entries){board[e.key]!.power=e.value;}
      for(final i in clear){board[i]=null;}
      for(var x=0;x<7;x++) {
        final column=<Piece>[];
        for(var y=6;y>=0;y--){if(board[y*7+x]!=null)column.add(board[y*7+x]!);}
        for(var y=6;y>=0;y--) {
          final piece=6-y<column.length?column[6-y]:Piece(random.nextInt(5));
          board[y*7+x]=piece;
          final old=oldPositions[piece.id];
          dropDistances[y*7+x]=old!=null?(y-old~/7).toDouble():(7-column.length).toDouble();
        }
      }
      await _frame('fall');forced={};preferred=-1;_rainbowColors.clear();
    }
    if(rainbowCharge>=6) {
      final choices=List.generate(49,(i)=>i).where((i)=>board[i]!.power==null).toList();
      if(choices.isNotEmpty){final at=choices[random.nextInt(choices.length)];board[at]!.power=Power.rainbow;rainbowCharge=0;await _frame('charged',{at});}
    }
    if(hint()==null){_shuffle();await _frame('shuffle');}
  }
  void _finish() {
    if(goals.entries.every((g)=>collected[g.key]>=g.value) && soilCleared>=soilTotal)status=GameStatus.won;
    else if(moves<=0)status=GameStatus.lost;
  }
}
