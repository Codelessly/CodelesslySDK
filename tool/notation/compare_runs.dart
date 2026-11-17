// Compares two runs of tool/notation/expand_all.dart: which documents are
// the same to the byte, which differ, and whether a run said more or less
// about a file than the other.
//
//   dart run tool/notation/compare_runs.dart <run A> <run B> [--only <keys.txt>] [--show 5]
import 'dart:io';

void main(List<String> args) {
  Map<String, List<String>> read(String dir) => {
        for (final l in File('$dir/index.tsv').readAsLinesSync())
          if (l.isNotEmpty) '${l.split('\t')[0]}\t${l.split('\t')[1]}': l.split('\t'),
      };
  final a = read(args[0]), b = read(args[1]);
  String? opt(String name) => args.contains(name) ? args[args.indexOf(name) + 1] : null;
  final only = opt('--only') == null ? null : File(opt('--only')!).readAsLinesSync().map((l) => l.split('\t').last).toSet();
  final show = int.tryParse(opt('--show') ?? '') ?? 10;
  var same = 0, differ = 0, missing = 0, issuesDiffer = 0, shown = 0;
  final files = <String>{}, differing = <String>{};
  for (final e in a.entries) {
    final key = e.value[0];
    if (only != null && !only.contains(key)) continue;
    files.add(key);
    final other = b[e.key];
    if (other == null) {
      missing++;
      continue;
    }
    if (other[2] == e.value[2]) {
      same++;
    } else {
      differ++;
      differing.add(key);
      if (shown++ < show) stdout.writeln('DIFFERS ${e.value[1]} $key\n  ${args[0]}/${e.value[5]}.${e.value[1]}.json\n  ${args[1]}/${other[5]}.${e.value[1]}.json');
    }
    if (other[4] != e.value[4]) {
      issuesDiffer++;
      if (shown++ < show) stdout.writeln('ISSUES ${e.value[4]} -> ${other[4]} ${e.value[1]} $key (${args[1]}/${other[5]}.${e.value[1]}.issues.txt)');
    }
  }
  stdout.writeln('${files.length} files, ${same + differ} expansions: $same identical, $differ differ (${differing.length} files), $missing missing, $issuesDiffer with a different number of issues');
  if (differ > 0 || missing > 0 || issuesDiffer > 0) exitCode = 1;
}
