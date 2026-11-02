import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final icon = CupertinoIcon(codepoint: 0xf442, name: 'heart');

  test('CDN URL uses the versioned lowercase hexadecimal codepoint', () {
    expect(
      cupertinoSvgUrl(icon),
      'https://icons.codelessly.com/cupertino/1.0.9/f442.svg',
    );
    expect(
      cupertinoSvgUrl(icon, baseUrl: 'https://icons.example.com/'),
      'https://icons.example.com/cupertino/1.0.9/f442.svg',
    );
    expect(
      cupertinoSvgUrl(
        CupertinoIcon(codepoint: 0, name: 'invalid'),
        baseUrl: 'https://icons.example.com',
      ),
      isNull,
    );
  });

  testWidgets('remote Cupertino icons preserve tint and size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            // Do not mount the picture; widget-test HTTP requests are blocked.
            final box = SvgIcon(
              icon: icon,
              color: Colors.blue,
              size: 30,
            ).build(context) as SizedBox;
            final picture = box.child! as SvgPicture;
            expect(box.width, 30);
            expect(box.height, 30);
            expect(
              (picture.bytesLoader as SvgNetworkLoader).url,
              '$cupertinoSvgBaseUrl/cupertino/1.0.9/f442.svg',
            );
            expect(
              picture.colorFilter,
              const ColorFilter.mode(Colors.blue, BlendMode.srcIn),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
}
