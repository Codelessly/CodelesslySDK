// The few plain colors and icon glyphs the runtime's own chrome draws with
// (a barrier, a player's controls, a toast's close button): constants of
// the SDK's own, so no widget library's palette or icon set is needed.
import 'dart:ui' show Color;

/// Plain colors.
abstract final class ShellColors {
  static const Color transparent = Color(0x00000000);
  static const Color black = Color(0xFF000000);

  /// Black at 54%: a modal barrier.
  static const Color black54 = Color(0x8A000000);
  static const Color white = Color(0xFFFFFFFF);

  /// The outline of an embed's placeholder, and its tint.
  static const Color blue = Color(0xFF2196F3);
  static const Color blue50 = Color(0xFFE3F2FD);
}

/// Codepoints in the `MaterialIcons` font ([ShellGlyphs.font]), as
/// `materialIconCodepoints` names them.
abstract final class ShellGlyphs {
  static const String font = 'MaterialIcons';

  static const int arrowDownward = 0xe097;

  /// Mirrored in a right-to-left layout.
  static const int arrowForward = 0xe09b;
  static const int audiotrackOutlined = 0xeea6;
  static const int chatBubbleOutline = 0xe155;
  static const int close = 0xe16a;
  static const int errorOutline = 0xe238;
  static const int graphicEq = 0xe2e3;
  static const int languageRounded = 0xf83f;
  static const int mapOutlined = 0xf1ae;
  static const int movieOutlined = 0xf1f5;
  static const int pauseCircle = 0xe47d;
  static const int playArrow = 0xe4cb;
  static const int playCircle = 0xe4cc;
  static const int playCircleFill = 0xe4cd;
}
