// The machine's memory, read where the operating system keeps it: no process is started for it (the render
// server asks whenever it weighs another worker; a PowerShell start for the same number was a quarter of a second
// of every `serve`).
import 'dart:ffi';
import 'dart:io';

/// The machine's memory in megabytes, all of it and what is free for a new process; null when it cannot be told.
typedef MachineMemory = ({int totalMb, int freeMb});

MachineMemory? _last;
DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

/// [readMemory], read again at most every [every].
MachineMemory? machineMemory({Duration every = const Duration(milliseconds: 250)}) {
  final now = DateTime.now();
  if (now.difference(_lastAt) < every) return _last;
  _lastAt = now;
  return _last = readMemory();
}

MachineMemory? readMemory() {
  try {
    if (Platform.isWindows) return _windows();
    if (Platform.isLinux || Platform.isAndroid) return _linux(File('/proc/meminfo').readAsStringSync());
    if (Platform.isMacOS) return _mac();
  } on Object {
    // Not told here.
  }
  return null;
}

/// `/proc/meminfo`: MemTotal and MemAvailable (what a new process can have without swapping).
MachineMemory? _linux(String text) {
  int? kb(String name) {
    final m = RegExp('^$name:\\s+(\\d+) kB', multiLine: true).firstMatch(text);
    return m == null ? null : int.parse(m[1]!);
  }

  final total = kb('MemTotal'), free = kb('MemAvailable') ?? kb('MemFree');
  return total == null || free == null ? null : (totalMb: total ~/ 1024, freeMb: free ~/ 1024);
}

/// For tests: [_linux] of a `/proc/meminfo` text.
MachineMemory? memoryFromMeminfo(String text) => _linux(text);

/// `sysctl hw.memsize` and `vm_stat` (free, inactive and speculative pages).
MachineMemory? _mac() {
  final total = int.tryParse('${Process.runSync('sysctl', ['-n', 'hw.memsize']).stdout}'.trim());
  final stat = '${Process.runSync('vm_stat', const []).stdout}';
  final page = int.tryParse(RegExp(r'page size of (\d+) bytes').firstMatch(stat)?[1] ?? '') ?? 4096;
  var pages = 0;
  for (final name in const ['Pages free', 'Pages inactive', 'Pages speculative']) {
    pages += int.tryParse(RegExp('$name:\\s+(\\d+)').firstMatch(stat)?[1] ?? '') ?? 0;
  }
  return total == null ? null : (totalMb: total ~/ (1024 * 1024), freeMb: pages * page ~/ (1024 * 1024));
}

Pointer<Uint8>? _status;
int Function(Pointer<Uint8>)? _globalMemoryStatusEx;

/// kernel32's GlobalMemoryStatusEx: MEMORYSTATUSEX is 64 bytes, its length first, ullTotalPhys at 8 and
/// ullAvailPhys at 16.
MachineMemory? _windows() {
  if (_globalMemoryStatusEx == null) {
    final kernel = DynamicLibrary.open('kernel32.dll');
    final heap = kernel.lookupFunction<IntPtr Function(), int Function()>('GetProcessHeap')();
    final alloc = kernel.lookupFunction<Pointer<Uint8> Function(IntPtr, Uint32, IntPtr), Pointer<Uint8> Function(int, int, int)>('HeapAlloc');
    _status = alloc(heap, 8, 64);
    if (_status!.address == 0) return null;
    _globalMemoryStatusEx = kernel.lookupFunction<Int32 Function(Pointer<Uint8>), int Function(Pointer<Uint8>)>('GlobalMemoryStatusEx');
  }
  final p = _status!;
  p.cast<Uint32>().value = 64;
  if (_globalMemoryStatusEx!(p) == 0) return null;
  final total = Pointer<Uint64>.fromAddress(p.address + 8).value, free = Pointer<Uint64>.fromAddress(p.address + 16).value;
  return (totalMb: total ~/ (1024 * 1024), freeMb: free ~/ (1024 * 1024));
}
