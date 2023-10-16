## 0.5.2
- New properties panel for Accordion widget.
- Optimize SDK loading performance. Load from Firestore Storage to reduce loading time by up to 90%.
- Fix layout initial load not reading from cache.
- Fix Inkwell not rendering without a Material parent.

## 0.5.1
- New shrink-wrap support for Buttons. Buttons can now resize based on the content inside them.
- New shrink-wrapping support for Slider, Switch, and Radio Button components.
- Fix ListView and PageView reverse scroll direction not enabled.
- Update null values to display empty instead of "null" text.
- Add video thumbnail previews.
- Fix video controller disposal.
- Fix expansion tile auto collapsing on resize.
- Fix expansion tile settings panel resetting `initiallyExpanded` property.

## 0.5.0
- Load API V1.
- Update layout algorithm to Flutter's Stack behavior changes.
- Fix ExpansionTiles layout and functionality issues.
- Fix reactions not being modified.
- Support Google Fonts v6.
- Add visual density support for buttons.
- Fix image alignment overlay BoxFit.none rendering poorly with different scaling.
- Fix stack alignment in code-gen.
- Fix ListTile action invocation.
- Fix dropdown image icon not updating
- Remove FetchWebsiteData.

## 0.4.1
- Add hover and splash color to dropdown node.
- Add color support for custom image icons.
- Fix spacer crashing.
- Remove unnecessary Material widgets.
- Add WidgetBuildSettings to control widget decorators.
- Fix layout system to support max constraints.
- Miscellaneous fixes.

## 0.4.0
- New WebView support for Web! Embedded videos and Iframes now work great!
- Improved WebView embedding for Android and iOS.
- New `SetMapVariableAction` support for map variables.
- Support more conditions.
    - `isEmpty`, `isNotEmpty`, `contains`
    - `isOdd`, `isEven`, `isNull`
- Add `remove` for list type variable.
- Remove deprecations and update formatting and documentation.
- Update Stack rendering to match Flutter's updated Stack behavior.
  - If a stack is wrapping, use margin to position children to preserve Stack layout. 
  - Change magnetization delegate to lock child inside the bounds of a stack that is wrapping.
  - Disallow wrapping if any child is outside the bounds of the wrapping node.
- Fix row/column scrollable widget tree implementation to render more accurately, especially with padding.
- Fix EdgeInsets.LTRB missing values in codegen.
- Round snapping value in NodeInteractionFreeform to discourage negative precision errors.
- Rename `automaticallyCollectCrashReports` to `automaticallySendCrashReports`.

## 0.3.0
- Scrolling V1. Enable scrolling for Columns, Frames, and Canvases.
- Create list operations and index for List `SetVariableAction`.
- AutoScale improvements. Fix incorrect sizing and scrolling.
- Improve InkWells and onTap behavior.
- Improve Icon onTap behavior.

## 0.2.0
- New simplified variables system. Variables passed into the CodelesslyWidget can now be referenced by name in the Codelessly Editor.

```
CodelesslyWidget(
  data: {
    'title': 'My Title',
    'productData': { // JSON Data
      'nested': {
        'json': {
          'path': 'Hey there!',
        }
      }
    }
  }
)

// Now you can access the variable directly in the Codelessly Editor.
${title} - 'My Title'

// Or, using the `data` object.
${data.title} - 'My Title'
${data.productData.nested.json.path} - 'Hey there!'
```

- New SVG image support!
- New hosted website publishing support.
- Add `>=`, `<=`, and `== null` operators.
- Add data and variable support for dropdown component.
- Add Material 3 Switch UI component.
- Add Rounded Circular Progress Indicator component.
- Improve InkWell behavior. Show Inkwell effect on top of other widgets.
- Prototype implementation of custom widget embedding feature.

## 0.1.0
- Update CodelesslyAPI v0.1.0.
- Optimize SDK size by 90% by switching to SVG icons.
- Add path support for Flutter Website publishing.
- Consolidate `initialize()` function.
- Fix Hive cache dispose not working on web.

## 0.0.8
- Update CodelesslyAPI v0.0.8.
- Text field and code-gen improvements.
- Fix text field counter text not working properly.

## 0.0.7
- Update CodelesslyAPI v0.0.7.
- Add support for Tabs.
- Add TextField support for variables.
- Add FAB support for variables.

## 0.0.6
- Update visibility rendering.

## 0.0.5
- Update CodelesslyAPI v0.0.5.
- Fix image rendering.
- Fix layout loading with conditions.
- Revamp example app.
- Fix multi-variables not being registered.
- Fix auto-scale rendering.
- Provide BuildContext as a parameter for `CodelesslyFunction`.
- Improve visibility rendering.

## 0.0.4
- Update CodelesslyAPI v0.0.5.
- Update example.

## 0.0.3
- Update GoogleFonts v5.0.0
- Update CodelesslyAPI v0.0.3.

## 0.0.2
- Upgrade to Flutter 3.10 and Dart 3.
- Add support for listview and pageview.
- Add support for api call action.
- Add `AssetModel`.
- Disable error screen when not in preview mode.
- Show blank screen while loading.
- Update README.
- Update documentation.

## 0.0.1
- Initial Prerelease.