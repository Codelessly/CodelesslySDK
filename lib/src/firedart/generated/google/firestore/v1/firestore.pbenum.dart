///
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class TargetChange_TargetChangeType extends $pb.ProtobufEnum {
  static const TargetChange_TargetChangeType NO_CHANGE =
      TargetChange_TargetChangeType._(
          0,
          $core.bool.fromEnvironment('protobuf.omit_enum_names')
              ? ''
              : 'NO_CHANGE');
  static const TargetChange_TargetChangeType ADD =
      TargetChange_TargetChangeType._(1,
          $core.bool.fromEnvironment('protobuf.omit_enum_names') ? '' : 'ADD');
  static const TargetChange_TargetChangeType REMOVE =
      TargetChange_TargetChangeType._(
          2,
          $core.bool.fromEnvironment('protobuf.omit_enum_names')
              ? ''
              : 'REMOVE');
  static const TargetChange_TargetChangeType CURRENT =
      TargetChange_TargetChangeType._(
          3,
          $core.bool.fromEnvironment('protobuf.omit_enum_names')
              ? ''
              : 'CURRENT');
  static const TargetChange_TargetChangeType RESET =
      TargetChange_TargetChangeType._(
          4,
          $core.bool.fromEnvironment('protobuf.omit_enum_names')
              ? ''
              : 'RESET');

  static const $core.List<TargetChange_TargetChangeType> values =
      <TargetChange_TargetChangeType>[
    NO_CHANGE,
    ADD,
    REMOVE,
    CURRENT,
    RESET,
  ];

  static final $core.Map<$core.int, TargetChange_TargetChangeType> _byValue =
      $pb.ProtobufEnum.initByValue(values);

  static TargetChange_TargetChangeType? valueOf($core.int value) =>
      _byValue[value];

  const TargetChange_TargetChangeType._($core.int v, $core.String n)
      : super(v, n);
}
