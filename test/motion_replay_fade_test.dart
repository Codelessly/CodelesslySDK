import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// An entrance may start from a value that is also the default: a dashed
/// trail that fades out each time a formation changes replays from
/// `enterFrom: {opacity: 1}` to rest at 0.
void main() {
  Widget at(String key) => Directionality(
        textDirection: TextDirection.ltr,
        child: NodeMotion(
          // As the editor stores it: JSON, where opacity 1 is the default.
          motion: MotionModel.fromJson({
            'opacity': 0,
            'enterFrom': {'opacity': 1},
            'durationMs': 1400,
            'curve': 'linear',
            'replayKey': key,
          }),
          child: const SizedBox(width: 10, height: 10),
        ),
      );

  double? opacity(WidgetTester tester) {
    final f = find.byType(Opacity);
    return f.evaluate().isEmpty ? null : tester.widget<Opacity>(f).opacity;
  }

  testWidgets('a fade-out entrance replays from full opacity when its key changes', (tester) async {
    await tester.pumpWidget(at('0'));
    await tester.pumpAndSettle();
    expect(opacity(tester), 0);
    await tester.pumpWidget(at('1'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(opacity(tester), closeTo(0.75, 0.02));
  });

  test('values named in enterFrom survive JSON even at their defaults', () {
    final MotionModel m = MotionModel.fromJson({'opacity': 0, 'enterFrom': {'opacity': 1, 'scale': 1}});
    expect(m.enterFrom!.named, {'opacity', 'scale'});
    expect(m.toJson()['enterFrom'], {'opacity': 1.0, 'scale': 1.0});
    expect(m.entranceStart.opacity, 1);
    // Built in code: withValue names the value too.
    final MotionModel coded = const MotionModel(opacity: 0).copyWith(enterFrom: MotionModel.none.withValue('opacity', 1));
    expect(coded.entranceStart.opacity, 1);
    // Unnamed defaults still keep the motion's own value.
    expect(MotionModel.fromJson({'rotate': 8, 'enterFrom': {'opacity': 0}}).entranceStart.rotate, 8);
  });
}
