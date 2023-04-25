## Codelessly SDK

This package provides the transformer API to complement the 
[codelessly_api](https://pub.dev/packages/codelessly_api) package.

## Features

This package is used to create active and passive transformers that convert `BaseNode`s
from the `codelessly_api` into Flutter widgets that can be published, previewed,
and interacted with in the Codelessly Editor.

## Usage

CodelesslySDK's key feature is **Cloud UI** which allows the users to update their app's UI 
over the air, without updating the app itself. To enable this feature, the SDK provides
a widget called `CodelesslyWidget`.

> To learn how to use the Codelessly Editor to publish layouts, check out our user guide
> [here](https://app.gitbook.com/o/rXXdMMDhFOAfV2g6j8A1/s/x4NeiXalJWaOaV6tsK5f/getting-started/3-minute-quick-start).

### CodelesslyWidget

CodelesslyWidget is a widget that renders the layout by utilizing the data of the canvas 
you publish from the editor. It takes in the following parameters:
1. `layoutID`: ID of the published canvas.
2. `isPreview`: Whether the layout is in preview or production mode. Preview mode is meant 
for debugging the layout and syncs with the changes made in the editor. Widgets in 
production mode do not sync and are only updated when explicitly published using the 
Publish button.
3. `config`: It takes an instance of `CodelesslyConfig` that holds the information required 
to fetch the canvas data from the server. `authToken` is required while other parameters 
are optional.

### Initializing SDK

Before you can use `CodelesslyWidget`, you need to initialize the SDK. To do that, simply 
call the `initializeSDK` method before you render any `CodelesslyWidget`. Ideally, call it in 
the `main` method.

```dart
void main() {
  Codelessly.initializeSDK();
  
  runApp(MyApp());
}
```

`initializeSDK` takes in several parameters to provide complete flexibility. For example, you 
can declare config in this method to make it the default configuration of all 
`CodelesslyWidget`s, unless overriden.

```dart
Codelessly.initializeSDK(
  config: const CodelesslyConfig(
    authToken: authToken,
  ),
);
```

Similarly, you can declare `data` and `functions` to make them globally accessible.

### Example

Here's an example of how you can embed a canvas in your app using CodelesslySDK:
```dart
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SDK.
  Codelessly.initializeSDK(
    config: const CodelesslyConfig(
      authToken: 'LDliZlRlTS5EOTAsUzsrR3VfK0coN2sqbDI9OkVMazN4YXUv',
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Codelessly SDK Example',
      debugShowCheckedModeBanner: false,
      home: SafeArea(
        child: CodelesslyWidget(
          layoutID: '0QsQaSzQ0A4RIzKKuN8Y',
        ),
      ),
    );
  }
}
```

## Extending the transformer API

Here is a minimal example of how to use this package to create a custom transformer
for the `MyNode` node:

Please read the code inside `BaseNode` and `AbstractNodeWidgetTransformer`
to better understand what each property does, and refer to the many
transformers under `codelessly_sdk/lib/src/transformers/node_transformers`
for additional examples.

```dart
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../../codelessly_sdk.dart';
class MyNodeTransformer extends NodeWidgetTransformer<MyNode> {
  const MyNodeTransformer();

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
globalActiveManager.registerTransformer('my_node', MyNodeTransformer());
globalPassiveManager.registerTransformer('my_node', MyNodeTransformer());
```

## Additional information

If you have any questions or run into any issues, you can file a support ticket through the Codelessly website or
contact the Codelessly team directly. We welcome contributions to this package and encourage you to submit any issues or
pull requests through the
GitHub repository.

You can contact us on our [Website](https://codelessly.com/) or join us on
our [Discord Server](https://discord.gg/Bzaz7zmY6q).