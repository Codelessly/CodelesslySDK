![Codelessly Logo](packages/Codelessly-Logo-Text.png)
# Codelessly CloudUI™ SDK
[![Pub release](https://img.shields.io/pub/v/codelessly_sdk.svg?style=flat-square)](https://pub.dev/packages/codelessly_sdk) [![GitHub Release Date](https://img.shields.io/github/release-date/Codelessly/CodelesslySDK.svg?style=flat-square)](https://github.com/Codelessly/CodelesslySDK) [![GitHub issues](https://img.shields.io/github/issues/Codelessly/CodelesslySDK.svg?style=flat-square)](https://github.com/Codelessly/CodelesslySDK/issues) [![GitHub top language](https://img.shields.io/github/languages/top/Codelessly/CodelesslySDK.svg?style=flat-square)](https://github.com/Codelessly/CodelesslySDK)

> ### Dynamic UI and real-time updates for Flutter apps

![Codelessly Publish UI](packages/Codelessly-Cover.png)

Supercharge your Flutter apps with dynamic UI and real-time updates. Build and publish UI without code!

- **Real-Time UI Updates:** Adjust your UI as often as you need, all in real-time. Adapt to trends, feedback, and business needs on the fly.
- **Intuitive UI Editor:** Easily create and update UI with our user-friendly Codelessly Editor.
- **Empower Non-Technical Team Members:** Enable anyone on your team to build UI without learning how to code.

## Quickstart
[![Pub release](https://img.shields.io/pub/v/codelessly_sdk.svg?style=flat-square)](https://pub.dev/packages/codelessly_sdk)

#### **Step 1: Import Library**

```yaml
codelessly_sdk: ^latest_version
```

#### **Step 2: Initialize the SDK**

Initialize Codelessly before calling `runApp()`.

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SDK.
  Codelessly.instance.initialize(
    config: CodelesslyConfig(
      authToken: AUTH_TOKEN,
      isPreview: kDebugMode,
    ),
  );

  runApp(const MyApp());
}
```
The `authToken`can be found for each project under `Publish > Settings > Settings`.

#### **Step 3: Embed the CodelesslyWidget**

Easily embed any design from the Codelessly Editor into your app using the `layoutID`.

```dart
CodelesslyWidget(
  layoutID: LAYOUT_ID,
)
```

**How to obtain a Layout ID**

1. In the Codelessly Editor, select the **canvas** of your layout.
2. Press the **Preview Icon** in the toolbar. ![CloudUI Preview Icon](packages/preview_icon.png)
3. Copy the **layoutID**.

![Codelessly Widget Code](packages/codelessly_widget_code.png)

### Complete Example

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

The `CodelesslyWidget` can be used like any other widget and embedded anywhere in your app. It can even be used to render entire pages as the root widget!

From dynamic forms to constantly changing sales and marketing pages, any design or layout can be streamed to your app via the `CodelesslyWidget`. 

To learn how to use the Codelessly editor to publish layouts, check out our [3-minute Quickstart Guide](https://docs.codelessly.com/getting-started/3-minute-quick-start).

## Injecting Data

Customize Codelessly CloudUI™ widgets by passing data values into your layout. The UI will dynamically replace any variables defined in the Codelessly editor with the provided values.

```dart
CodelesslyWidget(
  layoutID: LAYOUT_ID,
  data: {
    // A map of variables, Map<String, dynamic>
  },
),
```

#### **Step 1:** Define variables in the Codelessly Editor

Use the `${}` templating syntax in input fields to link data from the Codelessly editor to layouts as shown below. 

![Data](packages/ui_with_data_linking.png)

To link the title of a text widget to the `title` variable in the Codelessly editor, put `${data.title}` in the text widget’s text field.

> **Note:** The `data` object contains all the variables passed to the CodelesslyWidget. 
>
> Use `${data.title}` to access the `title` variable passed from the client. `${title}` alone is a Codelessly variable and will try to load variables defined in Codelessly, not your client.

#### **Step 2:** Pass data to the layout from your app.

```dart
CodelesslyWidget(
  layoutID: LAYOUT_ID,
  data: {
    'title': 'Fast Performance',
    'description': 'Complete projects on time and easily with our APIs. Get blazing fast performance!',
  },
),
```

Here, `data` parameter is a map of type `Map<String, dynamic>` which is used to populate information in the layout UI where `data`
variable is used from the Codelessly editor. The layout UI will automatically update to reflect the new data whenever
the `data` is updated.

This how it looks with populated data:

![Data](packages/ui_with_populated_data.png)

## Functions

Codelessly SDK also supports calling functions for user actions such as onClick, onLongPress, etc.

```dart
CodelesslyWidget(
  layoutID: LAYOUT_ID,
  functions: {
    'functionName': (context, reference, params) {
      // TODO: Implement your function here
    }),
  },
),
```

#### **Step 1:** Add a "Call Function" Action in the Codelessly Editor

Here, we tell the button to call the native `onNextButtonClicked` function when pressed.

![Defining call function action](packages/defining_call_function_action.png)

In the Codelessly Editor, you can easily add an Action to a widget. Use the `Call Function` action to invoke `onNextButtonClicked`.

1. Switch to the `Develop` tab.
2. Select a widget to open the `Actions` panel.
2. Click on the `+` button to add a new action.
3. Select `Call Function` from the list of actions.
4. Click on the `Settings` button to bring up the `Action Settings` popup.
5. Reference the function name in the `Function Name` field. For example, `onNextButtonClicked`.

**Note:** The `CodelesslyFunction` provides a `CodelesslyContext` which provides internal access to the widget's data, variables, conditions, functions, etc.

**Note 2:** You can declare `data` and `functions` in the global `Codelessly` instance to make them globally accessible to all `CodelesslyWidget`s.

## CodelesslyWidget Options

```dart
CodelesslyWidget(
  layoutID: '0R0Qe7wgeAJMnj3MGW4l',
  isPreview: kDebugMode,
  config: CodelesslyConfig(
  authToken: 'LCVyNTxyLCVxQXh3WDc5MFowLjApQXJfWyNdSnlAQjphLyN1',
  ),
)
```

- `layoutID`: The ID of the published canvas. The ID can be found in Quick Preview or under `Publish > Settings > Published Layouts`.

![Codelessly Published Layout ID](packages/codelessly_published_layout_id.png)

- `isPreview`: Whether the layout is in preview or production mode. Preview mode is meant for debugging the layout and syncs with the changes made in the editor. Widgets in production mode are only updated when published using the Publish button.
- `config`: An optional `CodelesslyConfig` that holds the information required to authenticate your layout from the server.

**Note:** Setting a `CodelesslyConfig` on a CodelesslyWidget overrides the global Codelessly instance settings. This lets you embed layouts from other projects with different auth tokens.

## Environment Configuration

The CodelesslyWidget supports **Preview** and **Published** environments via the `isPreview` boolean.

```dart
// Global config.
Codelessly.instance.initialize(
  config: CodelesslyConfig(
    isPreview: true,
  ),
);

// Widget level. Overrides global settings for this widget.
CodelesslyWidget(
  isPreview: true
);
```

### Preview Mode

> Realtime UI updates - edits made in the Codelessly Editor are mirrored immediately to the app.

When `isPreview` is set to true, the CodelesslyWidget will stream UI updates from the Codelessly Editor in realtime. Any edits to the UI in the editor will update in the app immediately. We think this is a pretty amazing feature so give it a try!

Use preview mode to test and prototype UI quickly. 

#### Flavor Support

A common request is to enable Preview mode in QA environments to support updating the UI on test user's devices. That can be done by setting the `isPreview` value based on the flavor or runtime environment.

```dart
// Global config.
Codelessly.instance.initialize(
  config: CodelesslyConfig(
    isPreview: FlavorConfig.flavor != "prod",
  ),
);
```

This enables realtime updates on release devices in a test environment, excluding production.

### Production Mode

> Publish UIs with absolute control over updates and versioning.

`isPreview` should be set to false for production environments to prevent the UI from changing. When running in Publish (aka Production) mode, UI changes must be explicitly published to update the UI. This makes working in the editor safe and prevents undesired changes from reaching end users.

**Note:** You do not need to change layoutIDs when switching from Preview to Production. Canvases have a single unique layoutID that the system uses to identify layouts with. Codelessly Servers will automatically handle loading the correct layout when moving from Preview to Production.

## Configuration Options

### CodelesslyConfig

```dart
Codelessly.instance.initialize(
  config: CodelesslyConfig(
    authToken: AUTH_TOKEN,
    isPreview: kDebugMode,
    preload: true,
    automaticallyCollectCrashReports: true,
  ),
);
```

CodelesslyConfig supports the following configuration capabilities.

* `isPreview`: Global enable or disable preview-mode setting.
* `preload`: Preload layouts to improve performance. When layouts are preloaded, they load instantly and behave like local widgets. `true` by default.
* `automaticallyCollectCrashReports`: Report SDK crashes to Codelessly. `true` by default. You can optionally disable this behavior.

### Global Data and Functions

Data and functions registered in the global `Codelessly.instance` are available to all CodelesslyWidgets.

```dart
Codelessly.instance.initialize(
  data: {'username': 'Sample User', 'paid': false},
  functions: {
    'openPurchasePage': CodelesslyFunction(
      (context) => Navigator.pushNamed(context, "PurchasePage")),
  },
);
```

## Demo
### [CodelesslyGPT](https://sdk-chat-bot.web.app/#/)
A demo chat-bot interface built with the Codelessly SDK. [View Code](https://github.com/Codelessly/CodelesslySDK/tree/main/example_chat_bot)

## Additional Resources
Additional resources and tutorials are on our [documentation website](https://docs.codelessly.com/getting-started/3-minute-quick-start).

If you have any questions or run into any issues, please open an issue or email us at [codelessly@gmail.com](mailto:codelessly@gmail.com).

For the latest information on releases and product updates, subscribe to our newsletter on the [Codelessly Website](https://codelessly.com/).