// A font icon's glyph, painted at its box's size.
import 'package:codelessly_api/codelessly_api.dart' show Json, readInt, readString;
import 'package:flutter/rendering.dart';

/// Paints an icon glyph (Material Icons, Material Symbols, Cupertino) to fill
/// its box.
class RenderIconGlyph extends RenderBox {
  Json _icon = const {};
  set icon(Json v) {
    if (identical(v, _icon)) return;
    _icon = v;
    _painter = null;
    markNeedsPaint();
  }

  Color? _color;
  set color(Color? v) {
    if (v == _color) return;
    _color = v;
    _painter = null;
    markNeedsPaint();
  }

  Size _designSize = Size.zero;
  set designSize(Size v) {
    if (v == _designSize) return;
    _designSize = v;
    _painter = null;
    markNeedsLayout();
  }

  TextPainter? _painter;

  @override
  bool get sizedByParent => true;

  /// As SDK 8.x's icon box: the size its fit box gives it, nothing of its
  /// own (so a row out of room can squeeze it).
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.smallest;

  static String? fontFamilyOf(Json icon) => readString(icon['fontFamily']) ??
      switch (readString(icon['source'])) {
        'cupertinoIcon' => 'CupertinoIcons',
        _ => 'MaterialIcons',
      };

  @override
  void paint(PaintingContext context, Offset offset) {
    final codepoint = readInt(_icon['codepoint']);
    if (codepoint == null || codepoint <= 0 || _icon['show'] == false) return;
    final painter = _painter ??= TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(codepoint),
        style: TextStyle(
          inherit: false,
          fontFamily: fontFamilyOf(_icon),
          package: readString(_icon['fontPackage']),
          fontSize: size.shortestSide,
          height: 1,
          color: _color ?? const Color(0xFF000000),
        ),
      ),
    )..layout();
    painter.paint(context.canvas, offset + Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2));
  }
}
