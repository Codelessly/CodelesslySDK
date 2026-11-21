// The render server: one address, several workers.
//
//   codelessly_cli render-pool --dir <build/.render-server> --flutter <flutter command> [--workers n] [--idle s]
//       [--queue n] [--request-timeout s] [--recycle-mb n] [--recycle-after n]
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
import 'common.dart';

/// What a worker may hold before it is replaced by a fresh one (when idle): the engine's memory grows with the
/// captures it has made, about a megabyte each.
const defaultRecycleMb = 1024;

/// How many workers the server starts when none is asked for: half the processors (the other half are the same
/// cores twice on most machines, and the agents asking need some), no more than half the machine's memory holds
/// at [defaultRecycleMb] each, and no more than [maxDefaultWorkers].
int defaultWorkers({int? processors, int? memoryMb}) {
  final cores = max(1, (processors ?? Platform.numberOfProcessors) ~/ 2);
  final memory = memoryMb ?? totalMemoryMb();
  final fits = memory == null ? 4 : max(1, (memory * 0.5 / defaultRecycleMb).floor());
  return min(min(cores, fits), maxDefaultWorkers);
}

const maxDefaultWorkers = 16;

/// The machine's memory in megabytes, or null when it cannot be told.
int? totalMemoryMb() {
  try {
    if (Platform.isLinux || Platform.isAndroid) {
      final m = RegExp(r'MemTotal:\s+(\d+) kB').firstMatch(File('/proc/meminfo').readAsStringSync());
      return m == null ? null : int.parse(m[1]!) ~/ 1024;
    }
    if (Platform.isMacOS) {
      final r = Process.runSync('sysctl', ['-n', 'hw.memsize']);
      final bytes = int.tryParse('${r.stdout}'.trim());
      return bytes == null ? null : bytes ~/ (1024 * 1024);
    }
    if (Platform.isWindows) {
      final r = Process.runSync('powershell', ['-NoProfile', '-NonInteractive', '-Command', '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory']);
      final bytes = int.tryParse('${r.stdout}'.trim());
      return bytes == null ? null : bytes ~/ (1024 * 1024);
    }
  } on Object {
    // Not told here.
  }
  return null;
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

  /// The warm-up renders it still has to do before its code runs as fast as it will.
  int warmLeft = 0;
  bool leaving = false;
}

class _Job {
  _Job(this.id, this.argsFile, this.client, {required this.v2, required this.runs, required this.shareable});
  final int id;
  final String argsFile;
  final Socket? client;
  final bool v2;

  /// How many runs it has (one, or one for each `--state`); whether other workers may help with it.
  final int runs;
  final bool shareable;
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
}

class _Pool {
  _Pool({
    required this.dir,
    required this.flutter,
    required this.workerCount,
    required this.idle,
    required this.maxQueue,
    required this.requestTimeout,
    required this.recycleBytes,
    required this.recycleAfter,
  });

  final String dir;
  final String flutter;
  final int workerCount;
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
    final launch = await _Launch.prepare(sdk, flutter, log);
    if (launch == null) return 2;
    _launch = launch;
    _warmSite = _writeWarmSite();
    _listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _listener!.listen(_accept, onError: (Object _) {});
    log('Render server: ${_launch.how}, $workerCount worker${workerCount == 1 ? '' : 's'}, port ${_listener!.port}.');
    // One worker first (the server takes requests as soon as it is up), then the others, a few at a time.
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
    unawaited(_spawnRest());
    Timer.periodic(const Duration(milliseconds: 250), (_) => _housekeeping());
    return _stopped.future;
  }

  final Completer<int> _stopped = Completer<int>();

  Future<void> _spawnRest() async {
    // (With `flutter test` one after another: each rewrites build/ as it starts.)
    final atOnce = _launch.direct ? 4 : 1;
    while (!_stopping && workers.where((w) => w.state != _WorkerState.gone).length < workerCount) {
      final missing = workerCount - workers.where((w) => w.state != _WorkerState.gone).length;
      await Future.wait([for (var i = 0; i < min(atOnce, missing); i++) _spawn()]);
    }
  }

  /// Starts a worker and waits until it takes requests. False when it did not start.
  Future<bool> _spawn() async {
    final w = _Worker('w${_nextWorker++}', '$dir/w${_nextWorker - 1}');
    workers.add(w);
    Directory(w.dir).createSync(recursive: true);
    try {
      w.process = await _launch.start(w.id, w.dir, idle: idle + const Duration(minutes: 10));
    } on Object catch (e) {
      log('Worker ${w.id} could not be started: $e');
      w.state = _WorkerState.gone;
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
    if (w.warmLeft > 0) await _warm(w);
    log('Worker ${w.id} up (pid ${w.process!.pid}).');
    _schedule();
    return w.state != _WorkerState.gone;
  }

  static const warmRounds = 6;

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

  Future<void> _warm(_Worker w) async {
    final out = '${w.dir}/warm';
    Directory(out).createSync(recursive: true);
    final argsFile = '$out/args';
    final fan = Directory('$argsFile.fan');
    if (fan.existsSync()) fan.deleteSync(recursive: true);
    File(argsFile).writeAsStringSync([_warmSite!, '--out', out, '--no-google-fonts', '--dump-layout'].map((a) => '$a\u0000').join());
    final job = _Job(-1, argsFile, null, v2: false, runs: 1, shareable: false)..warm = true;
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

  void _reply(Socket socket, String line) {
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

  _Job? _enqueue(String argsFile, Socket socket, {required bool v2}) {
    lastActivity = DateTime.now();
    if (_stopping) {
      _reply(socket, v2 ? 'failed The render server is stopping.' : 'stopping');
      return null;
    }
    if (waiting.length >= maxQueue) {
      busyRefused++;
      // (render.sh's form has no word for it: the connection closes, and it renders the usual way.)
      if (v2) {
        _reply(socket, 'busy ${waiting.length} $maxQueue');
      } else {
        socket.destroy();
      }
      return null;
    }
    var runs = 1, shareable = true;
    try {
      final args = File(argsFile).readAsStringSync().split('\u0000');
      runs = max(1, args.where((a) => a == '--state').length);
      shareable = !args.contains('--sheet');
    } on FileSystemException {
      _reply(socket, v2 ? 'failed The render server cannot read the request ($argsFile).' : 'failed');
      return null;
    }
    final job = _Job(_nextJob++, argsFile, socket, v2: v2, runs: runs, shareable: shareable);
    job.timeout = Timer(requestTimeout, () => _timedOut(job));
    waiting.add(job);
    _schedule();
    if (waiting.contains(job) && v2) _say(job, 'queued ${waiting.indexOf(job) + 1}');
    return job;
  }

  List<_Worker> get _idle => [for (final w in workers) if (w.state == _WorkerState.idle && !w.leaving) w];

  void _schedule() {
    if (_stopping) return;
    // Waiting requests first, the one that waited longest on the worker that is warmest.
    while (waiting.isNotEmpty) {
      final idle = _idle..sort((a, b) => a.warmLeft != b.warmLeft ? a.warmLeft.compareTo(b.warmLeft) : b.served.compareTo(a.served));
      if (idle.isEmpty) break;
      unawaited(_assign(idle.first, waiting.removeAt(0), 'lead'));
    }
    if (waiting.isNotEmpty) {
      _makeWay();
    } else {
      _help();
      // Nothing asks: the workers still to warm up do a round.
      for (final w in _idle) {
        if (w.warmLeft > 0 && active.isEmpty) unawaited(_warm(w).then((_) => _schedule()));
      }
    }
    final busy = waiting.isNotEmpty || (active.any((j) => !j.warm && j.shareable) && _idle.isNotEmpty);
    if (busy && _tick == null) {
      _tick = Timer.periodic(const Duration(milliseconds: 5), (_) => _schedule());
    } else if (!busy && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  /// Requests wait and no worker is idle: workers are asked back, one for each waiting request. A helper first
  /// (its request keeps its leader); else a leader that has rendered for [quantum], when a waiting request has
  /// had less of the workers' time than its own.
  void _makeWay() {
    var need = waiting.length - workers.where((w) => w.state == _WorkerState.busy && w.asked).length;
    if (need <= 0) return;
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
  void _help() {
    final idle = _idle..sort((a, b) => a.warmLeft.compareTo(b.warmLeft));
    if (idle.isEmpty) return;
    final now = DateTime.now();
    for (final job in active) {
      if (idle.isEmpty) return;
      if (job.warm || !job.shareable || job.leader == null || job.over || job.verdict != null) continue;
      if (now.difference(job.lastHelper).inMilliseconds > 400) job.joining = 0;
      var open = 0, unprepared = 0;
      for (var r = 0; r < job.runs; r++) {
        final at = job.dir.state(r);
        final known = at.total ?? at.estimate;
        if (known == null) {
          if (at.entered == 0) unprepared++;
        } else if (!at.solo) {
          open += max(0, known - at.claimed);
        }
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
    }
  }

  /// Hands [job] to [w] and deals with its answer.
  Future<void> _assign(_Worker w, _Job job, String role) async {
    w
      ..state = _WorkerState.busy
      ..job = job
      ..role = role
      ..asked = false
      ..since = DateTime.now();
    if (role == 'lead') {
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
      w.state = _WorkerState.idle;
      if (!job.warm && (w.rss > recycleBytes || w.served >= recycleAfter)) _recycle(w);
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
    if (client == null) return;
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
    if (!w.leaving) log('Worker ${w.id} is gone: $why.');
    if (was != _WorkerState.starting || _ready) {
      restarts++;
      // (A worker that never came up is not started over and over.)
      if (was == _WorkerState.starting && restarts > workerCount * 3 + 10) {
        log('Workers keep failing to start: no more are started.');
        return;
      }
      unawaited(_spawnRest());
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
    try {
      File('$dir/served').writeAsStringSync('$served\n');
    } on FileSystemException {
      // The folder is gone: stopping.
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

  static Future<_Launch?> prepare(String sdk, String flutter, void Function(String) log) async {
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
    // The assets `flutter test` made for this package, a copy of this server's own (a `flutter test` in the
    // checkout writes them again).
    final assets = Directory('${pool.path}/assets');
    if (assets.existsSync()) assets.deleteSync(recursive: true);
    _copy(unitAssets, assets);
    // The font configuration `flutter test` gives the engine (Linux reads it): Flutter's own fonts, not the system's.
    final fontConfig = File('${pool.path}/fonts.conf')
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
      if (dill.existsSync()) dill.deleteSync();
      File(tmp).renameSync(dill.path);
      log('Compiled in ${(clock.elapsedMilliseconds / 1000).toStringAsFixed(1)} s.');
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
    return Process.start(tester!, [
      '--disable-vm-service', '--enable-checked-mode', '--verify-entry-points', '--enable-software-rendering',
      '--skia-deterministic-rendering', '--enable-dart-profiling', '--non-interactive', '--use-test-fonts',
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
  final a = Args(argv, valued: {'--dir', '--flutter', '--workers', '--idle', '--queue', '--request-timeout', '--recycle-mb', '--recycle-after'});
  final dir = a['--dir'], flutter = a['--flutter'];
  if (dir == null || flutter == null) throw const UsageError('render-pool is started by tool/render/serve.sh (tool/codelessly serve).');
  int number(String option, int otherwise, {int least = 1}) {
    final v = a[option];
    if (v == null) return otherwise;
    final n = int.tryParse(v);
    if (n == null || n < least) throw UsageError('$option takes a whole number, $least or more (given "$v").');
    return n;
  }

  final pool = _Pool(
    dir: dir.replaceAll(r'\', '/'),
    flutter: flutter,
    workerCount: number('--workers', defaultWorkers()),
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
  final server = '${sdkRoot.path.replaceAll(r'\', '/')}/build/.render-server';
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
  stdout.writeln('${s['served']} requests served (${s['captures']} captures), ${s['failed']} failed, ${s['refusedBusy']} refused as busy; '
      'latency median ${s['medianMs'] ?? '-'} ms, p95 ${s['p95Ms'] ?? '-'} ms; ${s['capturesPerSecond']} captures a second since it started.');
  stdout.writeln('Workers restarted ${s['workerRestarts']} times (${s['workerCrashes']} stopped during a request, ${s['recycled']} replaced past ${s['recycleMb']} MB); ${s['how']}.');
  for (final w in workers) {
    stdout.writeln('  ${'${w['id']}'.padRight(5)} pid ${'${w['pid']}'.padRight(7)} ${'${w['state']}'.padRight(8)} ${'${w['requests']}'.padLeft(6)} requests ${'${w['captures']}'.padLeft(7)} captures '
        '${'${w['memoryMb']}'.padLeft(5)} MB${w['request'] == null ? '' : '  on request ${w['request']}'}${w['warmupsLeft'] == null ? '' : '  (warming up)'}');
  }
  return 0;
}
