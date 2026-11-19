// A figure whose digits roll to their new values, each in its own column of
// 0 to 9 (as Robinhood's price does when the pointer moves along its line).
import 'package:flutter/widgets.dart';

class RollingText extends StatelessWidget {
  const RollingText(this.text, {super.key, required this.style, this.duration = const Duration(milliseconds: 250)});

  final String text;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final digit = TextPainter(text: TextSpan(text: '0', style: style), textDirection: TextDirection.ltr)..layout();
    final height = digit.height, width = digit.width;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < text.length; i++)
          if (int.tryParse(text[i]) case final value?)
            // Keyed from the right, so a digit keeps its column as the
            // figure grows a place.
            TweenAnimationBuilder<double>(
              key: ValueKey(text.length - i),
              tween: Tween(end: value.toDouble()),
              duration: duration,
              curve: Curves.easeOut,
              builder: (context, v, _) => ClipRect(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: height * 10,
                    maxHeight: height * 10,
                    child: Transform.translate(
                      offset: Offset(0, -v * height),
                      child: Column(
                        children: [
                          for (var d = 0; d < 10; d++)
                            SizedBox(height: height, child: Text('$d', style: style, textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Text(text[i], style: style),
      ],
    );
  }
}
