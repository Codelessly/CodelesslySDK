// The render server: one address, several workers.
//
//   codelessly_cli render-pool --dir <build/.render-server> --flutter <flutter command> [--workers n|auto]
//       [--min-workers n] [--max-workers n] [--retire-after s] [--idle s] [--queue n] [--request-timeout s]
//       [--recycle-mb n] [--recycle-after n]
//
// How many workers: by default (`--workers auto`) the server starts four and follows its load (autoscale.dart).
// A burst of a few clients finds them up; `--min-workers 1` is one warm worker and one engine for one client.
// When work waits with no worker idle (requests in the queue, or captures of a request nobody took), workers are
// added in growing steps, each up in about a second; what stops the growth is a signal, not a number: a worker
// that does not start, free memory that would fall under a reserve, or a raise that did not raise the work done
// per second (the level is then a ceiling for two minutes). Workers idle for a minute are ended, down to four.
// `--workers n` is that many from start to stop.
//
// tool/render/serve.sh starts it (tool/codelessly serve). Rendering in Flutter's engine runs on one thread of one
// process, so rendering in parallel is several processes: this one listens where the render command asks
// (<dir>/port: the port and a token) and hands each request to a worker, the render harness
// (tool/render/render_harness.dart) run by Flutter's headless engine (flutter_tester) in a process of its own.
//
// The harness is compiled once (build/render_pool/harness.dill, made again when a source it is made of changed)
// and every worker runs that file: a worker starts in about half a second, with no `flutter test` and none of the
// writes to build/ that make those take turns. When this Flutter has no such files, the workers are started with
// `flutter test`, one after another.
//
// Requests:
//   <token> <arguments file>        a render (render.sh's form); answered `done` when its report is written
//   <token> run <arguments file>    the same from tool/codelessly render; answered `queued <n>` when it has to
//                                   wait, then `done`, `busy <queued> <limit>` (the queue is full) or
//                                   `failed <why>`
//   <token> status                  where the server stands, as JSON
//   <dir>/<id>.req                  a file holding the path of an arguments file: a render asked without a socket,
//                                   answered by its report and status files alone
//   <token> stop                    stop
//
// A request is led by one worker, which writes its report; while other workers are idle and no request waits,
// they help with its captures (tool/render/src/fan.dart), so one request of many captures is rendered in
// parallel too. A request that waits takes workers back: helpers leave after the capture they are on, and a
// leader that has rendered for a second makes way for a request that has had less of the workers' time, its own
// going on later from where it is. So requests take turns by what they have had, not by when they came.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../render/src/fan.dart';
import 'autoscale.dart';
import 'common.dart';
import 'memory.dart';

/// What a worker may hold before it is replaced by a fresh one (when idle): the engine's memory grows with the
/// captures it has made, about a megabyte each.
const defaultRecycleMb = 1024;

/// The workers `--workers auto` starts with and keeps, unless `--min-workers` or `--max-workers` says fewer.
const defaultMinWorkers = 4;

/// How many requests at a time a client that has many (tool/codelessly states) should send a server that
/// follows its load: half the processors (the other half are the same cores twice on most machines, and the
/// agents asking need some), 8 at most, within the server's own bounds. The server grows to render them.
int parallelHint({int? processors, int least = 1, int? most}) {
  var n = min(max(1, (processors ?? Platform.numberOfProcessors) ~/ 2), 8);
  if (n < least) n = least;
  if (most != null && n > most) n = most;
  return n;
}

/// The free memory a raise of the pool must leave: an eighth of the machine's, between half a gigabyte and two.
int memoryReserveMb(int? totalMb) => totalMb == null ? 1024 : (totalMb ~/ 8).clamp(512, 2048);

/// What `--workers` says: a whole number (that many, from start to stop), or `auto` (null: follow the load).
int? workersOption(String? value) {
  if (value == null || value.trim().toLowerCase() == 'auto') return null;
  final n = int.tryParse(value);
  if (n == null || n < 1) throw UsageError('--workers takes a whole number, 1 or more, or auto (given "$value").');
  return n;
}

enum _WorkerState { starting, idle, busy, gone }

class _Worker {
  _Worker(this.id, this.dir);
  final String id;
  final String dir;
  Process? process;
  int port = 0;
  String token = '';
  _WorkerState state = _WorkerState.starting;
  _Job? job;
  String role = '';
  DateTime since = DateTime.now();
  final DateTime started = DateTime.now();

  /// Whether the server asked it to make way for a waiting request (it answers after the capture it is on).
  bool asked = false;
  int served = 0, captures = 0, rss = 0;

  /// The warm-up renders it still has to do before its code runs as fast as it will (a request it renders
  /// counts as one).
  int warmLeft = 0;
  bool leaving = false;

  /// Ended once it is idle because the pool shrinks (not replaced by a fresh one).
  bool retiring = false;

  /// Since when it has had nothing to do.
  DateTime idleSince = DateTime.now();
}

class _Job {
  _Job(this.id, this.argsFile, this.client, {required this.v2, required this.runs, required this.shareable, this.single = false});
  final int id;
  final String argsFile;
  final Socket? client;
  final bool v2;

  /// How many runs it has (one, or one for each `--state`); whether other workers may help with it.
  final int runs;
  final bool shareable;

  /// One capture, as far as its arguments say ([asksOneCapture]): one worker renders it with no shared folder,
  /// and the server does not look for captures others could take.
  final bool single;

  /// The captures its workers said they rendered, and how many of them the autoscaler was told of already.
  int rendered = 0, counted = 0;

  /// The captures nobody took when the server last looked and had no idle worker to send.
  int unmet = 0;
  late final FanDir dir = FanDir.of(argsFile);
  final DateTime arrived = DateTime.now();
  DateTime? firstStarted;
  _Worker? leader;
  final Set<_Worker> helpers = {};

  /// The workers' time it has had, in microseconds (its leaders' and helpers').
  int service = 0;
  int crashes = 0, retries = 0, parked = 0;
  DateTime lastHelper = DateTime.fromMillisecondsSinceEpoch(0);
  int joining = 0;
  bool over = false;

  /// What to tell the client once the helpers have left.
  String? verdict;
  Timer? timeout;
  bool warm = false;

  /// A warm-up that is not given up for a waiting request (a new worker's first: most of what it compiles).
  bool keep = false;
}

class _Pool {
  _Pool({
    required this.dir,
    required this.flutter,
    required this.fixedWorkers,
    required this.policy,
    required this.idle,
    required this.maxQueue,
    required this.requestTimeout,
    required this.recycleBytes,
    required this.recycleAfter,
  });

  final String dir;
  final String flutter;

  /// `--workers n`: that many from start to stop. Null (`--workers auto`, the default): the pool follows its
  /// load (autoscale.dart), from [AutoscalePolicy.min] up, with no fixed top unless [AutoscalePolicy.max] is one.
  final int? fixedWorkers;
  final AutoscalePolicy policy;
  late final Autoscaler _scaler = Autoscaler(policy);
  late final AutoscaleState _scale = _scaler.start(DateTime.now());

  bool get auto => fixedWorkers == null;

  /// The workers the server should have now.
  int get workerCount => fixedWorkers ?? _scale.limit;

  /// For tests: workers from this number on do not start (`CODELESSLY_RENDER_DEBUG_FAIL_START_FROM`).
  final int? _failStartFrom = int.tryParse(Platform.environment['CODELESSLY_RENDER_DEBUG_FAIL_START_FROM'] ?? '');

  final Duration idle;
  final int maxQueue;
  final Duration requestTimeout;
  final int recycleBytes;
  final int recycleAfter;

  /// How long a leader renders before a request that has had less may take its worker.
  static const quantum = Duration(milliseconds: 1000);

  final String sdk = sdkRoot.path.replaceAll(r'\', '/');
  final List<_Worker> workers = [];
  final List<_Job> waiting = [];
  final Set<_Job> active = {};
  final String token = [for (var i = 0; i < 16; i++) Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')].join();
  final DateTime started = DateTime.now();
  DateTime lastActivity = DateTime.now();
  int _nextWorker = 0, _nextJob = 0;
  int served = 0, failed = 0, captures = 0, restarts = 0, crashes = 0, recycled = 0, busyRefused = 0;
  final List<int> _latencies = [];
  ServerSocket? _listener;
  Timer? _tick;
  bool _stopping = false, _ready = false;
  late final _Launch _launch;
  String? _warmSite;

  void log(String line) => stdout.writeln('${DateTime.now().toIso8601String().substring(11, 23)} $line');

  Future<int> run() async {
    Directory(dir).createSync(recursive: true);
    final launch = await _Launch.prepare(sdk, flutter, dir, log);
    if (launch == null) return 2;
    _launch = launch;
    _warmSite = _writeWarmSite();
    _listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _listener!.listen(_accept, onError: (Object _) {});
    log('Render server: ${_launch.how}, ${auto ? 'workers follow the load (from ${policy.min}${policy.max == null ? '' : ' to ${policy.max}'})' : '$workerCount worker${workerCount == 1 ? '' : 's'}'}, port ${_listener!.port}.');
    // One worker first (the server takes requests as soon as it is up), then any others asked for, a few at a
    // time. A server that follows its load starts no other until work waits.
    final first = _spawn();
    final up = await first;
    if (!up) {
      log('The first worker did not start: see ${workers.first.dir}.log');
      await _shutdown();
      return 2;
    }
    File('$dir/port.tmp')
      ..writeAsStringSync('${_listener!.port} $token\n')
      ..renameSync('$dir/port');
    File('$dir/ready').writeAsStringSync('$pid\n');
    _ready = true;
    lastActivity = DateTime.now();
    unawaited(_spawnRest());
    Timer.periodic(housekeepingEvery, (_) => _housekeeping());
    return _stopped.future;
  }

  /// How often the server looks at what no event tells it: its stop file, request files, idle workers to end.
  /// (A request over the socket, a worker's answer and a worker's end are events: nothing waits for this.)
  static const housekeepingEvery = Duration(milliseconds: 250);

  final Completer<int> _stopped = Completer<int>();

  int get _alive => workers.where((w) => w.state != _WorkerState.gone && !w.retiring).length;
  /// The workers not up yet: their process is starting, or they are in the warm-up round they do first.
  int get _starting =>
      workers.where((w) => w.state == _WorkerState.starting || (w.state == _WorkerState.busy && w.job != null && w.job!.warm && w.job!.keep)).length;

  Future<void> _spawnRest() async {
    // (With `flutter test` one after another: each rewrites build/ as it starts.)
    final atOnce = _launch.direct ? 4 : 1;
    while (!_stopping && !_gaveUp && _alive < workerCount) {
      final missing = workerCount - _alive;
      await Future.wait([for (var i = 0; i < min(atOnce, missing); i++) _spawn()]);
    }
  }

  /// Starts a worker and waits until it takes requests. False when it did not start.
  Future<bool> _spawn() async {
    final w = _Worker('w${_nextWorker++}', '$dir/w${_nextWorker - 1}');
    workers.add(w);
    Directory(w.dir).createSync(recursive: true);
    try {
      if (_failStartFrom != null && _nextWorker > _failStartFrom) throw StateError('made to fail (CODELESSLY_RENDER_DEBUG_FAIL_START_FROM)');
      w.process = await _launch.start(w.id, w.dir, idle: idle + const Duration(minutes: 10));
    } on Object catch (e) {
      log('Worker ${w.id} could not be started: $e');
      w.state = _WorkerState.gone;
      _startFailed('${w.id} could not be started');
      // (Not at once again, whatever asks: what refused it is there for a moment more.)
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return false;
    }
    final out = File('${w.dir}.log').openWrite();
    w.process!.stdout.listen(out.add, onError: (Object _) {});
    w.process!.stderr.listen(out.add, onError: (Object _) {});
    unawaited(w.process!.exitCode.then((code) {
      out.close();
      _gone(w, 'its process ended (exit $code)');
    }));
    final limit = DateTime.now().add(_launch.direct ? const Duration(minutes: 2) : const Duration(minutes: 15));
    while (w.state == _WorkerState.starting && DateTime.now().isBefore(limit) && !_stopping) {
      if (File('${w.dir}/ready').existsSync() && File('${w.dir}/port').existsSync()) {
        try {
          final at = File('${w.dir}/port').readAsStringSync().trim().split(' ');
          w.port = int.parse(at[0]);
          w.token = at[1];
          break;
        } on Object {
          // Being written: next look.
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (w.port == 0 || w.state != _WorkerState.starting) {
      if (w.state == _WorkerState.starting) _gone(w, 'it did not start in time');
      return false;
    }
    w.warmLeft = _warmSite == null ? 0 : warmRounds;
    w.state = _WorkerState.idle;
    // The first warm-up before it is given a request: what it compiles as it first renders is most of the cost.
    // (Its state says busy meanwhile, so no request is handed to it before the round is over.)
    // (The server's first worker: whoever started the server asks next, so the quiet before a further round
    // starts when this one is up.)
    if (!_ready) lastActivity = DateTime.now().add(const Duration(minutes: 1));
    if (w.warmLeft > 0) await _warm(w, first: true);
    if (!_ready) lastActivity = DateTime.now();
    if (w.state == _WorkerState.gone) return false;
    w.idleSince = DateTime.now();
    _startFailures = 0;
    log('Worker ${w.id} up (pid ${w.process!.pid}).');
    // The workers of a raise are up: the rate at the new level is measured from here.
    if (auto && _starting == 0) _scaler.landed(_scale, DateTime.now());
    _schedule();
    return true;
  }

  /// A worker did not start. A pool that follows its load takes that as the level's refusal (starting fewer is
  /// the only thing that helps a machine that will not take another): cut to what runs, and remembered.
  void _startFailed(String why) {
    // (Workers that never come up are not started over and over.)
    if (++_startFailures > workerCount * 3 + 10 && !_gaveUp) {
      _gaveUp = true;
      log('Workers keep failing to start: no more are started.');
    }
    if (!auto || !_ready) return;
    final up = workers.where((w) => (w.state == _WorkerState.idle || w.state == _WorkerState.busy) && !w.retiring).length;
    final change = _scaler.refused(_scale, DateTime.now(), running: up, kind: 'start_failure', why: why);
    if (change != null) _applied(change);
  }

  int _startFailures = 0;

  static const warmRounds = 6;

  /// How long nobody must have asked before the last free worker is taken to be as warm as it gets without a
  /// client (it does no warm-up round of its own: [_warmIdle]).
  static const quietBeforeWarm = Duration(seconds: 1);

  /// A small site of the usual nodes, rendered by each new worker so the code a render runs is compiled before
  /// the first request (the engine runs it interpreted, then compiled as it proves hot).
  String? _writeWarmSite() {
    final source = Directory('$sdk/tool/render/warmup');
    if (!source.existsSync()) return null;
    final site = Directory('$dir/warm-site')..createSync(recursive: true);
    for (final f in source.listSync().whereType<File>()) {
      f.copySync('${site.path}/${f.uri.pathSegments.last}');
    }
    return site.path;
  }

  /// One warm-up round on [w]. A round after the [first] is given up for a request that waits: the worker stops
  /// at the round's next capture (three a round).
  Future<void> _warm(_Worker w, {bool first = false}) async {
    final out = '${w.dir}/warm';
    Directory(out).createSync(recursive: true);
    final argsFile = '$out/args';
    final fan = Directory('$argsFile.fan');
    if (fan.existsSync()) fan.deleteSync(recursive: true);
    File(argsFile).writeAsStringSync([_warmSite!, '--out', out, '--no-google-fonts', '--dump-layout'].map((a) => '$a\u0000').join());
    final job = _Job(-1, argsFile, null, v2: false, runs: 1, shareable: false)
      ..warm = true
      ..keep = first;
    w.warmLeft--;
    await _assign(w, job, 'lead');
  }

  void _accept(Socket socket) {
    socket.setOption(SocketOption.tcpNoDelay, true);
    final text = StringBuffer();
    _Job? job;
    utf8.decoder.bind(socket).listen((chunk) {
      if (job != null) return;
      text.write(chunk);
      final end = '$text'.indexOf('\n');
      if (end < 0) return;
      final line = '$text'.substring(0, end).trimRight();
      if (!line.startsWith('$token ')) {
        socket.destroy();
        return;
      }
      final rest = line.substring(token.length + 1);
      if (rest == 'status') {
        _reply(socket, jsonEncode(status()));
        return;
      }
      if (rest == 'stop') {
        _reply(socket, 'stopping');
        unawaited(_shutdown());
        return;
      }
      final v2 = rest.startsWith('run ');
      job = _enqueue(v2 ? rest.substring(4) : rest, socket, v2: v2);
    }, onError: (Object _) {
      socket.destroy();
    }, onDone: () {
      // The client is gone: a request of its that still waits is dropped.
      final j = job;
      if (j != null && !j.over && waiting.remove(j)) {
        j.over = true;
        j.timeout?.cancel();
        log('Request ${j.id} dropped: its client left while it waited.');
      }
    }, cancelOnError: true);
  }

  void _reply(Socket? socket, String line) {
    if (socket == null) return;
    try {
      socket.write('$line\n');
      socket.flush().then((_) => socket.close()).catchError((Object _) => socket.destroy());
    } on Object {
      socket.destroy();
    }
  }

  void _say(_Job job, String line) {
    try {
      job.client?.write('$line\n');
    } on Object {
      // The client is gone.
    }
  }

  _Job? _enqueue(String argsFile, Socket? socket, {required bool v2}) {
    lastActivity = DateTime.now();
    if (_stopping) {
      _reply(socket, v2 ? 'failed The render server is stopping.' : 'stopping');
      return null;
    }
    // (A request a worker is free for does not wait: it is never refused.)
    if (waiting.length >= maxQueue && (_idle.isEmpty || waiting.isNotEmpty)) {
      busyRefused++;
      // (render.sh's form has no word for it: the connection closes, and it renders the usual way.)
      if (v2) {
        _reply(socket, 'busy ${waiting.length} $maxQueue');
      } else {
        socket?.destroy();
      }
      return null;
    }
    var runs = 1, shareable = true, single = false;
    try {
      final args = File(argsFile).readAsStringSync().split('\u0000');
      if (args.isNotEmpty && args.last.isEmpty) args.removeLast();
      runs = max(1, args.where((a) => a == '--state').length);
      shareable = !args.contains('--sheet');
      single = asksOneCapture(args);
    } on FileSystemException {
      _reply(socket, v2 ? 'failed The render server cannot read the request ($argsFile).' : 'failed');
      return null;
    }
    final job = _Job(_nextJob++, argsFile, socket, v2: v2, runs: runs, shareable: shareable, single: single);
    job.timeout = Timer(requestTimeout, () => _timedOut(job));
    waiting.add(job);
    _schedule();
    if (waiting.contains(job) && v2) _say(job, 'queued ${waiting.indexOf(job) + 1}');
    return job;
  }

  List<_Worker> get _idle => [for (final w in workers) if (w.state == _WorkerState.idle && !w.leaving && !w.retiring) w];

  void _schedule() {
    if (_stopping) return;
    // Waiting requests first, the one that waited longest on the worker that is warmest.
    while (waiting.isNotEmpty) {
      final idle = _idle..sort(_warmestFirst);
      if (idle.isEmpty) break;
      final job = waiting.removeAt(0);
      unawaited(_assign(idle.first, job, job.single ? 'solo' : 'lead'));
    }
    if (waiting.isNotEmpty) {
      _makeWay();
    } else {
      _help();
      _warmIdle();
    }
    if (auto) _follow();
    // Looked at again in a moment: while requests wait (a worker may be asked to make way), while idle workers
    // could take captures of a request being rendered, and while a pool that follows its load has captures nobody
    // took. Not for a request of one capture: nothing about it changes until its worker answers.
    final shared = active.any((j) => !j.warm && j.shareable && !j.single);
    final busy = waiting.isNotEmpty || (shared && (_idle.isNotEmpty || auto));
    final every = waiting.isNotEmpty || (shared && _idle.isNotEmpty) ? const Duration(milliseconds: 5) : const Duration(milliseconds: 50);
    if (_tick != null && (!busy || every != _tickEvery)) {
      _tick!.cancel();
      _tick = null;
    }
    if (busy && _tick == null) {
      _tickEvery = every;
      _tick = Timer.periodic(every, (_) => _schedule());
    }
  }

  Duration _tickEvery = Duration.zero;

  /// The worker a request is given first: the warmest, then the one that has served most (so one client's
  /// requests keep to one worker, and the others' idle time runs on).
  static int _warmestFirst(_Worker a, _Worker b) => a.warmLeft != b.warmLeft ? a.warmLeft.compareTo(b.warmLeft) : b.served.compareTo(a.served);

  /// Nothing asks: the workers still to warm up do a round, all but the one a request would be given (the
  /// warmest), so a request never finds every worker in a round; a round is given up when requests come for
  /// more workers than are free ([_makeWay]). That last one does no round of its own.
  void _warmIdle() {
    if (active.isNotEmpty) return;
    final idle = _idle..sort(_warmestFirst);
    while (idle.length > 1) {
      final w = idle.removeLast();
      if (w.warmLeft > 0) unawaited(_warm(w).then((_) => _schedule()));
    }
    // The last one does no further round: a client could ask at any moment, and what it renders for the client
    // warms it as well (measured: a round met by a request cost that request 100 ms, and the requests after the
    // rounds were no faster than those of a worker that had done none).
    if (idle.length == 1 && idle.first.warmLeft > 0 && DateTime.now().difference(lastActivity) >= quietBeforeWarm &&
        !workers.any((w) => w.state == _WorkerState.busy && (w.job?.warm ?? false))) {
      idle.first.warmLeft = 0;
    }
  }

  /// A pool that follows its load: the autoscaler is told where the pool stands, and what it decides is done.
  void _follow() {
    var demand = waiting.length;
    for (final job in active) {
      if (!job.warm && job.shareable && !job.single && job.verdict == null) demand += job.unmet;
    }
    // (A worker in a warm-up round is free for a request: it gives the round up.)
    final free = _idle.length + workers.where((w) => w.state == _WorkerState.busy && (w.job?.warm ?? false) && !w.job!.keep).length;
    final memory = demand > 0 && free == 0 ? machineMemory() : null;
    final change = _scaler.tick(_scale, DateTime.now(), idle: free, starting: _starting, demand: demand, freeMb: memory?.freeMb);
    if (change != null) _applied(change);
  }

  /// What the autoscaler decided: said in the log, and workers started or ended to match.
  void _applied(AutoscaleChange change) {
    if (change.to == change.from) {
      log('Workers ${change.reason}.');
      return;
    }
    log('Workers ${change.from} -> ${change.to}: ${change.reason}.');
    if (change.to > change.from) {
      unawaited(_spawnRest());
      return;
    }
    // Fewer: those still starting first, then idle ones (the coldest first), then busy ones (each ends after
    // the request it is on).
    var over = _alive - change.to;
    final order = [
      ...workers.where((w) => w.state == _WorkerState.starting && !w.retiring),
      ...(_idle..sort(_warmestFirst)).reversed,
      ...workers.where((w) => w.state == _WorkerState.busy && !w.retiring && !w.leaving),
    ];
    for (final w in order) {
      if (over <= 0) break;
      over--;
      _retire(w);
    }
  }

  /// [w] is ended because the pool shrinks: now when it has nothing to do, else after the request it is on.
  void _retire(_Worker w) {
    w.retiring = true;
    if (w.state != _WorkerState.busy || (w.job?.warm ?? false)) {
      w.leaving = true;
      _kill(w);
    }
  }

  /// Requests wait and no worker is idle: workers are asked back, one for each waiting request. A helper first
  /// (its request keeps its leader); else a leader that has rendered for [quantum], when a waiting request has
  /// had less of the workers' time than its own.
  void _makeWay() {
    var need = waiting.length - workers.where((w) => w.state == _WorkerState.busy && w.asked).length;
    if (need <= 0) return;
    // A warm-up round first: a request never waits for one to end (the worker stops at its next capture).
    for (final w in workers) {
      if (need <= 0) return;
      if (w.state == _WorkerState.busy && !w.asked && w.job != null && w.job!.warm && !w.job!.keep) {
        _askYield(w);
        need--;
      }
    }
    final now = DateTime.now();
    final helpers = [for (final w in workers) if (w.state == _WorkerState.busy && w.role == 'help' && !w.asked) w];
    for (final w in helpers) {
      if (need <= 0) return;
      _askYield(w);
      need--;
    }
    final least = waiting.map((j) => j.service).reduce(min);
    final leaders = [
      for (final w in workers)
        if (w.state == _WorkerState.busy && w.role == 'lead' && !w.asked && !w.job!.warm && now.difference(w.since) >= quantum) w,
    ]..sort((a, b) => a.since.compareTo(b.since));
    for (final w in leaders) {
      if (need <= 0) return;
      if (least >= w.job!.service + now.difference(w.since).inMicroseconds) continue;
      _askYield(w);
      need--;
    }
  }

  void _askYield(_Worker w) {
    w.asked = true;
    w.job!.dir.askYield(w.id);
  }

  /// Idle workers help with the requests being rendered that have captures nobody took yet.
  /// A pool that follows its load also notes, for each such request, the captures no idle worker was there for
  /// ([_Job.unmet]: what more workers would take), and tells the autoscaler of the captures rendered meanwhile.
  void _help() {
    final idle = _idle..sort((a, b) => a.warmLeft.compareTo(b.warmLeft));
    if (idle.isEmpty && !auto) return;
    final now = DateTime.now();
    // (With no worker to send, the folders are looked at ten times a second, not two hundred.)
    if (idle.isEmpty && now.difference(_lookedForUnmet).inMilliseconds < 100) return;
    _lookedForUnmet = now;
    for (final job in active) {
      if (idle.isEmpty && !auto) return;
      if (job.warm || !job.shareable || job.single || job.leader == null || job.over || job.verdict != null) {
        job.unmet = 0;
        continue;
      }
      if (now.difference(job.lastHelper).inMilliseconds > 400) job.joining = 0;
      var open = 0, unprepared = 0, recorded = 0;
      for (var r = 0; r < job.runs; r++) {
        final at = job.dir.state(r);
        recorded += at.recorded;
        final known = at.total ?? at.estimate;
        if (known == null) {
          if (at.entered == 0) unprepared++;
        } else if (!at.solo) {
          open += max(0, known - at.claimed);
        }
      }
      if (auto && recorded > job.counted) {
        _scaler.progress(_scale, recorded - job.counted);
        job.counted = recorded;
      }
      // (One run nobody prepared is the leader's next; a helper is worth its own preparing from two captures.)
      var want = max(0, unprepared - 1) + open ~/ 2 - job.joining;
      while (want > 0 && idle.isNotEmpty) {
        final w = idle.removeAt(0);
        job.joining++;
        job.lastHelper = now;
        want--;
        unawaited(_assign(w, job, 'help'));
      }
      job.unmet = max(0, want);
    }
  }

  DateTime _lookedForUnmet = DateTime.fromMillisecondsSinceEpoch(0);

  /// Hands [job] to [w] and deals with its answer.
  Future<void> _assign(_Worker w, _Job job, String role) async {
    w
      ..state = _WorkerState.busy
      ..job = job
      ..role = role
      ..asked = false
      ..since = DateTime.now();
    if (role != 'help') {
      job.leader = w;
      job.firstStarted ??= DateTime.now();
      if (!job.warm) active.add(job);
    } else {
      job.helpers.add(w);
    }
    var answer = '';
    try {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, w.port, timeout: const Duration(seconds: 5));
      socket.setOption(SocketOption.tcpNoDelay, true);
      socket.write('${w.token} $role ${job.argsFile}\n');
      await socket.flush();
      answer = (await utf8.decoder.bind(socket).join()).trim();
      socket.destroy();
    } on Object {
      // Gone, or going: no answer.
    }
    _answered(w, job, role, answer);
  }

  void _answered(_Worker w, _Job job, String role, String answer) {
    final parts = answer.split(' ');
    final verdict = parts.first;
    final spent = DateTime.now().difference(w.since).inMicroseconds;
    job.service += spent;
    job.dir.clearYield(w.id);
    final lost = !const {'done', 'yield', 'left', 'retry'}.contains(verdict);
    if (!lost) {
      w.rss = parts.length > 1 ? int.tryParse(parts[1]) ?? w.rss : w.rss;
      final rendered = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
      if (!job.warm) {
        w.served++;
        w.captures += rendered;
        captures += rendered;
        job.rendered += rendered;
        // What it rendered for a request warmed it as a round of its own would.
        if (w.warmLeft > 0 && rendered > 0) w.warmLeft--;
      }
    }
    final bye = lost || parts.contains('bye');
    if (role == 'help') {
      job.helpers.remove(w);
      if (lost || verdict == 'retry') job.dir.release(w.id);
    } else {
      job.leader = null;
      if (job.warm) {
        // Nothing to tell anyone.
      } else if (job.over) {
        // Timed out meanwhile: answered already.
      } else if (verdict == 'done') {
        _finish(job, 'done');
      } else if (verdict == 'left') {
        // The request's files are gone: so is its client.
        _finish(job, 'done');
      } else if (verdict == 'yield') {
        job.parked++;
        waiting.add(job);
      } else if (verdict == 'retry') {
        job.dir.release(w.id);
        if (++job.retries > 4) {
          _finish(job, 'failed The render server\'s workers each had other files registered for fonts this run draws; '
              'it was tried on ${job.retries} of them. Render it without the server (tool/codelessly serve --stop).');
        } else {
          waiting.insert(0, job);
        }
      } else {
        job.dir.release(w.id);
        crashes++;
        if (++job.crashes >= 2) {
          _finish(job, 'failed The render server\'s worker stopped while it rendered this run, twice (${w.id} last; its output is in ${w.dir}.log). '
              'The workers were started again; render it without the server (tool/codelessly serve --stop) to see what it comes to.');
        } else {
          log('Request ${job.id}: worker ${w.id} stopped during it; given to another worker.');
          waiting.insert(0, job);
        }
      }
    }
    if (job.verdict != null && job.helpers.isEmpty && job.leader == null) _tell(job);
    w
      ..job = null
      ..asked = false;
    if (bye) {
      _gone(w, lost ? 'it did not answer' : 'it takes no more requests');
    } else {
      w
        ..state = _WorkerState.idle
        ..idleSince = DateTime.now();
      if (w.retiring) {
        // The pool shrank while it rendered: it ends here.
        w.leaving = true;
        _kill(w);
      } else if (!job.warm && (w.rss > recycleBytes || w.served >= recycleAfter)) {
        _recycle(w);
      }
    }
    _schedule();
  }

  /// [job] is over: its client is told once the workers that helped have left it (they read its files).
  void _finish(_Job job, String verdict) {
    job.verdict = verdict;
    job.timeout?.cancel();
    for (final h in job.helpers) {
      if (!h.asked) _askYield(h);
    }
  }

  void _tell(_Job job) {
    if (job.over) return;
    job.over = true;
    active.remove(job);
    final verdict = job.verdict!;
    // What it rendered that the autoscaler was not told of as it went (a request that captures nothing is one).
    if (auto && !job.warm && verdict == 'done') {
      final all = max(1, job.rendered);
      if (all > job.counted) _scaler.progress(_scale, all - job.counted);
      job.counted = all;
    }
    if (verdict == 'done') {
      served++;
      _latencies.add(DateTime.now().difference(job.arrived).inMilliseconds);
      if (_latencies.length > 2000) _latencies.removeRange(0, 1000);
    } else {
      failed++;
      log('Request ${job.id} (${job.argsFile}): $verdict');
    }
    lastActivity = DateTime.now();
    final client = job.client;
    if (client == null) {
      // A request left as a file is answered by its files alone: one that failed gets them here.
      if (verdict != 'done' && !job.warm) {
        try {
          File('${job.argsFile}.report').writeAsStringSync('${verdict.replaceFirst('failed ', '')}\n');
          File('${job.argsFile}.status').writeAsStringSync('2');
        } on FileSystemException {
          // Its folder is gone: so is who asked.
        }
      }
      return;
    }
    // (render.sh's form: `done`, or the connection closed without it, and it renders the usual way.)
    if (verdict == 'done' || job.v2) {
      _reply(client, verdict);
    } else {
      client.destroy();
    }
  }

  void _timedOut(_Job job) {
    if (job.over || job.verdict != null) return;
    final running = job.leader != null || job.helpers.isNotEmpty;
    waiting.remove(job);
    job.verdict = 'failed The render took longer than ${requestTimeout.inSeconds} s, the render server\'s limit for one request '
        '(tool/codelessly serve --request-timeout <seconds>)${running ? '; the workers that were on it were started again' : ', waiting for a worker'}.';
    // A worker still on it may hang: each is ended, and another started in its place.
    for (final w in [?job.leader, ...job.helpers]) {
      _kill(w);
    }
    job.helpers.clear();
    job.leader = null;
    _tell(job);
  }

  void _kill(_Worker w) {
    try {
      File('${w.dir}/stop').writeAsStringSync('');
    } on FileSystemException {
      // Its folder is gone.
    }
    w.process?.kill();
  }

  /// A worker past what it may hold is replaced: a new one is started, and it ends once it is idle.
  void _recycle(_Worker w) {
    if (w.leaving) return;
    w.leaving = true;
    recycled++;
    log('Worker ${w.id} is replaced by a fresh one (${w.rss ~/ (1024 * 1024)} MB after ${w.served} requests).');
    _kill(w);
  }

  void _gone(_Worker w, String why) {
    if (w.state == _WorkerState.gone) return;
    final was = w.state;
    w.state = _WorkerState.gone;
    _kill(w);
    if (_stopping) return;
    if (w.retiring) {
      // Ended because the pool shrank: none takes its place.
      log('Worker ${w.id} ended (${w.served} requests).');
      return;
    }
    if (!w.leaving) log('Worker ${w.id} is gone: $why.');
    if (was == _WorkerState.starting) _startFailed('${w.id}: $why');
    if (was != _WorkerState.starting || _ready) {
      restarts++;
      unawaited(_spawnRest());
    }
  }

  bool _gaveUp = false;

  int _servedWritten = -1;

  /// Requests left in the server's folder as files (`<id>.req`, holding the path of an arguments file: what
  /// render.sh writes where it cannot open a socket), the oldest first, while the queue has room for them.
  void _takeRequestFiles() {
    final List<File> requests;
    try {
      requests = [for (final f in Directory(dir).listSync().whereType<File>()) if (f.path.endsWith('.req')) f]..sort((a, b) => a.path.compareTo(b.path));
    } on FileSystemException {
      return;
    }
    for (final f in requests) {
      if (waiting.length >= maxQueue && (_idle.isEmpty || waiting.isNotEmpty)) return;
      final String argsFile;
      try {
        argsFile = f.readAsStringSync().trim();
        f.deleteSync();
      } on FileSystemException {
        continue; // Being written: the next look.
      }
      _enqueue(argsFile, null, v2: false);
    }
  }

  void _housekeeping() {
    if (_stopping) return;
    if (File('$dir/stop').existsSync()) {
      unawaited(_shutdown());
      return;
    }
    if (active.isEmpty && waiting.isEmpty && DateTime.now().difference(lastActivity) > idle) {
      log('Idle for ${idle.inSeconds} s: stopping.');
      unawaited(_shutdown());
      return;
    }
    _takeRequestFiles();
    final now = DateTime.now();
    if (auto) {
      // Workers beyond the least that have had nothing to do for retireAfter are ended, the coldest first; the one
      // a request would be given stays.
      final idle = _idle..sort(_warmestFirst);
      var alive = _alive;
      var ended = 0;
      for (final w in idle.skip(1).toList().reversed) {
        if (alive - ended <= policy.min) break;
        if (now.difference(w.idleSince) < policy.retireAfter) continue;
        ended++;
        _retire(w);
      }
      if (ended > 0) {
        final change = _scaler.retired(_scale, now, to: alive - ended);
        if (change != null) log('Workers ${change.from} -> ${change.to}: ${change.reason}.');
      }
      // (The autoscaler's ceiling and holds run out with the clock, not with an event.)
      if (waiting.isNotEmpty || active.isNotEmpty) _follow();
    }
    // (Workers still to warm up are looked at again once nobody has asked for a moment.)
    if (active.isEmpty && waiting.isEmpty && workers.any((w) => w.state == _WorkerState.idle && w.warmLeft > 0)) _schedule();
    if (served != _servedWritten) {
      try {
        File('$dir/served').writeAsStringSync('$served\n');
        _servedWritten = served;
      } on FileSystemException {
        // The folder is gone: stopping.
      }
    }
    if (workers.every((w) => w.state == _WorkerState.gone) && _ready) {
      log('No worker is left and none starts: stopping.');
      unawaited(_shutdown());
    }
  }

  Future<void> _shutdown() async {
    if (_stopping) return;
    _stopping = true;
    _tick?.cancel();
    for (final name in const ['port', 'ready']) {
      final f = File('$dir/$name');
      if (f.existsSync()) f.deleteSync();
    }
    await _listener?.close();
    for (final job in [...waiting, ...active]) {
      if (job.over) continue;
      job.verdict = 'failed The render server stopped.';
      _tell(job);
    }
    for (final w in workers) {
      if (w.state != _WorkerState.gone) _kill(w);
    }
    // The workers' processes end (their input closes with this process too).
    await Future.wait([
      for (final w in workers)
        if (w.process != null) w.process!.exitCode.timeout(const Duration(seconds: 3), onTimeout: () => -1),
    ]);
    log('Render server stopped.');
    await stdout.flush();
    if (!_stopped.isCompleted) _stopped.complete(0);
  }

  Map<String, Object?> status() {
    final sorted = [..._latencies]..sort();
    int? at(double share) => sorted.isEmpty ? null : sorted[min(sorted.length - 1, (sorted.length * share).floor())];
    final seconds = max(1, DateTime.now().difference(started).inSeconds);
    return {
      'pid': pid,
      'since': started.toIso8601String(),
      'how': _launch.how,
      'workers': [
        for (final w in workers)
          if (w.state != _WorkerState.gone)
            {
              'id': w.id,
              'pid': w.process?.pid,
              'state': w.state == _WorkerState.busy ? (w.job?.warm ?? false ? 'warming' : w.role == 'help' ? 'helping' : 'busy') : w.state.name,
              if (w.job != null && !w.job!.warm) 'request': w.job!.id,
              'requests': w.served,
              'captures': w.captures,
              'memoryMb': w.rss ~/ (1024 * 1024),
              if (w.warmLeft > 0) 'warmupsLeft': w.warmLeft,
            },
      ],
      'workerCount': workerCount,
      // How many requests at a time a client with many should send.
      'parallel': auto ? parallelHint(least: policy.min, most: policy.max) : workerCount,
      'scaling': {
        'mode': auto ? 'auto' : 'fixed',
        'min': auto ? policy.min : workerCount,
        'max': auto ? policy.max : workerCount,
        if (auto) ..._scale.toJson(DateTime.now()),
        if (!auto) 'limit': workerCount,
        if (auto) 'retireAfterSeconds': policy.retireAfter.inSeconds,
        if (auto) 'memoryReserveMb': policy.reserveMb,
        if (auto) 'freeMemoryMb': machineMemory()?.freeMb,
      },
      'busy': workers.where((w) => w.state == _WorkerState.busy && !(w.job?.warm ?? false)).length,
      'idle': workers.where((w) => w.state == _WorkerState.idle).length,
      'queued': waiting.length,
      'queueLimit': maxQueue,
      'rendering': active.length,
      'served': served,
      'failed': failed,
      'refusedBusy': busyRefused,
      'captures': captures,
      'medianMs': at(0.5),
      'p95Ms': at(0.95),
      'capturesPerSecond': double.parse((captures / seconds).toStringAsFixed(2)),
      'workerRestarts': restarts,
      'workerCrashes': crashes,
      'recycled': recycled,
      'recycleMb': recycleBytes ~/ (1024 * 1024),
      'requestTimeoutSeconds': requestTimeout.inSeconds,
    };
  }
}

/// How a worker is started: Flutter's headless engine on the compiled harness, or `flutter test`.
class _Launch {
  _Launch._(this.sdk, this.flutter, this.root, {this.tester, this.dill, this.assets, this.fontConfig});
  final String sdk, flutter, root;
  final String? tester, dill, assets, fontConfig;

  bool get direct => tester != null;
  String get how => direct ? 'workers run the compiled harness (flutter_tester)' : 'workers are started with flutter test';

  static String _exe(String path) => Platform.isWindows ? '$path.exe' : path;

  static Future<_Launch?> prepare(String sdk, String flutter, String serverDir, void Function(String) log) async {
    // The flutter command's SDK: bin/flutter is in it.
    var root = Platform.environment['FLUTTER_ROOT'] ?? '';
    final resolved = File(flutter).existsSync() ? File(flutter).resolveSymbolicLinksSync() : flutter;
    if (root.isEmpty || !File('$root/bin/cache/dart-sdk/version').existsSync()) root = File(resolved).parent.parent.path;
    root = Directory(root).absolute.path;
    final cache = '$root/bin/cache';
    final runtime = _exe('$cache/dart-sdk/bin/dartaotruntime');
    final frontend = '$cache/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot';
    final patched = '$cache/artifacts/engine/common/flutter_patched_sdk';
    String? tester;
    final engine = Directory('$cache/artifacts/engine');
    if (engine.existsSync()) {
      for (final d in engine.listSync().whereType<Directory>()) {
        final t = _exe('${d.path}/flutter_tester');
        if (File(t).existsSync()) tester = t;
      }
    }
    final unitAssets = Directory('$sdk/build/unit_test_assets');
    final wanted = Platform.environment['CODELESSLY_RENDER_WORKERS_START'] ?? '';
    if (wanted == 'flutter-test' || tester == null || !File(runtime).existsSync() || !File(frontend).existsSync() ||
        !Directory(patched).existsSync() || !unitAssets.existsSync()) {
      if (wanted != 'flutter-test') log('This Flutter has no flutter_tester, frontend server or test assets where they are looked for: workers start with flutter test.');
      return _Launch._(sdk, flutter, root);
    }
    final pool = Directory('$sdk/build/render_pool')..createSync(recursive: true);
    // The assets `flutter test` made for this package, a copy of this server's own in its folder (a `flutter test` in the
    // checkout writes them again).
    final assets = Directory('$serverDir/assets');
    if (assets.existsSync()) assets.deleteSync(recursive: true);
    _copy(unitAssets, assets);
    // The font configuration `flutter test` gives the engine (Linux reads it): Flutter's own fonts, not the system's.
    final fontConfig = File('$serverDir/fonts.conf')
      ..writeAsStringSync('<fontconfig>\n  <dir>$cache/artifacts</dir>\n  <cachedir>/var/cache/fontconfig</cachedir>\n</fontconfig>\n');
    final dill = File('${pool.path}/harness.dill');
    if (_stale(dill, sdk)) {
      log('Compiling the render harness (once per change of the SDK or the API)...');
      final clock = Stopwatch()..start();
      final tmp = '${dill.path}.$pid.tmp';
      final r = await Process.run(runtime, [
        frontend, '--sdk-root', '$patched/', '--target=flutter', '--no-print-incremental-dependencies',
        '-Ddart.vm.profile=false', '-Ddart.vm.product=false', '--enable-asserts', '--track-widget-creation',
        '--packages', '$sdk/.dart_tool/package_config.json', '--output-dill', tmp, '$sdk/tool/render/render_harness.dart',
      ], workingDirectory: sdk);
      if (r.exitCode != 0 || !File(tmp).existsSync() || File(tmp).lengthSync() == 0 || '${r.stdout}'.contains(RegExp(r'^[0-9a-f-]+ .* [1-9]\d*$', multiLine: true))) {
        log('The render harness did not compile:\n${'${r.stdout}\n${r.stderr}'.trim().split('\n').take(60).join('\n')}');
        if (File(tmp).existsSync()) File(tmp).deleteSync();
        return null;
      }
      log('Compiled in ${(clock.elapsedMilliseconds / 1000).toStringAsFixed(1)} s.');
      try {
        if (dill.existsSync()) dill.deleteSync();
        File(tmp).renameSync(dill.path);
      } on FileSystemException {
        // Another server of this checkout holds the older file (Windows): this one runs its own.
        return _Launch._(sdk, flutter, root, tester: tester, dill: tmp, assets: assets.path, fontConfig: fontConfig.path);
      }
    }
    return _Launch._(sdk, flutter, root, tester: tester, dill: dill.path, assets: assets.path, fontConfig: fontConfig.path);
  }

  static void _copy(Directory from, Directory to) {
    to.createSync(recursive: true);
    for (final e in from.listSync()) {
      final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (e is Directory) {
        _copy(e, Directory('${to.path}/$name'));
      } else if (e is File) {
        e.copySync('${to.path}/$name');
      }
    }
  }

  /// Whether the compiled harness is missing or older than something it is made of: the SDK's lib/ and
  /// tool/render/ and tool/notation/ (the harness reads its formula check), the API's lib/, the pubspecs, the
  /// packages, this Flutter.
  static bool _stale(File dill, String sdk) {
    if (!dill.existsSync()) return true;
    final since = dill.lastModifiedSync();
    bool newer(String path) {
      final s = FileStat.statSync(path);
      return s.type != FileSystemEntityType.notFound && s.modified.isAfter(since);
    }

    final api = _apiOf(sdk);
    for (final root in ['$sdk/lib', '$sdk/tool/render', '$sdk/tool/notation', if (api != null) '$api/lib']) {
      if (!Directory(root).existsSync()) continue;
      for (final e in Directory(root).listSync(recursive: true, followLinks: false)) {
        if (e is File && e.path.endsWith('.dart') && newer(e.path)) return true;
      }
    }
    for (final f in ['$sdk/pubspec.yaml', '$sdk/pubspec_overrides.yaml', '$sdk/pubspec.lock', '$sdk/.dart_tool/package_config.json', if (api != null) '$api/pubspec.yaml']) {
      if (newer(f)) return true;
    }
    return false;
  }

  /// The codelessly_api the SDK compiles against, from its package configuration.
  static String? _apiOf(String sdk) {
    try {
      final config = jsonDecode(File('$sdk/.dart_tool/package_config.json').readAsStringSync()) as Map;
      for (final p in config['packages'] as List) {
        if (p is Map && p['name'] == 'codelessly_api') {
          final uri = Uri.parse('${p['rootUri']}');
          final resolved = uri.isAbsolute ? uri : Uri.directory('$sdk/.dart_tool/').resolveUri(uri);
          return resolved.scheme == 'file' ? resolved.toFilePath().replaceAll(r'\', '/').replaceFirst(RegExp(r'/$'), '') : null;
        }
      }
    } on Object {
      // Not told.
    }
    return null;
  }

  Future<Process> start(String id, String workerDir, {required Duration idle}) {
    final environment = {
      'CODELESSLY_RENDER_SERVE': workerDir,
      'CODELESSLY_RENDER_IDLE': '${idle.inSeconds}',
      'CODELESSLY_RENDER_WORKER': id,
    };
    if (!direct) {
      // (On Windows the flutter command is a script: a shell runs it.)
      return Process.start(flutter, ['test', '--no-pub', 'tool/render/render_harness.dart'],
          workingDirectory: sdk, environment: environment, runInShell: Platform.isWindows);
    }
    // What `flutter test` passes the engine, and the environment it gives the test.
    // (Without its --enable-dart-profiling: nothing reads a profile of a worker, and sampling one costs a
    // twentieth of what the workers render.)
    return Process.start(tester!, [
      '--disable-vm-service', '--enable-checked-mode', '--verify-entry-points', '--enable-software-rendering',
      '--skia-deterministic-rendering', '--non-interactive', '--use-test-fonts',
      '--disable-asset-fonts', '--packages=$sdk/.dart_tool/package_config.json', '--flutter-assets-dir=$assets', dill!,
    ], workingDirectory: sdk, environment: {
      ...environment,
      'CODELESSLY_RENDER_WORKER_STDIN': '1',
      'FLUTTER_TEST': 'true',
      'FLUTTER_ROOT': root,
      'FONTCONFIG_FILE': fontConfig!,
      'UNIT_TEST_ASSETS': assets!,
      'APP_NAME': 'codelessly_sdk',
    });
  }
}

Future<int> poolMain(List<String> argv) async {
  final a = Args(argv, valued: {
    '--dir', '--flutter', '--workers', '--min-workers', '--max-workers', '--retire-after', '--idle', '--queue', '--request-timeout', '--recycle-mb',
    '--recycle-after',
  });
  final dir = a['--dir'], flutter = a['--flutter'];
  if (dir == null || flutter == null) throw const UsageError('render-pool is started by tool/render/serve.sh (tool/codelessly serve).');
  int number(String option, int otherwise, {int least = 1}) {
    final v = a[option];
    if (v == null) return otherwise;
    final n = int.tryParse(v);
    if (n == null || n < least) throw UsageError('$option takes a whole number, $least or more (given "$v").');
    return n;
  }

  // `--workers n` is that many; without it (or `auto`) the pool follows its load, within --min-workers and
  // --max-workers when given. (The machine's memory is read from the system itself, memory.dart: no process
  // is started to learn it.)
  final fixed = workersOption(a['--workers']);
  // Four to start with and to keep (a burst of a few clients finds them up), fewer when --max-workers says so.
  final most = a['--max-workers'] == null ? null : number('--max-workers', 1);
  final least = number('--min-workers', most != null && most < defaultMinWorkers ? most : defaultMinWorkers);
  if (fixed != null && (a['--min-workers'] != null || a['--max-workers'] != null)) {
    throw const UsageError('--min-workers and --max-workers bound --workers auto; --workers <n> is that many.');
  }
  if (most != null && most < least) throw UsageError('--max-workers ($most) is less than --min-workers ($least).');
  final pool = _Pool(
    dir: dir.replaceAll(r'\', '/'),
    flutter: flutter,
    fixedWorkers: fixed,
    policy: AutoscalePolicy(
      initial: least,
      min: least,
      max: most,
      retireAfter: Duration(seconds: number('--retire-after', const AutoscalePolicy().retireAfter.inSeconds)),
      reserveMb: fixed == null ? memoryReserveMb(readMemory()?.totalMb) : 1024,
    ),
    idle: Duration(seconds: number('--idle', 1800)),
    maxQueue: number('--queue', 256, least: 0),
    requestTimeout: Duration(seconds: number('--request-timeout', 1200)),
    recycleBytes: number('--recycle-mb', defaultRecycleMb, least: 64) * 1024 * 1024,
    recycleAfter: number('--recycle-after', 100000),
  );
  return pool.run();
}

/// Asks the render server of this checkout one thing ([what]: `status`, `stop`) and returns its answer, or null
/// when none is up.
Future<String?> askServer(String what, {Duration timeout = const Duration(seconds: 5)}) async {
  final server = renderServerDir;
  try {
    final at = File('$server/port').readAsStringSync().trim().split(' ');
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, int.parse(at[0]), timeout: timeout);
    socket.write('${at[1]} $what\n');
    await socket.flush();
    final answer = await utf8.decoder.bind(socket).join().timeout(timeout);
    socket.destroy();
    return answer.trim();
  } on Object {
    return null;
  }
}

/// How the number of workers is decided, for `serve --status`: the limit now, its bounds, what was learned and
/// the last decision with its reason.
String scalingLine(Map<String, Object?> g) {
  if (g['mode'] != 'auto') return 'Workers: ${g['limit'] ?? '?'}, fixed (--workers ${g['limit'] ?? 'n'}); --workers auto follows the load.';
  final last = (g['lastDecision'] as Map?)?.cast<String, Object?>();
  final ceiling = g['ceiling'] == null ? 'no learned ceiling' : 'learned ceiling ${g['ceiling']} (until ${'${g['ceilingUntil']}'.substring(11, 19)})';
  return 'Workers follow the load: limit ${g['limit']} now (least ${g['min']}, most ${g['max'] ?? 'not fixed'}), $ceiling, '
      'highest that held ${g['learned'] ?? '-'}; idle ones end after ${g['retireAfterSeconds']} s; '
      '${g['freeMemoryMb'] ?? '?'} MB of memory free (${g['memoryReserveMb']} MB kept free).\n'
      'Last scaling decision: ${last == null ? 'none yet' : '${'${last['at']}'.substring(11, 19)} ${last['from']} -> ${last['to']}: ${last['reason']}'}.';
}

/// `tool/codelessly serve --status`'s second part: the workers, the queue, what was served and how fast.
Future<int> poolStatusMain(List<String> argv) async {
  final answer = await askServer('status');
  if (answer == null || !answer.startsWith('{')) return 1;
  if (argv.contains('--json')) {
    stdout.writeln(answer);
    return 0;
  }
  final s = (jsonDecode(answer) as Map).cast<String, Object?>();
  final workers = (s['workers'] as List).cast<Map>();
  stdout.writeln('${workers.length} of ${s['workerCount']} workers up (${s['busy']} busy, ${s['idle']} idle); ${s['queued']} requests queued (limit ${s['queueLimit']}), ${s['rendering']} rendering.');
  stdout.writeln(scalingLine((s['scaling'] as Map?)?.cast<String, Object?>() ?? const {}));
  stdout.writeln('${s['served']} requests served (${s['captures']} captures), ${s['failed']} failed, ${s['refusedBusy']} refused as busy; '
      'latency median ${s['medianMs'] ?? '-'} ms, p95 ${s['p95Ms'] ?? '-'} ms; ${s['capturesPerSecond']} captures a second since it started.');
  stdout.writeln('Workers restarted ${s['workerRestarts']} times (${s['workerCrashes']} stopped during a request, ${s['recycled']} replaced by a fresh one: past ${s['recycleMb']} MB, or --recycle-after); ${s['how']}.');
  for (final w in workers) {
    stdout.writeln('  ${'${w['id']}'.padRight(5)} pid ${'${w['pid']}'.padRight(7)} ${'${w['state']}'.padRight(8)} ${'${w['requests']}'.padLeft(6)} requests ${'${w['captures']}'.padLeft(7)} captures '
        '${'${w['memoryMb']}'.padLeft(5)} MB${w['request'] == null ? '' : '  on request ${w['request']}'}${w['warmupsLeft'] == null ? '' : '  (warming up)'}');
  }
  return 0;
}
