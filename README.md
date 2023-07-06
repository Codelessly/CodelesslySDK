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

#### Step 1: Import Library

Import this library into your project:
```yaml
codelessly_sdk: ^latest_version
```

#### Step 2: Initialize the SDK

Initialize Codelessly before calling `runApp`.

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SDK.
  Codelessly.instance.initialize(
    config: const CodelesslyConfig(
      authToken: AUTH_TOKEN,
      isPreview: kIsDebug,
    ),
  );

  runApp(const MyApp());
}
```

The `authToken` can be found for each project under `Publish > Settings > Settings`. Information on customizing SDK initialization can be found later in the documentation.

#### Step 3: Get a Layout ID

The `CodelesslyWidget` enables your application to update its UI over the air.

```dart
CodelesslyWidget(
  layoutID: LAYOUT_ID,
)
```

Any design or layout can be streamed directly from the Codelessly Editor to your app via the `CodelesslyWidget` with a `layoutID`. 

1. In the Codelessly Editor, select the **canvas** of your layout.
2. Press the **Preview Icon** in the toolbar. ![CloudUI Preview Icon](packages/preview_icon.png)
3. Copy the **layoutID**.

![Codelessly Widget Code](packages/codelessly_widget_code.png)

Refer to the later sections for how to pass variables and functions to the CodelesslyWidget.

#### Step 4: Embed the CodelesslyWidget

The `CodelesslyWidget` can be used like any other widget and embedded anywhere in your app. It can even be used to render entire pages as the root widget.

Here is a complete example:

```dart
import 'package:codelessly_sdk/codelessly_sdk.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Codelessly SDK Example',
      home: CodelesslyWidget(
        layoutID: LAYOUT_ID,
      ),
    );
  }
}
```

To learn how to use the Codelessly editor to publish layouts, check out our [3-minute Quickstart Guide](https://app.gitbook.com/o/rXXdMMDhFOAfV2g6j8A1/s/x4NeiXalJWaOaV6tsK5f/getting-started/3-minute-quick-start).

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

### Customize Initialization

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

## Additional Resources
Please find additional tutorials at our [documentation](https://app.gitbook.com/o/rXXdMMDhFOAfV2g6j8A1/s/x4NeiXalJWaOaV6tsK5f/getting-started/3-minute-quick-start).

If you have any questions or run into any issues, please open an issue or email us at codelessly@gmail.com.

For the latest information on releases and product updates, subscribe to our newsletter on the [Codelessly Website](https://codelessly.com/).