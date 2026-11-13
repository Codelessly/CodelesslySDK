// What a behavior shows for a value it is given or reads: a drag track's
// place, a flip card's side. Pure: [read] gives the value at a path (a
// variable), wherever values come from.
import 'package:codelessly_api/codelessly_api.dart' as api;

/// `${track}` for [track] drawn at [value] (NaN: empty) at [progress]
/// (its rest place when null).
Map<String, Object?> trackValues(api.DragTrack track, double value,
        {double? progress, bool dragging = false, bool fine = false, bool focused = false}) {
  final shown = progress ?? track.restProgressOf(value);
  return {
    'value': value.isNaN ? null : value,
    // An endless track reports where it is within one turn.
    'progress': track.unbounded ? shown - shown.floorToDouble() : shown,
    'dragging': dragging,
    'fine': fine,
    'focused': focused,
  };
}

/// The value [track] is drawn at: its bound value (`drag.track.value`),
/// else its variable's ([read]; null: there are no values to read), else
/// its default or start; NaN (empty) for a track that parks such a value
/// ([api.DragTrack.parkedProgress]).
double trackValueFrom(api.DragTrack track, Object? Function(String path)? read) {
  final Object? raw = track.value ?? (track.hasVariable && read != null ? read(track.variable.trim()) : null);
  final double? value = switch (raw) {
    final num n when n.isFinite => n.toDouble(),
    final String s => double.tryParse(s.trim()),
    _ => null,
  };
  if (value != null) return value;
  if (track.parkedProgress != null) return double.nan;
  return track.defaultValue ?? track.min;
}

/// Whether [flip] shows its back: its variable's value ([read]; null:
/// there are no values to read) when it has one, else `flipped` (bindable).
bool flipWantedFrom(api.FlipCard flip, Object? Function(String path)? read) {
  final name = flip.variable.trim();
  if (name.isEmpty || read == null) return flip.flipped;
  final v = read(name);
  if (v == null) return flip.flipped;
  if (v is bool) return v;
  return '$v'.trim().toLowerCase() == 'true';
}
