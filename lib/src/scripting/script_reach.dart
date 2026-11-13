// What a script run can reach by name, so a run is sent only that: the
// other scripts it calls and the variables they read or write.
import 'package:codelessly_api/core.dart' show ScriptDef;

/// What a run of a script can reach by name: the other scripts it calls
/// (`script.name(...)`, transitively) and the variables it and they read or
/// write (`vars.get("name")`, `vars.has`, `vars.set`). Null for either when
/// a script reaches it by a computed name (`vars.get(name)`, `vars.all()`,
/// `script[name]`, or `vars`/`script` passed around): the run then gets all
/// of them, as it always did.
///
/// A run is sent only these: a 2,304-cell board ticking 30 times a second
/// shouldn't ship every variable of the app, and every script's source, to
/// the engine each time.
class ScriptReach {
  const ScriptReach(this.scripts, this.variables);

  final Set<String>? scripts;
  final Set<String>? variables;

  static final Map<String, ({Set<String>? scripts, Set<String>? variables})> _bySource = {};

  /// [script]'s reach among [others] (the scripts it can call, by name).
  static ScriptReach of(ScriptDef script, Map<String, ScriptDef> others) {
    final seen = <String>{};
    final pending = [script.source];
    Set<String>? scripts = {}, variables = {};
    while (pending.isNotEmpty) {
      final u = usesOf(pending.removeLast());
      if (u.variables == null) {
        variables = null;
      } else {
        variables?.addAll(u.variables!);
      }
      if (u.scripts == null) {
        scripts = null;
        // Any script may run: the variables of all of them count.
        for (final o in others.values) {
          if (seen.add(o.name)) pending.add(o.source);
        }
        continue;
      }
      for (final name in u.scripts!) {
        scripts?.add(name);
        final o = others[name];
        if (o != null && seen.add(name)) pending.add(o.source);
      }
    }
    return ScriptReach(scripts, variables);
  }

  static final RegExp _comments = RegExp(r'/\*[\s\S]*?\*/|//[^\n]*');
  static final RegExp _strings = RegExp(r"""'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*"|`(?:[^`\\]|\\.)*`""");
  static final RegExp _word = RegExp(r'(?<![\w$.])(vars|script)(?![\w$])');
  static final RegExp _varUse =
      RegExp(r"""vars\s*\.\s*(?:get|has|set)\s*\(\s*(?:'([^'\\]*)'|"([^"\\]*)"|`([^`\\$]*)`)\s*[,)]""");
  static final RegExp _scriptUse = RegExp(r'script\s*\.\s*([A-Za-z_$][\w$]*)');

  /// The names [source] uses literally; null for a kind it reaches by a
  /// computed name.
  static ({Set<String>? scripts, Set<String>? variables}) usesOf(String source) {
    final cached = _bySource[source];
    if (cached != null) return cached;
    // Comments become spaces and string contents x's, so the masked text
    // lines up with the source: a word found in it is code.
    String blank(Match m) => ' ' * m[0]!.length;
    final noComments = source.replaceAllMapped(_comments, blank);
    final masked = noComments.replaceAllMapped(_strings, (m) {
      final t = m[0]!;
      return t[0] + 'x' * (t.length - 2) + t[t.length - 1];
    });
    Set<String>? scripts = {}, variables = {};
    for (final m in _word.allMatches(masked)) {
      if (m[1] == 'vars') {
        final use = _varUse.matchAsPrefix(noComments, m.start);
        if (use == null) {
          variables = null;
        } else {
          variables?.add(use[1] ?? use[2] ?? use[3]!);
        }
      } else {
        final use = _scriptUse.matchAsPrefix(masked, m.start);
        if (use == null) {
          scripts = null;
        } else {
          scripts?.add(use[1]!);
        }
      }
    }
    if (_bySource.length > 512) _bySource.clear();
    return _bySource[source] = (scripts: scripts, variables: variables);
  }
}
