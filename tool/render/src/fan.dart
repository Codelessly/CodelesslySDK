// One request rendered by several workers of the render server (tool/cli/src/pool.dart starts them, each this
// harness in a process of its own): the files they share, in `<arguments file>.fan/`.
//
// A request is its runs (one, or one per `--state`), and a run is its captures in order: every screen at every
// size, numbered from 0. A worker that takes part in a run walks all its captures in that order and renders each
// one it is the first to claim; what a capture gave (its diagnostics, the files it wrote, what it copied, focused
// and announced) is written as that capture's record. The worker that leads the request waits until every capture
// has its record and makes the report from the records in order, so the report, the diagnostics file and the exit
// status are those of one worker rendering them one after another.
//
//   r<run>.in.<worker>      the worker takes part in the run (it is preparing it, or walking it)
//   r<run>.est              how many captures the run has (known once a worker prepared it)
//   r<run>.solo             the run's captures are rendered one after another (steps over several screens may end
//                           on one page and write one file name): never two at a time
//   r<run>.c<n>.claim       capture n is some worker's (the file holds its name); made with an exclusive create
//   r<run>.c<n>.json        capture n's record: it is rendered and its files are written
//   r<run>.walk.json        what a walk of the whole run found outside its captures: how many there are, and the
//                           diagnostics said before the first and between them
//   yield.<worker>          the server asks the worker to stop taking captures of this request (another request
//                           waits for it); the worker answers when the capture it is on is done
//
// Plain dart:io: the server (tool/cli) reads the same files.
import 'dart:convert';
import 'dart:io';

/// The folder the workers of one request share.
class FanDir {
  FanDir(this.path);

  /// The folder of the request whose arguments are in [argsFile].
  FanDir.of(String argsFile) : path = '$argsFile.fan';

  final String path;

  File _f(String name) => File('$path/$name');

  void create() => Directory(path).createSync(recursive: true);

  bool get exists => Directory(path).existsSync();

  /// Writes [name] whole or not at all (a reader never sees half of it).
  void _write(String name, String text) {
    final tmp = _f('$name.$pid.tmp');
    try {
      tmp.writeAsStringSync(text);
    } on FileSystemException {
      return; // The folder is gone: the request is over (its client left), and nobody reads this.
    }
    try {
      tmp.renameSync('$path/$name');
    } on FileSystemException {
      // Another worker wrote the same file first (on Windows a rename onto a file being read fails): theirs says
      // the same.
      if (tmp.existsSync()) tmp.deleteSync();
    }
  }

  Object? _read(String name) {
    try {
      return jsonDecode(_f(name).readAsStringSync());
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  void _touch(String name) {
    try {
      _f(name).writeAsStringSync('');
    } on FileSystemException {
      // The folder is gone: the request is over.
    }
  }

  void enter(int run, String worker) => _touch('r$run.in.$worker');

  bool solo(int run) => _f('r$run.solo').existsSync();

  void markSolo(int run) => _touch('r$run.solo');

  int? estimate(int run) {
    try {
      return int.tryParse(_f('r$run.est').readAsStringSync().trim());
    } on FileSystemException {
      return null;
    }
  }

  void writeEstimate(int run, int cells) {
    if (!_f('r$run.est').existsSync()) _write('r$run.est', '$cells\n');
  }

  /// What a walk of [run] found: `{"total": n, "pre": [...], "heads": {"<capture>": [...]}}`.
  Map<String, Object?>? walk(int run) => (_read('r$run.walk.json') as Map?)?.cast<String, Object?>();

  void writeWalk(int run, Map<String, Object?> walk) {
    if (!_f('r$run.walk.json').existsSync()) _write('r$run.walk.json', jsonEncode(walk));
  }

  /// Makes capture [cell] of [run] this [worker]'s; false when it is another's already.
  bool claim(int run, int cell, String worker) {
    final f = _f('r$run.c$cell.claim');
    try {
      f.createSync(exclusive: true);
    } on FileSystemException {
      return false;
    }
    try {
      f.writeAsStringSync(worker);
    } on FileSystemException {
      return false;
    }
    return true;
  }

  /// Gives a capture this worker claimed and did not render back.
  void unclaim(int run, int cell) {
    try {
      _f('r$run.c$cell.claim').deleteSync();
    } on FileSystemException {
      // Gone already.
    }
  }

  bool recorded(int run, int cell) => _f('r$run.c$cell.json').existsSync();

  Map<String, Object?>? record(int run, int cell) => (_read('r$run.c$cell.json') as Map?)?.cast<String, Object?>();

  void writeRecord(int run, int cell, Map<String, Object?> record) => _write('r$run.c$cell.json', jsonEncode(record));

  bool yieldAsked(String worker) => _f('yield.$worker').existsSync();

  void askYield(String worker) {
    try {
      _f('yield.$worker').writeAsStringSync('');
    } on FileSystemException {
      // The request's folder is gone: it is over.
    }
  }

  void clearYield(String worker) {
    try {
      _f('yield.$worker').deleteSync();
    } on FileSystemException {
      // None asked.
    }
  }

  /// Where [run] stands: who takes part, how many captures are claimed and recorded.
  ({int entered, int claimed, int recorded, int? estimate, int? total, bool solo}) state(int run) {
    var entered = 0, claimed = 0, recorded = 0;
    var solo = false, walked = false, estimated = false;
    final prefix = 'r$run.';
    try {
      for (final e in Directory(path).listSync()) {
        final name = e.path.substring(e.path.lastIndexOf(RegExp(r'[/\\]')) + 1);
        if (!name.startsWith(prefix) || name.endsWith('.tmp')) continue;
        final rest = name.substring(prefix.length);
        if (rest.startsWith('in.')) {
          entered++;
        } else if (rest == 'solo') {
          solo = true;
        } else if (rest == 'walk.json') {
          walked = true;
        } else if (rest == 'est') {
          estimated = true;
        } else if (rest.endsWith('.claim')) {
          claimed++;
        } else if (rest.startsWith('c') && rest.endsWith('.json')) {
          recorded++;
        }
      }
    } on FileSystemException {
      // The folder is gone: nothing stands.
    }
    final total = walked ? (walk(run)?['total'] as num?)?.toInt() : null;
    return (entered: entered, claimed: claimed, recorded: recorded, estimate: estimated ? estimate(run) : null, total: total, solo: solo);
  }

  /// Gives back every capture [worker] claimed and did not record (it stopped, or is gone), and forgets that it
  /// takes part. Returns how many captures were given back.
  int release(String worker) {
    var freed = 0;
    try {
      for (final e in Directory(path).listSync().whereType<File>()) {
        final name = e.path.substring(e.path.lastIndexOf(RegExp(r'[/\\]')) + 1);
        if (name.endsWith('.in.$worker')) {
          e.deleteSync();
        } else if (name.endsWith('.claim')) {
          final record = File('${e.path.substring(0, e.path.length - '.claim'.length)}.json');
          if (record.existsSync()) continue;
          String owner;
          try {
            owner = e.readAsStringSync();
          } on FileSystemException {
            continue;
          }
          // (A claim just made and not yet signed is its maker's, who is alive: left, unless it has stood so for
          // seconds: its maker stopped between the two.)
          final unsigned = owner.isEmpty && DateTime.now().difference(e.statSync().modified) > const Duration(seconds: 5);
          if ((owner == worker || unsigned) && !record.existsSync()) {
            e.deleteSync();
            freed++;
          }
        }
      }
    } on FileSystemException {
      // The request's folder is gone: nothing to give back.
    }
    return freed;
  }
}
