///
import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use anyDescriptor instead')
const Any$json = {
  '1': 'Any',
  '2': [
    {'1': 'type_url', '3': 1, '4': 1, '5': 9, '10': 'typeUrl'},
    {'1': 'value', '3': 2, '4': 1, '5': 12, '10': 'value'},
  ],
};

/// Descriptor for `Any`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List anyDescriptor = $convert.base64Decode(
    'CgNBbnkSGQoIdHlwZV91cmwYASABKAlSB3R5cGVVcmwSFAoFdmFsdWUYAiABKAxSBXZhbHVl');
