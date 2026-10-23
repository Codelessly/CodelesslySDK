import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ScopedValues scope(String mode) => ScopedValues.preview(
    variables: {
      'networkMode': VariableData(
        id: 'n',
        name: 'networkMode',
        value: mode,
        type: VariableType.text,
      ),
    },
  );
  final DelayAction latency = DelayAction(
    milliseconds: 900,
    duration: r"${= networkMode == 'slow' ? 4000 : 900}",
  );

  test('a delay waits as long as its duration formula says', () {
    expect(FunctionsRepository.delayMilliseconds(latency, scope('slow')), 4000);
    expect(
      FunctionsRepository.delayMilliseconds(latency, scope('normal')),
      900,
    );
  });

  test('a delay without a usable formula waits its fixed time', () {
    expect(
      FunctionsRepository.delayMilliseconds(
        DelayAction(milliseconds: 300),
        scope('slow'),
      ),
      300,
    );
    expect(
      FunctionsRepository.delayMilliseconds(
        DelayAction(milliseconds: 300, duration: r'${missing}'),
        scope('slow'),
      ),
      300,
    );
  });
}
