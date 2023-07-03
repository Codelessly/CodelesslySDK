![Codelessly Logo](packages/Codelessly-Logo-Text.png)
# Codelessly CloudUI™ SDK
[![Pub release](https://img.shields.io/pub/v/codelessly_sdk.svg?style=flat-square)](https://pub.dev/packages/codelessly_sdk) [![GitHub Release Date](https://img.shields.io/github/release-date/Codelessly/CodelesslySDK.svg?style=flat-square)](https://github.com/Codelessly/CodelesslySDK) [![GitHub issues](https://img.shields.io/github/issues/Codelessly/CodelesslySDK.svg?style=flat-square)](https://github.com/Codelessly/CodelesslySDK/issues) [![GitHub top language](https://img.shields.io/github/languages/top/Codelessly/CodelesslySDK.svg?style=flat-square)](https://github.com/Codelessly/CodelesslySDK)

![Codelessly Publish UI](packages/Codelessly-Cover.png)

> ### Dynamic UI and real-time updates for Flutter apps

Supercharge your Flutter apps with dynamic UI and real-time updates. Build and publish UI without code!

- **Real-Time UI Updates:** Adjust your UI as often as you need, all in real-time. Adapt to trends, feedback, and business needs on the fly.
- **Intuitive UI Editor:** Easily create and update UI with our user-friendly Codelessly Editor.
- **Empower Non-Technical Team Members:** Enable anyone on your team to build UI without learning how to code.

## Quickstart
[![Pub release](https://img.shields.io/pub/v/codelessly_sdk.svg?style=flat-square)](https://pub.dev/packages/codelessly_sdk)

Import this library into your project:
```yaml
codelessly_sdk: ^latest_version
```
**Initialize the SDK**

```dart
Codelessly.instance.initialize(
  config: const CodelesslyConfig(
    authToken: authToken,
  ),
);
```

Find the `authToken` in your Codelessly Project under `Publish > Settings > Settings`.



The Codelessly SDK's key feature is **Cloud UI** which allows the users to update their app's UI over the air, without updating the app itself. To enable this feature, the SDK provides a widget called `CodelesslyWidget`.

```dart
import 'package:codelessly_sdk/codelessly_sdk.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Codelessly SDK Example',
      home: CodelesslyWidget(
        layoutID: 'YOUR LAYOUT ID HERE',
        config: const CodelesslyConfig(
          authToken: 'YOUR AUTH TOKEN HERE',
        ),
      ),
    );
  }
}
```

> To learn how to use the Codelessly editor to publish layouts, check out our user guide [here](https://app.gitbook.com/o/rXXdMMDhFOAfV2g6j8A1/s/x4NeiXalJWaOaV6tsK5f/getting-started/3-minute-quick-start).

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

## Features
* 💾 Built-in Caching: Experience instantaneous UI rendering on subsequent loads.
* 🔄 UI Preloading: Efficiently provision your published Codelessly Cloud UI, avoiding loading phases.
* ⚡ Live Updates: Enjoy real-time UI updates as you re-publish changes from your Codelessly editor that get reflected immediately to your users without any app updates.
* 📐 Responsive Rendering: Ensure consistent UI appearances across any widget tree.
* 🌟 Dynamic Data Injection: Widgets with variables update and react immediately to any data provided to the CodelesslyWidget dynamically during runtime.
* ⚙️ Function Support: Create your own functions that execute custom logic, triggering whenever they are configured to run from your Codelessly editor.
* 🎛️ Controller-Pattern Support: Leverage the full potential of Flutter's controller-pattern for advanced control over your UI.
* 🌍 Cross-Platform Compatibility: Ensures maximum accessibility with support for all platforms.
* 🎨 Customizable Placeholders: Personalize loading and error placeholders for a unique and consistent user experience.

## Demo
### [CodelesslyGPT](https://sdk-chat-bot.web.app/#/)
A demo chatbot interface built with the Codelessly SDK. [View Code](https://github.com/Codelessly/CodelesslySDK/tree/main/example_chat_bot)

## Customization

### The CodelesslyWidget

The CodelesslyWidget is a widget that renders a layout by accessing its associated canvas that you publish from the Codelessly editor. It takes the following parameters:

* `layoutID`: The ID of the published canvas. You can retrieve this from the Codelessly editor’s published layouts menu.
* `isPreview`: Whether the layout is in preview or production mode. Preview mode is meant for debugging the layout and syncs with the changes made in the editor. Widgets in production mode do not sync and are only updated when explicitly published using the Publish button.
* `config`: An optional `CodelesslyConfig` that holds the information required to authenticate your layout from the server. `authToken` is required while other parameters are optional. You can retrieve this from the Codelessly editor’s publish settings menu.

> The `config` parameter may be required depending on how you configure your CodelesslyWidget. Please read below for more information.

### Initializing the SDK
There are multiple methods to initialize your `CodelesslyWidget`.

#### Method #1: Lazy Initialization using the CodelesslyWidget
The simplest method is to directly use the `CodelesslyWidget` and allow it to initialize itself automatically when it comes into view in your widget tree. If you use this method, you **must** provide the `authToken` in a `CodelesslyConfig` in the `config` constructor parameter of the `CodelesslyWidget`.

```dart
import 'package:codelessly_sdk/codelessly_sdk.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Codelessly SDK Example',
      home: CodelesslyWidget(
        layoutID: 'YOUR LAYOUT ID HERE',
        config: const CodelesslyConfig(
          authToken: 'YOUR AUTH TOKEN HERE',
        ),
      ),
    );
  }
}
```

The global `Codelessly` instance will be configured for you automatically using this method. The first time you load data, you may see an empty loading state while the SDK attempts to download all the necessary information; subsequent attempts will be instantaneous as the caching system kicks in.

> Subsequent attempts should be instantaneous as the caching system kicks in.

#### Method #2: Preemptive Initialization using the Codelessly global instance

To initialize the SDK before rendering any `CodelesslyWidget`, perform the initialization through the global `Codelessly` instance.. To do this, you must initialize the SDK through the global `Codelessly` instance. To do this, simply call the `Codelessly.initializeSDK` method before you render any `CodelesslyWidget`. Ideally, call it in the `main` method.

```dart
import 'package:codelessly_sdk/codelessly_sdk.dart';

void main() async {
  await Codelessly.initializeSDK(
    config: const CodelesslyConfig(
      authToken:'YOUR AUTH TOKEN HERE',
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
      home: CodelesslyWidget(
        layoutID: 'YOUR LAYOUT ID HERE',
      ),
    );
  }
}
```

`initializeSDK` takes in several parameters to provide more  flexibility and control. For example, you can declare your `CodelesslyConfig` in this method to make it the default configuration of all `CodelesslyWidget`s, unless explicitly overridden.

### CodelesslyConfig

The CodelesslyConfig provides you with additional configuration capabilities to the SDK.

* `isPreview`: Globally enable or disable preview-mode from the SDK.
* `preload`: Determines if the SDK should preload all of the published layouts of a given Codelessly project. This allows you to provision your entire project ahead of time instead of lazily as `CodelesslyWidget`s render into view and individually download their data.
* `automaticallyCollectCrashReports`: By default, any crashes or errors are sent to Codelessly’s servers for analysis. You can optionally disable this behavior.

### Data & Functions

You can provide custom data and functions dynamically to your layout. The UI will dynamically replace any variables defined in the Codelessly editor with the appropriate provided value. Similarly, any function names defined in the editor will be executed through a map of the function’s name and a value of `CodelesslyFunction`.

```dart
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Codelessly SDK Example',
      home: CodelesslyWidget(
        layoutID: 'YOUR LAYOUT ID HERE',
        data: {
          'name': 'John Doe',
          'age': 25,
        },
        functions: {
          'myFunction': CodelesslyFunction((CodelesslyContext context) {
            // TODO: Implement your function here
          }),
        },
      ),
    );
  }
}
```

> Similarly, you can declare `data` and `functions` in the global `Codelessly` instance to make them globally accessible by all `CodelesslyWidget`s.

## Custom Transformers
Here is a minimal example of how to use this package to create a custom transformer
for the `MyNode` node:

Please read the code inside `BaseNode` and `AbstractNodeWidgetTransformer`
to better understand what each property does, and refer to any of the
transformers under `codelessly_sdk/lib/src/transformers/node_transformers`
for additional examples.

```dart
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';

class MyNodeTransformer extends NodeWidgetTransformer<MyNode> {
  const MyNodeTransformer();

  @override
  Widget buildWidget(
      MyNode node,
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
transformerManager.registerTransformer('my_node', MyNodeTransformer());
```
## Additional Resources
Visit [LINK](https://example.com) to read our complete and exhaustive documentation of this package.

If you have any questions or run into any issues, you can file a support ticket through the Codelessly website or contact the Codelessly team directly. We welcome contributions to this package and encourage you to submit any issues or pull requests through the GitHub repository.

You can contact us on our [Website](https://codelessly.com/) or join us on
our [Discord Server](https://discord.gg/Bzaz7zmY6q).

## Authors ❤️
* [Ray Li](https://github.com/searchy2)
* [Saad Ardati](https://github.com/SaadArdati)
* [Birju Vachhani](https://github.com/BirjuVachhani)
* [Aachman Garg](https://github.com/imaachman)
* [Tibor Szuntheimer](https://github.com/Producer86)

Flutter is a game-changing technology that will revolutionize not just development, but software itself. A big thank you to the Flutter team for building such an amazing platform 💙

<a href="https://github.com/flutter/flutter"><img alt="Flutter" src="https://raw.githubusercontent.com/Codelessly/ResponsiveFramework/master/packages/Flutter%20Logo%20Banner.png" /></a>

## License
```
Copyright 2023 Codelessly

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following
   disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
   disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products
   derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
