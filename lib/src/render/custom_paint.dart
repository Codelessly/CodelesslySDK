// A node's `customPaint` (Flutter's `CustomPaint` as data): one render
// object in the node's chain, around its content, that draws the
// `painter` list before the content and the `foregroundPainter` list after
// it, as Flutter's RenderCustomPaintLayer does.
//
// The draw list is compiled once per value: literals become numbers,
// colors and parsed paths up front, each expression a closure over the
// node's values ([ExpressionValues], the runtime's), with `size`, and a
// repeat's `item`, `index` and `count`, as names of its own. Each top-level
// op is recorded into a `ui.Picture` and replayed until a name it reads
// changes (watched through the node's values), the box changes size or an
// image it waits for arrives: nothing repaints on a clock.
//
// Ops with `hit` are hit regions: a pointer reaction of the node gets the
// region under the pointer, its point in view box coordinates and the
// repeat item it was drawn for ([customPaintEvent]).
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_api/core.dart' show Json, Node;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'contracts.dart';
import 'convert.dart';
import 'paint/image_fill.dart';
import 'paint/node_paint.dart' show RenderNodePaint;
import 'paint/path_paint.dart' show parseSvgPath, trimPath;
import 'recipe.dart';

/// Adds node [n]'s `customPaint` layer to [chain] (just outside its
/// content: its painter under the content, its foreground painter over it).
void customPaintLayers(NodeBuilder b, Node n, List<RenderBox> chain) {
  final paint = n.behaviors.customPaint;
  if (paint == null) return;
  final values = b.tree.bindings?.valuesFor(b.source, b.id, b.instance);
  chain.add(
    b.obtain<RenderCustomPaintLayer>('customPaint', RenderCustomPaintLayer.new)
      ..configure(paint, values is ExpressionValues ? values : null),
  );
}

/// [event] (a pointer trigger's, `{"result": {...}}`) with what node box
/// [box]'s custom paint has under the pointer added to its result:
/// `region` (the topmost hit region's id, else ""), `x`, `y` (in the box),
/// `viewX`, `viewY` (in its view box) and the `item` and `index` of the
/// repeat that drew the region. [event] itself when the node has none.
Json customPaintEvent(RenderBox box, Json event) {
  RenderObject? o = box;
  while (o is RenderObjectWithChildMixin<RenderBox> && o is! RenderCustomPaintLayer) {
    o = o.child;
  }
  if (o is! RenderCustomPaintLayer || !o.hasSize || !o.attached) return event;
  final result = event['result'];
  final r = result is Map ? result : const <String, Object?>{};
  final gx = r['globalX'], gy = r['globalY'];
  final local = gx is num && gy is num ? o.globalToLocal(Offset(gx.toDouble(), gy.toDouble())) : o.lastPointer;
  if (local == null) return event;
  return {
    ...event,
    'result': {...r, ...o.pointAt(local)},
  };
}

// --- reading values -----------------------------------------------------------------

double? _toNum(Object? v) => switch (v) {
  final num n when n.isFinite => n.toDouble(),
  final bool b => b ? 1 : 0,
  final String s => double.tryParse(s.trim()),
  _ => null,
};

bool? _toBool(Object? v) => switch (v) {
  final bool b => b,
  final num n => n != 0,
  final String s => switch (s.trim().toLowerCase()) {
    'true' => true,
    'false' || '' || 'null' => false,
    final t => num.tryParse(t)?.let((n) => n != 0),
  },
  null => false,
  _ => null,
};

String _toText(Object? v) => switch (v) {
  null => '',
  final String s => s,
  final double d when d == d.roundToDouble() && d.abs() < 1e15 => '${d.toInt()}',
  _ => '$v',
};

List<double>? _toNums(Object? v) {
  if (v is Map) {
    final x = _toNum(v['x'] ?? v['dx'] ?? v['left']), y = _toNum(v['y'] ?? v['dy'] ?? v['top']);
    final w = _toNum(v['width']), h = _toNum(v['height']);
    if (x == null || y == null) return null;
    return w != null && h != null ? [x, y, w, h] : [x, y];
  }
  if (v is num) return [v.toDouble()];
  if (v is! List) return null;
  final out = <double>[];
  for (final e in v) {
    final d = _toNum(e);
    if (d == null) return null;
    out.add(d);
  }
  return out;
}

Color? _toColor(Object? v) => switch (v) {
  final int i => Color(i),
  final String s => api.Color.fromJson(s.trim())?.flutter,
  _ => null,
};

/// A list a repeat goes through: a list, a map's values, or JSON text.
List<Object?>? _toList(Object? v) => switch (v) {
  final List<Object?> l => l,
  final Map<Object?, Object?> m => m.values.toList(),
  _ => null,
};

// --- compiled values ------------------------------------------------------------------

/// What a compiled op reads while it draws: the node's values and the
/// names a draw list gives (`size`, a repeat's item, index and count).
class _Scope {
  _Scope(this.values);
  final ExpressionValues? values;
  final Map<String, Object?> locals = {};

  /// The innermost repeat's item and index (a hit region reports them).
  Object? item;
  int? index;

  Object? eval(String source) {
    final v = values;
    if (v == null) return null;
    try {
      return v.evaluate(source, locals);
    } catch (_) {
      return null;
    }
  }
}

typedef _F<T> = T Function(_Scope s);

/// Compiles a draw list, collecting the names its expressions read.
class _Compiler {
  _Compiler(this.values);
  final ExpressionValues? values;
  Set<String> names = {};

  void _read(String source) {
    if (!source.contains(r'${')) return;
    final v = values;
    if (v != null) names.addAll(v.namesRead(source));
  }

  _F<double> number(api.Expr<double>? e, double fallback) {
    if (e == null) return (_) => fallback;
    final src = e.source;
    if (src == null) {
      final v = e.value!;
      return (_) => v;
    }
    _read(src);
    return (s) => _toNum(s.eval(src)) ?? fallback;
  }

  _F<double?> optionalNumber(api.Expr<double>? e) {
    if (e == null) return (_) => null;
    final src = e.source;
    if (src == null) {
      final v = e.value!;
      return (_) => v;
    }
    _read(src);
    return (s) => _toNum(s.eval(src));
  }

  _F<bool> boolean(api.Expr<bool>? e, bool fallback) {
    if (e == null) return (_) => fallback;
    final src = e.source;
    if (src == null) {
      final v = e.value!;
      return (_) => v;
    }
    _read(src);
    return (s) => _toBool(s.eval(src)) ?? fallback;
  }

  _F<String> text(String? t) {
    if (t == null) return (_) => '';
    if (!t.contains(r'${')) return (_) => t;
    _read(t);
    return (s) => _toText(s.eval(t));
  }

  /// A vector (each item may be an expression, or the whole one).
  _F<List<double>?> vec(api.Expr<api.Vec>? e) {
    if (e == null) return (_) => null;
    final src = e.source;
    if (src != null) {
      _read(src);
      return (s) => _toNums(s.eval(src));
    }
    final items = e.value!;
    if (items.every((i) => !i.isExpression)) {
      final v = [for (final i in items) i.value!];
      return (_) => v;
    }
    final fs = [for (final i in items) number(i, 0)];
    return (s) => [for (final f in fs) f(s)];
  }

  _F<Offset?> offset(api.Expr<api.Vec>? e) {
    final f = vec(e);
    return (s) => switch (f(s)) {
      [final x, final y] => Offset(x, y),
      _ => null,
    };
  }

  _F<Rect?> rect(api.Expr<api.Vec>? e) {
    final f = vec(e);
    return (s) => switch (f(s)) {
      [final l, final t, final w, final h] => Rect.fromLTWH(l, t, w, h),
      _ => null,
    };
  }

  _F<BorderRadius> radius(api.Expr<api.BorderRadius> e) {
    final src = e.source;
    if (src == null) {
      final r = e.value!.flutter;
      return (_) => r;
    }
    _read(src);
    return (s) {
      final v = s.eval(src);
      return api.BorderRadius.fromJson(v is String ? _toNum(v) : v).flutter;
    };
  }

  /// Points: `[[x, y], ...]` with `null` breaks.
  _F<List<Offset?>> points(api.Expr<List<api.Vec?>>? e) {
    if (e == null) return (_) => const [];
    final src = e.source;
    if (src != null) {
      _read(src);
      return (s) {
        final read = api.readPoints(s.eval(src)) ?? const [];
        return [
          for (final p in read) p == null ? null : Offset(p[0].value ?? 0, p[1].value ?? 0),
        ];
      };
    }
    final fs = [for (final p in e.value!) p == null ? null : offset(api.Expr(p))];
    return (s) => [for (final f in fs) f?.call(s)];
  }

  List<_PaintF> paints(List<api.Expr<api.DrawPaint>> list) => [for (final p in list) paint(p)];

  _PaintF paint(api.Expr<api.DrawPaint> e) {
    final src = e.source;
    if (src == null) return _compilePaint(e.value!);
    _read(src);
    return (s, bounds) {
      final v = s.eval(src);
      if (v is String || v is int) {
        final c = _toColor(v);
        return c == null ? null : _Ink(Paint()..color = c, true, const []);
      }
      final p = api.DrawPaint.fromJson(v);
      return p == null ? null : _compilePaint(p)(s, bounds);
    };
  }

  _PaintF _compilePaint(api.DrawPaint p) {
    final color = switch (p.color) {
      final api.Expr<api.Color> c when c.source != null => () {
          _read(c.source!);
          return (_Scope s) => _toColor(s.eval(c.source!)) ?? const Color(0xFF000000);
        }(),
      final c => () {
          final v = c.value!.flutter;
          return (_Scope _) => v;
        }(),
    };
    final width = number(p.strokeWidth, 0);
    final style = p.style == api.PaintingStyle.stroke ? PaintingStyle.stroke : PaintingStyle.fill;
    final cap = StrokeCap.values.byName(p.strokeCap.name);
    final join = StrokeJoin.values.byName(p.strokeJoin.name);
    final mode = blendMode(p.blendMode);
    final shader = p.shader;
    final dashes = p.dashPattern;
    return (s, bounds) {
      final out = shader != null ? RenderNodePaint.paintFor(shader, bounds) : Paint();
      if (shader == null) out.color = color(s);
      out
        ..style = style
        ..strokeWidth = math.max(0, width(s))
        ..strokeCap = cap
        ..strokeJoin = join
        ..strokeMiterLimit = p.strokeMiterLimit
        ..blendMode = mode
        ..isAntiAlias = p.isAntiAlias;
      return _Ink(out, p.scaleStroke, dashes);
    };
  }

  // --- ops -----------------------------------------------------------------------------

  List<_Op> ops(List<api.DrawOp> ops) => [for (final o in ops) ?op(o)];

  _Op? op(api.DrawOp o) {
    final when = boolean(o.when, true);
    final _Op? out = switch (o) {
      final api.PathOp p => _pathOp(p),
      final api.LineOp l => () {
          final a = offset(l.p1), b = offset(l.p2);
          return _ShapeOp(_shape(l), (s) {
            final p1 = a(s) ?? Offset.zero, p2 = b(s) ?? Offset.zero;
            return _Geometry.line(p1, p2);
          });
        }(),
      final api.RectOp r => () {
          final f = rect(r.rect);
          return _ShapeOp(_shape(r), (s) => f(s)?.let(_Geometry.rect));
        }(),
      final api.RRectOp r => () {
          final f = rect(r.rect), rad = radius(r.radius);
          return _ShapeOp(_shape(r), (s) => f(s)?.let((rect) => _Geometry.rrect(rad(s).toRRect(rect))));
        }(),
      final api.CircleOp c => () {
          final center = offset(c.c), r = number(c.radius, 0);
          return _ShapeOp(_shape(c), (s) => _Geometry.circle(center(s) ?? Offset.zero, math.max(0, r(s))));
        }(),
      final api.OvalOp ov => () {
          final f = rect(ov.rect);
          return _ShapeOp(_shape(ov), (s) => f(s)?.let(_Geometry.oval));
        }(),
      final api.ArcOp a => () {
          final f = rect(a.rect), start = number(a.startAngle, 0), sweep = number(a.sweepAngle, 0);
          return _ShapeOp(_shape(a), (s) => f(s)?.let((r) => _Geometry.arc(r, start(s), sweep(s), a.useCenter)));
        }(),
      final api.PointsOp pt => () {
          final f = points(pt.points);
          final mode = ui.PointMode.values.byName(pt.pointMode.name);
          return _ShapeOp(_shape(pt), (s) => _Geometry.points(mode, [for (final p in f(s)) ?p]));
        }(),
      final api.ParagraphOp t => _paragraphOp(t),
      final api.ImageOp i => () {
          final url = text(i.url), src = rect(i.src), dst = rect(i.dst);
          return _ImageOp(_shape(i), url, src, dst);
        }(),
      final api.GroupOp g => _groupOp(g),
      final api.RepeatOp r => _repeatOp(r),
      api.UnknownDrawOp() => null,
    };
    if (out == null || o.when == null) return out;
    return _When(when, out);
  }

  _ShapeInfo _shape(api.ShapeOp o) => _ShapeInfo(paints(o.paint), o.hit == null ? null : text(o.hit));

  _Op _pathOp(api.PathOp p) {
    final info = _shape(p);
    final start = number(p.trimStart, 0), end = number(p.trimEnd, 1);
    final fillType = p.fillType == api.PathFillType.evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
    _F<Path?> path;
    if (p.d != null) {
      final d = text(p.d);
      path = (s) => parseSvgPath(d(s))?.let((path) => Path()..addPath(path, Offset.zero));
    } else {
      final pts = points(p.points);
      final close = p.close;
      path = (s) {
        final out = Path();
        var open = false;
        for (final pt in pts(s)) {
          if (pt == null) {
            open = false;
            continue;
          }
          if (open) {
            out.lineTo(pt.dx, pt.dy);
          } else {
            out.moveTo(pt.dx, pt.dy);
            open = true;
          }
        }
        if (close) out.close();
        return out;
      };
    }
    return _ShapeOp(info, (s) {
      final source = path(s);
      if (source == null) return null;
      source.fillType = fillType;
      final a = start(s).clamp(0.0, 1.0), b = end(s).clamp(0.0, 1.0);
      final trimmed = a <= 0 && b >= 1 ? source : (trimPath(source, a, b)..fillType = fillType);
      return _Geometry.path(trimmed);
    });
  }

  _Op _paragraphOp(api.ParagraphOp t) {
    final info = _shape(t);
    final content = text(t.text);
    final at = offset(t.offset);
    final maxWidth = optionalNumber(t.maxWidth);
    final style = textStyle(t.style);
    final base = t.style.color == null && t.style.foreground == null ? style.copyWith(color: const Color(0xFF000000)) : style;
    final align = textAlign(t.textAlign);
    return _ParagraphOp(info, (s, bounds) {
      final painters = info.paints;
      var st = base;
      if (painters.isNotEmpty) {
        final ink = painters.first(s, bounds);
        if (ink != null) st = st.copyWith(color: null, foreground: ink.paint);
      }
      final painter = TextPainter(
        text: TextSpan(text: content(s), style: st),
        textAlign: align,
        textDirection: TextDirection.ltr,
        maxLines: t.maxLines,
      )..layout(maxWidth: maxWidth(s) ?? double.infinity);
      final size = painter.size;
      final anchor = t.anchor;
      final p = (at(s) ?? Offset.zero) - Offset((anchor.x + 1) / 2 * size.width, (anchor.y + 1) / 2 * size.height);
      return (painter, p);
    });
  }

  _Op _groupOp(api.GroupOp g) {
    final children = ops(g.ops);
    final translate = offset(g.translate);
    final scale = vec(g.scale);
    final rotate = optionalNumber(g.rotate);
    final transform = vec(g.transform);
    final clipRect = rect(g.clipRect);
    final clipRRect = g.clipRRect == null ? null : (rect(g.clipRRect!.rect), radius(g.clipRRect!.radius));
    final clipPath = g.clipPath == null ? null : text(g.clipPath);
    final opacity = number(g.opacity, 1);
    final mode = blendMode(g.blendMode);
    return _GroupOp(children, (p) {
      final s = p.scope;
      final o = opacity(s).clamp(0.0, 1.0);
      final layer = o < 1 || mode != BlendMode.srcOver;
      if (layer) {
        p.canvas.saveLayer(null, Paint()
          ..color = Color.fromRGBO(0, 0, 0, o)
          ..blendMode = mode);
      } else {
        p.canvas.save();
      }
      p.push();
      if (g.translate != null) {
        final t = translate(s);
        if (t != null) p.apply(Matrix4.translationValues(t.dx, t.dy, 0), () => p.canvas.translate(t.dx, t.dy));
      }
      if (g.scale != null) {
        final v = scale(s);
        if (v != null && v.isNotEmpty) {
          final sx = v[0], sy = v.length > 1 ? v[1] : v[0];
          p.apply(Matrix4.diagonal3Values(sx, sy, 1), () => p.canvas.scale(sx, sy));
        }
      }
      if (g.rotate != null) {
        final r = rotate(s);
        if (r != null) p.apply(Matrix4.rotationZ(r), () => p.canvas.rotate(r));
      }
      if (g.transform != null) {
        final m = transform(s);
        if (m != null && m.length == 16) {
          final matrix = Matrix4.fromList(m);
          p.apply(matrix, () => p.canvas.transform(matrix.storage));
        }
      }
      if (clipRect(s) case final Rect r) p.canvas.clipRect(r);
      if (clipRRect != null) {
        if (clipRRect.$1(s) case final Rect r) p.canvas.clipRRect(clipRRect.$2(s).toRRect(r));
      }
      if (clipPath != null) {
        if (parseSvgPath(clipPath(s)) case final Path path) p.canvas.clipPath(path);
      }
      for (final c in children) {
        c.draw(p);
      }
      p.pop();
      p.canvas.restore();
    });
  }

  _Op _repeatOp(api.RepeatOp r) {
    final children = ops(r.ops);
    final each = r.each;
    if (each != null) _read(each);
    final count = optionalNumber(r.count);
    return _RepeatOp(children, r.as, r.indexAs, (s) {
      if (each != null) return _toList(s.eval(each)) ?? const [];
      final n = count(s)?.floor() ?? 0;
      return List<Object?>.generate(math.max(0, math.min(n, 100000)), (i) => i);
    });
  }
}

// --- the compiled ops ------------------------------------------------------------------

/// A paint, ready: Flutter's [paint], whether its stroke scales with the
/// drawing, and its dashes.
class _Ink {
  const _Ink(this.paint, this.scaleStroke, this.dashes);
  final Paint paint;
  final bool scaleStroke;
  final List<double> dashes;
  bool get stroke => paint.style == PaintingStyle.stroke;
}

typedef _PaintF = _Ink? Function(_Scope s, Rect bounds);

class _ShapeInfo {
  const _ShapeInfo(this.paints, this.hit);
  final List<_PaintF> paints;
  final _F<String>? hit;
}

/// What a shape op draws, as the Canvas call that draws it, and as a path.
class _Geometry {
  _Geometry._(this.draw, this.toPath, this.bounds, {this.area = true});

  factory _Geometry.line(Offset a, Offset b) => _Geometry._(
    (c, p) => c.drawLine(a, b, p),
    () => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy),
    Rect.fromPoints(a, b),
    area: false,
  );
  factory _Geometry.rect(Rect r) => _Geometry._((c, p) => c.drawRect(r, p), () => Path()..addRect(r), r);
  factory _Geometry.rrect(RRect r) => _Geometry._((c, p) => c.drawRRect(r, p), () => Path()..addRRect(r), r.outerRect);
  factory _Geometry.circle(Offset c, double radius) =>
      _Geometry._((cv, p) => cv.drawCircle(c, radius, p), () => Path()..addOval(Rect.fromCircle(center: c, radius: radius)),
          Rect.fromCircle(center: c, radius: radius));
  factory _Geometry.oval(Rect r) => _Geometry._((c, p) => c.drawOval(r, p), () => Path()..addOval(r), r);
  factory _Geometry.arc(Rect r, double start, double sweep, bool useCenter) => _Geometry._(
    (c, p) => c.drawArc(r, start, sweep, useCenter, p),
    () {
      final path = Path();
      if (useCenter) {
        path
          ..moveTo(r.center.dx, r.center.dy)
          ..arcTo(r, start, sweep, false)
          ..close();
      } else {
        path.addArc(r, start, sweep);
      }
      return path;
    },
    r,
    area: useCenter,
  );
  factory _Geometry.points(ui.PointMode mode, List<Offset> points) => _Geometry._(
    (c, p) => c.drawPoints(mode, points, p),
    () {
      final path = Path();
      if (points.isEmpty) return path;
      if (mode == ui.PointMode.lines) {
        for (var i = 0; i + 1 < points.length; i += 2) {
          path
            ..moveTo(points[i].dx, points[i].dy)
            ..lineTo(points[i + 1].dx, points[i + 1].dy);
        }
      } else if (mode == ui.PointMode.polygon) {
        path.addPolygon(points, false);
      } else {
        for (final pt in points) {
          path.addOval(Rect.fromCircle(center: pt, radius: 0.5));
        }
      }
      return path;
    },
    points.isEmpty ? Rect.zero : _boundsOf(points),
    area: false,
  );
  factory _Geometry.path(Path path) => _Geometry._((c, p) => c.drawPath(path, p), () => path, path.getBounds());

  final void Function(Canvas c, Paint p) draw;
  final Path Function() toPath;
  final Rect bounds;

  /// Whether a fill covers something (a line, open arc or points don't).
  final bool area;

  static Rect _boundsOf(List<Offset> pts) {
    var l = pts.first.dx, t = pts.first.dy, r = l, b = t;
    for (final p in pts) {
      l = math.min(l, p.dx);
      t = math.min(t, p.dy);
      r = math.max(r, p.dx);
      b = math.max(b, p.dy);
    }
    return Rect.fromLTRB(l, t, r, b);
  }
}

abstract class _Op {
  void draw(_Painter p);
}

class _When implements _Op {
  _When(this.test, this.op);
  final _F<bool> test;
  final _Op op;
  @override
  void draw(_Painter p) {
    if (test(p.scope)) op.draw(p);
  }
}

class _ShapeOp implements _Op {
  _ShapeOp(this.info, this.geometry);
  final _ShapeInfo info;
  final _F<_Geometry?> geometry;

  @override
  void draw(_Painter p) {
    final g = geometry(p.scope);
    if (g == null) return;
    double tolerance = 0;
    var filled = false;
    for (final f in info.paints) {
      final ink = f(p.scope, g.bounds);
      if (ink == null) continue;
      p.drawShape(g, ink);
      if (ink.stroke) {
        tolerance = math.max(tolerance, ink.paint.strokeWidth * (ink.scaleStroke ? p.scale : 1) / 2);
      } else {
        filled = true;
      }
    }
    if (info.hit case final hit?) {
      p.addRegion(hit(p.scope), g.toPath(), filled: (filled || info.paints.isEmpty) && g.area, tolerance: tolerance);
    }
  }
}

class _ParagraphOp implements _Op {
  _ParagraphOp(this.info, this.layout);
  final _ShapeInfo info;
  final (TextPainter, Offset) Function(_Scope s, Rect bounds) layout;

  @override
  void draw(_Painter p) {
    final (painter, at) = layout(p.scope, p.view);
    painter.paint(p.canvas, at);
    if (info.hit case final hit?) {
      p.addRegion(hit(p.scope), Path()..addRect(at & painter.size), filled: true, tolerance: 0);
    }
    painter.dispose();
  }
}

class _ImageOp implements _Op {
  _ImageOp(this.info, this.url, this.src, this.dst);
  final _ShapeInfo info;
  final _F<String> url;
  final _F<Rect?> src, dst;

  @override
  void draw(_Painter p) {
    final u = url(p.scope).trim();
    final to = dst(p.scope) ?? p.view;
    if (info.hit case final hit?) p.addRegion(hit(p.scope), Path()..addRect(to), filled: true, tolerance: 0);
    if (u.isEmpty) return;
    p.urls.add(u);
    final loaded = p.images.imageFor(u);
    if (loaded == null) {
      p.incomplete = true;
      return;
    }
    final paint = info.paints.isEmpty ? Paint() : (info.paints.first(p.scope, to)?.paint ?? Paint());
    if (loaded.image case final ImageInfo info) {
      final image = info.image;
      final from = src(p.scope) ?? Offset.zero & Size(image.width.toDouble(), image.height.toDouble());
      p.canvas.drawImageRect(image, from, to, paint);
    } else if (loaded.picture case final picture?) {
      final size = picture.size;
      if (size.isEmpty) return;
      final from = src(p.scope) ?? Offset.zero & size;
      p.canvas
        ..save()
        ..clipRect(to)
        ..translate(to.left, to.top)
        ..scale(to.width / from.width, to.height / from.height)
        ..translate(-from.left, -from.top)
        ..drawPicture(picture.picture)
        ..restore();
    }
  }
}

class _GroupOp implements _Op {
  _GroupOp(this.children, this.run);
  final List<_Op> children;
  final void Function(_Painter p) run;
  @override
  void draw(_Painter p) => run(p);
}

class _RepeatOp implements _Op {
  _RepeatOp(this.children, this.as, this.indexAs, this.items);
  final List<_Op> children;
  final String as, indexAs;
  final List<Object?> Function(_Scope s) items;

  @override
  void draw(_Painter p) {
    final s = p.scope;
    final list = items(s);
    final locals = s.locals;
    final had = (locals[as], locals[indexAs], locals['count']);
    final hadKeys = (locals.containsKey(as), locals.containsKey(indexAs), locals.containsKey('count'));
    final outer = (s.item, s.index);
    locals['count'] = list.length;
    for (var i = 0; i < list.length; i++) {
      locals[as] = list[i];
      locals[indexAs] = i;
      s
        ..item = list[i]
        ..index = i;
      for (final c in children) {
        c.draw(p);
      }
    }
    void restore(String k, bool had, Object? v) => had ? locals[k] = v : locals.remove(k);
    restore(as, hadKeys.$1, had.$1);
    restore(indexAs, hadKeys.$2, had.$2);
    restore('count', hadKeys.$3, had.$3);
    s
      ..item = outer.$1
      ..index = outer.$2;
  }
}

// --- painting --------------------------------------------------------------------------

/// A hit region: where a shape was drawn, in the box's coordinates.
class _Region {
  _Region(this.id, this.path, this.filled, this.tolerance, this.item, this.index);
  final String id;
  final Path path;
  final bool filled;
  final double tolerance;
  final Object? item;
  final int? index;

  bool contains(Offset p) {
    if (filled && path.contains(p)) return true;
    final reach = math.max(tolerance, 8.0);
    if (!path.getBounds().inflate(reach).contains(p)) return false;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d <= m.length; d += 2) {
        final t = m.getTangentForOffset(d);
        if (t != null && (t.position - p).distance <= reach) return true;
      }
    }
    return false;
  }
}

/// Draws compiled ops on one canvas, keeping the transform from the ops'
/// coordinates to the box's (for hit regions and strokes that don't scale).
class _Painter {
  _Painter(this.canvas, this.scope, Matrix4 base, this.view, this.images) : _matrix = base.clone();

  final Canvas canvas;
  final _Scope scope;

  /// The view, in the ops' coordinates.
  final Rect view;
  final ImageClient images;
  Matrix4 _matrix;
  final List<Matrix4> _stack = [];
  final List<_Region> regions = [];
  final Set<String> urls = {};
  bool incomplete = false;

  /// How much the ops' units are scaled on the box (the mean of the axes).
  double get scale {
    final m = _matrix.storage;
    return math.sqrt((math.sqrt(m[0] * m[0] + m[1] * m[1]) * math.sqrt(m[4] * m[4] + m[5] * m[5])).abs());
  }

  void push() => _stack.add(_matrix.clone());
  void pop() => _matrix = _stack.removeLast();

  void apply(Matrix4 m, void Function() onCanvas) {
    _matrix = _matrix.multiplied(m);
    onCanvas();
  }

  void drawShape(_Geometry g, _Ink ink) {
    final paint = ink.paint;
    final dashed = ink.stroke && ink.dashes.isNotEmpty && ink.dashes.any((d) => d > 0);
    if (!ink.scaleStroke && ink.stroke) {
      // In the box's pixels: the outline mapped to the box, drawn there.
      final inverse = Matrix4.tryInvert(_matrix);
      if (inverse != null) {
        var path = g.toPath().transform(_matrix.storage);
        if (dashed) path = trimPath(path, 0, 1, ink.dashes);
        canvas
          ..save()
          ..transform(inverse.storage)
          ..drawPath(path, paint)
          ..restore();
        return;
      }
    }
    if (dashed) {
      canvas.drawPath(trimPath(g.toPath(), 0, 1, ink.dashes), paint);
    } else {
      g.draw(canvas, paint);
    }
  }

  void addRegion(String id, Path path, {required bool filled, required double tolerance}) =>
      regions.add(_Region(id, path.transform(_matrix.storage), filled, tolerance, scope.item, scope.index));
}

/// One top-level op of a list, and what it drew last.
class _Segment {
  _Segment(this.op, this.names);
  final _Op op;
  final Set<String> names;
  ui.Picture? picture;
  List<_Region> regions = const [];
  Set<String> urls = const {};
  bool incomplete = false;

  void clear() {
    picture?.dispose();
    picture = null;
  }
}

/// Paints a node's [api.CustomPaint] around its content.
class RenderCustomPaintLayer extends RenderProxyBox with ImageClient {
  api.CustomPaint? _paint;
  ExpressionValues? _values;
  List<_Segment> _painter = const [], _foreground = const [];
  final Map<String, Listenable> _watched = {};
  Size? _recordedSize;

  /// Times a top-level op was drawn into a picture again (tests, tools).
  int debugRecordCount = 0;

  /// Times the layer painted.
  int debugPaintCount = 0;

  /// The last pointer position hit tested in this box.
  Offset? lastPointer;

  /// Draws [paint], reading its expressions from [values] (null: only its
  /// literals draw).
  void configure(api.CustomPaint paint, ExpressionValues? values) {
    if (paint == _paint && values == _values) return;
    _paint = paint;
    _values = values;
    _unwatch();
    final compiler = _Compiler(values);
    List<_Segment> compile(List<api.DrawOp> ops) {
      final out = <_Segment>[];
      for (final o in ops) {
        compiler.names = {};
        final op = compiler.op(o);
        if (op != null) out.add(_Segment(op, compiler.names));
      }
      return out;
    }

    _clear();
    _painter = compile(paint.painter);
    _foreground = compile(paint.foregroundPainter);
    if (attached) _watch();
    markNeedsPaint();
  }

  void _clear() {
    for (final s in [..._painter, ..._foreground]) {
      s.clear();
    }
  }

  void _watch() {
    final values = _values;
    if (values == null) return;
    final names = {for (final s in [..._painter, ..._foreground]) ...s.names};
    for (final n in names) {
      final w = values.watch(n);
      if (w == null) continue;
      void changed() => _changed(n);
      _watched[n] = w;
      _listeners[n] = changed;
      w.addListener(changed);
    }
  }

  final Map<String, VoidCallback> _listeners = {};

  void _unwatch() {
    for (final e in _watched.entries) {
      e.value.removeListener(_listeners[e.key]!);
    }
    _watched.clear();
    _listeners.clear();
  }

  void _changed(String name) {
    var any = false;
    for (final s in [..._painter, ..._foreground]) {
      if (s.names.contains(name)) {
        s.clear();
        any = true;
      }
    }
    if (any) markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _watch();
    // What changed while it was away isn't known: draw afresh.
    _clear();
  }

  @override
  void detach() {
    _unwatch();
    super.detach();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  /// The view box's rect and the transform from it to the box.
  (Rect, Matrix4) _view() {
    final v = _paint?.viewBox;
    if (v == null) return (Offset.zero & size, Matrix4.identity());
    final view = Rect.fromLTWH(v[0], v[1], v[2], v[3]);
    final fit = BoxFit.values.byName(_paint!.fit.name);
    final fitted = applyBoxFit(fit, view.size, size);
    final dst = Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    final src = Alignment.center.inscribe(fitted.source, Offset.zero & view.size);
    final m = Matrix4.translationValues(dst.left, dst.top, 0)
      ..scaleByDouble(dst.width / src.width, dst.height / src.height, 1, 1)
      ..translateByDouble(-(view.left + src.left), -(view.top + src.top), 0, 1);
    return (view, m);
  }

  void _record(_Segment s, Rect view, Matrix4 m) {
    debugRecordCount++;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final viewBox = _paint?.viewBox;
    final scope = _Scope(_values);
    scope.locals['size'] = {'width': viewBox == null ? size.width : view.width, 'height': viewBox == null ? size.height : view.height};
    if (viewBox != null) {
      // The fit's crop: what falls outside the box isn't drawn (`cover`).
      canvas
        ..clipRect(Offset.zero & size)
        ..transform(m.storage);
    }
    final p = _Painter(canvas, scope, m, view, this);
    try {
      s.op.draw(p);
    } catch (e, st) {
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: st, library: 'codelessly customPaint'));
    }
    s.picture?.dispose();
    s.picture = recorder.endRecording();
    s.regions = p.regions;
    s.urls = p.urls;
    s.incomplete = p.incomplete;
  }

  void _paintList(PaintingContext context, Offset offset, List<_Segment> list) {
    if (list.isEmpty) return;
    final (view, m) = _view();
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    for (final s in list) {
      if (s.picture == null || s.incomplete) _record(s, view, m);
      canvas.drawPicture(s.picture!);
    }
    canvas.restore();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    debugPaintCount++;
    final paint = _paint;
    if (paint == null || !hasSize) return super.paint(context, offset);
    if (_recordedSize != size) {
      _clear();
      _recordedSize = size;
    }
    if (paint.isComplex) context.setIsComplexHint();
    if (paint.willChange) context.setWillChangeHint();
    _paintList(context, offset, _painter);
    super.paint(context, offset);
    _paintList(context, offset, _foreground);
    _showUrls();
  }

  /// The images the ops drew: loaded (or let go) after this paint.
  void _showUrls() {
    final urls = {for (final s in [..._painter, ..._foreground]) ...s.urls};
    if (setEquals(urls, _shown)) return;
    _shown = urls;
    scheduleMicrotask(() {
      if (!attached) return;
      showImages(_shown);
    });
  }

  Set<String> _shown = const {};

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    lastPointer = position;
    return super.hitTest(result, position: position);
  }

  /// The topmost hit region at [local] (in the box), or null.
  ({String id, Object? item, int? index})? regionAt(Offset local) {
    for (final list in [_foreground, _painter]) {
      for (final s in list.reversed) {
        for (final r in s.regions.reversed) {
          if (r.contains(local)) return (id: r.id, item: r.item, index: r.index);
        }
      }
    }
    return null;
  }

  /// What a pointer at [local] reports: the region, the point in the box
  /// and in the view box, and the region's repeat item and index.
  Json pointAt(Offset local) {
    final region = regionAt(local);
    final (_, m) = _view();
    final inverse = Matrix4.tryInvert(m);
    final view = inverse == null ? local : MatrixUtils.transformPoint(inverse, local);
    return {
      'region': region?.id ?? '',
      'x': local.dx,
      'y': local.dy,
      'viewX': view.dx,
      'viewY': view.dy,
      if (region != null && region.index != null) 'item': region.item,
      if (region != null && region.index != null) 'index': region.index,
    };
  }
}
