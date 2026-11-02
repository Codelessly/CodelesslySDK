import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filled Material icons resolve to hosted vector assets', () {
    expect(
      const MaterialIcon(
        codepoint: 0xe037,
        name: 'play_arrow',
        style: MaterialIconStyle.filled,
        version: 16,
      ).toSvgUrl(),
      'https://fonts.gstatic.com/s/i/materialicons/play_arrow/v16/24px.svg',
    );
  });

  test(
    'styled and Flutter-specific names do not require a Flutter icon map',
    () {
      expect(
        const MaterialIcon(
          codepoint: 0,
          name: '3d_rotation',
          style: MaterialIconStyle.sharp,
          version: 12,
        ).toSvgUrl(),
        'https://fonts.gstatic.com/s/i/materialiconssharp/3d_rotation/v12/24px.svg',
      );
    },
  );
}
