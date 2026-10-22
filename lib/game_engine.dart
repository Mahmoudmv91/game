import 'dart:math';

enum Power { bomb, rainbow }
enum GameStatus { playing, won, lost }

class Piece {
  Piece(this.color, {this.power});
  final int color;
  Power? power;
}

/// UI-independent rules. Flame or a Flutter painter can render this engine.
class GardenGame {
  GardenGame(this.level, {Random? random}) : random = random ?? Random() {
    moves = max(18, 24 - level ~/ 4);
    goals = {level % 5: level == 1 ? 9 : 10 + min(level, 15),
      (level + 2) % 5: level == 1 ? 9 : 10 + min(level, 15)};
    for (var i = 0; i < 49; i++) {
      int color;
      do { color = this.random.nextInt(5); }
      while ((i % 7 > 1 && board[i - 1]!.color == color && board[i - 2]!.color == color) ||
        (i >= 14 && board[i - 7]!.color == color && board[i - 14]!.color == color));
      board.add(Piece(color));
    }
    for (var i = 0; i < (level > 1 ? min(4 + level * 2, 25) : 0); i++) {
      soil[(i * 11 + 9) % 49] = level > 4 && i % 3 == 0 ? 2 : 1;
    }
    soilTotal = soil.fold(0, (a, b) => a + b);
    if (hint() == null) shuffle();
  }

  final int level;
  final Random random;
  final board = <Piece?>[];
  final soil = List<int>.filled(49, 0);
  final collected = List<int>.filled(5, 0);
  late final Map<int, int> goals;
  late final int soilTotal;
  late int moves;
  int score = 0, soilCleared = 0;
  bool busy = false;
  GameStatus status = GameStatus.playing;
  Future<void> Function(String phase, Set<int> indices)? onFrame;

  bool adjacent(int a, int b) => a >= 0 && b >= 0 && a < 49 && b < 49 &&
    (a % 7 - b % 7).abs() + (a ~/ 7 - b ~/ 7).abs() == 1;

  List<List<int>> groups() {
    final result = <List<int>>[];
    for (var axis = 0; axis < 2; axis++) {
      for (var line = 0; line < 7; line++) {
        var run = <int>[];
        for (var p = 0; p <= 7; p++) {
          final index = axis == 1 ? p * 7 + line : line * 7 + p;
          final cell = p < 7 ? board[index] : null;
          if (run.isNotEmpty && (cell == null || cell.color != board[run.first]!.color)) {
            if (run.length >= 3) result.add(List.of(run));
            run = [];
          }
          if (cell != null) run.add(index);
        }
      }
    }
    return result;
  }

  void _exchange(int a, int b) { final item = board[a]; board[a] = board[b]; board[b] = item; }

  List<int>? hint() {
    for (var a = 0; a < 49; a++) {
      if (board[a]?.power != null) return [a, a];
      for (final b in [a + 1, a + 7]) {
        if (!adjacent(a, b)) continue;
        _exchange(a, b);
        final valid = groups().isNotEmpty;
        _exchange(a, b);
        if (valid) return [a, b];
      }
    }
    return null;
  }

  bool shuffle() {
    for (var i = 0; i < 200; i++) {
      board.shuffle(random);
      if (groups().isEmpty && hint() != null) return true;
    }
    return false;
  }

  Future<void> _frame(String phase, [Set<int> indices = const {}]) async {
    await onFrame?.call(phase, indices);
  }

  Future<bool> swap(int a, int b) async {
    if (busy || status != GameStatus.playing || !adjacent(a, b)) return false;
    busy = true;
    try {
      _exchange(a, b);
      await _frame('swap');
      final special = [a, b].where((i) => board[i]!.power != null).toList();
      if (special.isEmpty && groups().isEmpty) {
        _exchange(a, b);
        await _frame('invalid', {a, b});
        return false;
      }
      moves--;
      final forced = <int>{};
      for (final i in special) {
        forced.add(i);
        if (board[i]!.power == Power.rainbow) {
          final other = i == a ? b : a;
          for (var j = 0; j < 49; j++) {
            if (board[other]!.power == Power.rainbow || board[j]!.color == board[other]!.color) forced.add(j);
          }
        }
      }
      await _resolve(forced, b);
      _finish();
      return true;
    } finally { busy = false; await _frame('idle'); }
  }

  Future<bool> activate(int index) async {
    if (index < 0 || index >= 49 || busy || status != GameStatus.playing || board[index]!.power == null) return false;
    busy = true;
    try {
      moves--;
      final forced = <int>{index};
      if (board[index]!.power == Power.rainbow) {
        for (var j = 0; j < 49; j++) { if (board[j]!.color == board[index]!.color) forced.add(j); }
      }
      await _resolve(forced, -1); _finish(); return true;
    } finally { busy = false; await _frame('idle'); }
  }

  Future<bool> hammer(int index) async {
    if (index < 0 || index >= 49 || busy || status != GameStatus.playing) return false;
    busy = true;
    try { await _resolve({index}, -1); _finish(); return true; }
    finally { busy = false; await _frame('idle'); }
  }

  Future<void> _resolve(Set<int> forced, int preferred) async {
    for (var chain = 0; chain < 50; chain++) {
      final matches = groups();
      if (forced.isEmpty && matches.isEmpty) break;
      final clear = <int>{...forced, ...matches.expand((g) => g)};
      final creations = <int, Power>{};
      if (forced.isEmpty) {
        for (final group in matches) {
          if (group.length < 4) continue;
          final at = group.contains(preferred) ? preferred : group[group.length ~/ 2];
          if (board[at]!.power == null) creations[at] = group.length >= 5 ? Power.rainbow : Power.bomb;
        }
      }
      final processed = <int>{};
      while (clear.difference(processed).isNotEmpty) {
        final i = clear.difference(processed).first;
        processed.add(i);
        final cell = board[i]!;
        if (cell.power == Power.bomb) {
          for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              final y = i ~/ 7 + dy, x = i % 7 + dx;
              if (y >= 0 && y < 7 && x >= 0 && x < 7) clear.add(y * 7 + x);
            }
          }
        } else if (cell.power == Power.rainbow) {
          for (var j = 0; j < 49; j++) { if (board[j]!.color == cell.color) clear.add(j); }
        }
      }
      clear.removeAll(creations.keys);
      score += clear.length * 50 * (chain + 1);
      for (final i in clear) {
        collected[board[i]!.color]++;
        if (soil[i] > 0) { soil[i]--; soilCleared++; }
      }
      await _frame('clear', clear);
      for (final entry in creations.entries) { board[entry.key]!.power = entry.value; }
      for (final i in clear) { board[i] = null; }
      for (var x = 0; x < 7; x++) {
        final column = <Piece>[];
        for (var y = 6; y >= 0; y--) { if (board[y * 7 + x] != null) column.add(board[y * 7 + x]!); }
        for (var y = 6; y >= 0; y--) { board[y * 7 + x] = 6 - y < column.length ? column[6 - y] : Piece(random.nextInt(5)); }
      }
      await _frame('fall'); forced = {}; preferred = -1;
    }
    if (hint() == null) { shuffle(); await _frame('shuffle'); }
  }

  void _finish() {
    if (goals.entries.every((g) => collected[g.key] >= g.value) && soilCleared >= soilTotal) {
      status = GameStatus.won;
    } else if (moves <= 0) { status = GameStatus.lost; }
  }
}
