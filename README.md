## Codelessly SDK

This package provides the transformer API to complement the `codelessly_api`
package.

## Features

This package is used to create active and passive transformers that convert `BaseNode`s
from the `codelessly_api` into Flutter widgets that can be published, previewed,
and interacted with in the Codelessly Editor.

## Usage

// TODO

## Extending the transformer API

Here is a minimal example of how to use this package to create a custom transformer
for the `MyCoolNode` node:

Please read the code inside `BaseNode` and `AbstractNodeWidgetTransformer`
to better understand what each property does, and refer to the many
transformers under `codelessly_sdk/lib/src/transformers/node_transformers`
for additional examples.

```dart
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
class MyCoolNodeTransformer extends NodeWidgetTransformer<MyCoolNode> {
  const MyCoolNodeTransformer();

  @override
  Widget buildWidget(
      IconNode node,
      BuildContext context, [
        WidgetBuildSettings settings = const WidgetBuildSettings(),
      ]) {
    return Icon(
      Icons.flutter_dash,
      size: node.basicBoxLocal.shortestSide,
      color: Colors.blue,
    );
  }
}
```

To register a transformer:

```dart
globalActiveManager.registerTransformer('my_cool_node', MyCoolNodeTransformer());
globalPassiveManager.registerTransformer('my_cool_node', MyCoolNodeTransformer());
```

## Additional information

If you have any questions or run into any issues, you can file a support ticket through the Codelessly website or
contact the Codelessly team directly. We welcome contributions to this package and encourage you to submit any issues or
pull requests through the
GitHub repository.

You can contact us on our [Website](https://codelessly.com/) or join us on
our [Discord Server](https://discord.gg/Bzaz7zmY6q).