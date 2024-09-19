## 5.1.0
- Fix Hive CE duplicate initialization error.
- Update Firestore v3.5.0.

## 5.0.0
- Restore Wasm Web support.
- Require Flutter v3.24.0 and Dart SDK v3.5.0.

## 4.0.0

- Teams V2 support. Owner field & admin Role migration.
- New SDK usage and stat tracking.
- Skip downloading disabled layouts.
- Add Open URL error handling.
- Create `where` query API.
- Create new `image` variable type.
- Add Date decoder.

## 3.0.3

- Revert Hive CE dependency.

## 3.0.2

- Remove direct `package:web` dependency.

## 3.0.1

- Migrate Wasm dependencies.

## 3.0.0

- Wasm Web support.
- Codelessly v10 release.
- Update Firebase v3.3.0.

## 2.3.0

- New guided setup flow for getting started with CloudUI.
- Add support for toggling CloudUIs on and off. They're like feature flags, except much more powerful!

## 2.2.1

- Set target platforms.

## 2.2.0

- Restored Windows support. Codelessly CloudUI™ now supports all Flutter platforms!

## 2.1.1

- Fix Firebase exception on web.
- Fix Text Input `Set Value` action not working.

## 2.1.0

- New TextInputField features! This is the first batch of improvements to the TextInput component and includes the
  following:
    - Added Autofill Hints support.
    - Added Text Input Validator.
    - Added Text Input Formatter.
    - Added Submit Keyboard Action selector.
- New Editor layout rendering pipeline!
    - Huge improvements to TextInputField rendering accuracy.
- Fix website publishing error that occurs when using an empty Navigate Action.

## 2.0.2

- Update CodelesslyException to display better errors during development.
- Update external components with reactions.
- Add click and long click reactions to rectangle node.

## 2.0.1

- Fix nested shrink-wrapping Stacks size calculations.

## 2.0.0

- Firebase v3.1.0 support.
- Update Checkbox shrinkwrap and padding sizing.
- Change default Stroke cap to none.
- Optimize node sorting algorithm.
- Highlight text with missing fonts.
- Improve WebView widget support for multiple platforms.

## 1.9.0

- Flutter v3.22 support.

## 1.8.0

- Custom Layout IDs support! Use a human readable ID for CodelesslyWidgets to help identify and differentiate CloudUI in
  your code.

## 1.7.0

- Teams v1 support.

## 1.6.0

- Initial CloudUI support for Layout Groups.
    - Display different layouts for different screen sizes.

## 1.5.0

- Multi environment support. Use multiple Codelessly widgets simultaneously from different projects.
- Update Google Fonts v6.2.1.

## 1.4.0

- New StyleSheets support! Create reusable color and text styles.
- Update GridView `childAlignment` property. Minor refactor.
- Improve Edge Pins.
    - Fix edge pins not being saved.
    - Clamp edge pins to positive values in wrapping parent layouts.

## 1.3.0

- Temporarily remove Windows support as Firebase Auth is not supported on Windows yet.
- Update dependencies.

## 1.2.0

- Cache system improvements to load layouts better.
- Inkwell improvements.
- Implement isTrue and isFalse operators for conditions.
- Refactor operator filtering to use index if available.
- **Fixes**
    - Fix doc data validation on creation.
    - Fix canvas with auto-scale always aligning at top center.
    - Fix list remove operation type mismatch.
    - Fix download and cache system optimizations.

## 1.1.0

- New AutoComplete support for Variables.
- New `createdAt` and `updatedAt` variables to support sorting by date.
- Button improvements:
    - Improve button layout calculations.
    - Fix conditions not evaluating on button labels.
- Image Editor improvements:
    - Fix image fill editor pixel overflow.
    - Fix image fill tooltips rendering oddly.
    - Fix images invisible after flipping.
- Fixes:
    - Fix disable automatic padding from Frames with strokes.
    - Fix canvas color visibility not working when there's only 1 fill.
    - Fix set variable action not using variable type properly.
    - Fix inequality operator was checking for equality.
    - Fix unsupported type text not visible in json view.

## 1.0.0

- Official v1 release!
- Migrate to Material 3.
- Text field improvements.
    - Fix text field not updating internal state in a list view.
    - Fix text field state sync issue.
    - Fix list operation action when index is out of bounds.
    - Changes to enable ListViews to shrinkwrap.
- Add variable support for button color properties.

## 0.8.0

- Codelessly Data support. Save and write data to Codelessly Cloud.
- New GridView widget.
- Codelessly Data Query Filters support. Sort and filter data.
- Variable improvements.
    - Include 'set' and 'replace' operations for list operations.
    - Add new ${value} predefined variable to expose internal node data. TextFields only for now.
    - Track internal value with new NodeProvider InheritedWidget per-widget.
    - Fix variable substitution for api request body of text type.
- TextField improvements.
    - Add variable support for all text field text properties.
    - Add support for actions on prefix and suffix icons on text fields.
    - Fix set operation on map not showing input field.
    - Implement proper TextFieldModel minimum size computation.
    - Add support for TextInputType.numberWithOptions.
- JSON improvements.
    - Fix json variable controller highlighting.
    - Fix json syntax highlighting for storage operations.
    - Fix focus nodes for json variable input fields.
- List improvements.
    - Add insertAll option for list operations
    - Refactor insert list operation to use json input field.
- Add copy-paste and shortcuts support for actions.
- Add support for non-blocking actions.
- Implement option to enable/disable action.
- Add firebase queries support for grid view.
- Add support for number operations.
- Codelessly Data improvements.
    - Implement filters and sort for load from cloud database action.
    - Make document ID optional for load from cloud database action.
    - Improve UI of list view settings panel.
    - Dismiss filters dialog on save.
    - Implement collection streaming for cloud database.
    - Add limit option in list view settings panel.
    - Add limit option for load from cloud database action.
- Add Firestore ListView support.
- Add Firestore and remove FireDart.
- Fix image url substitution.
- New authentication and Firebase initialization.

## 0.7.5

- API fixes.
    - Fix variable substitution in API parameter value.
    - Fix default value not being used correctly for API parameters.
    - Remove body and bodyBytes param from API response to optimize performance.
- Fix drag and drop insert to the edge of Accordion, Expansion Tile, ListView, and PageView.
- Enable support for base64 data decoding in ImageBuilder.

## 0.7.4

- Hotfix shrinkwrapping stack alignment layout.
- Use maybePop instead of pop for navigate action.

## 0.7.3

- Migrate Variables and Conditions to use permissions model.
- TextField Improvements.
    - Fix shrink-wrapping conflict with expands property.
    - Fix text field model not calculating text field height properly for shrink-wrapping.
    - Allow min lines and max lines input fields to clear.
    - Fix shrink-wrap height calculation being affected by isDense property.
- Preview Improvements.
    - Use editor video preview images for renderer.
    - Show current variant for preview mode.
- Stack Layout Improvements.
    - Update codegen to reflect new shrinkwrapping-stack alignment changes.
    - Miscellaneous fixes.
- Fix color filter for image error builder.
- Add more logs & minor improvements.

## 0.7.2

- Implement global listeners for navigation.
- Update Alignment rules and behavior in Stacks.
- Fix web view controller crashing on macOS.
- Fix sdk disposing not working properly.
- Fix embedded canvases crashing with local storage.
- Fix and improve CStatus constructors.

## 0.7.1

- Improve Alignment and Positioning.
- Improve SDK preload performance. New Download Queue system speeds up layout downloads.
- Fix AppBar not navigating back when leading is a custom icon.
- Scrolling Improvements.
    - Fix scroll physics and always scrollable option.
    - Fix scrolling being cut off.
    - Fix stack crash when scrollable and no aligned children.
    - Fix scrollable size fit rules to allow fixed and flexible size fits.
- Implement safe area for canvases
- Substitute WebView input/src with variable values.

## 0.7.0

- New Dialogs feature! 100% customizable dialogs with customizable close button, background, and padding.
    - New show dialog action.
    - New show dialog settings panel.
- Improve Embedded Canvases preview rendering.
- Improve Scrolling.
    - Enable scrolling for expanded frames with special conditions for child.
    - Fix ClipRect as SingleChildScrollView child not being merge swept.
    - Don't use alignment on container from the child in codegen if it is scrollable.
    - Removed fixed width/height with a SizedBox around SingleChildScrollView.
    - Don't wrap a stack child with Align widget if it is scrollable.
    - Fix scrollable property enable/disable conditions to allow proper scrolling in some special cases.
- Fix Edge Pins not syncing with server.
- Fix PageView triggers not executing.
- Fix Button size rendering incorrectly.
- Fix SDK incorrect variables initialization from actions.
- Fix image always using fixed sizes.

## 0.6.0

- Embedded Canvases V1.
    - Embed canvases into layouts.
- Local Storage V1.
    - Store and persist data locally.
- Optimize JSON data to reduce data usage and storage by 80%.
- ListView Improvements
    - Use keys for ListView items.
    - Fix list view not using data length first.
    - Prioritize hard coded item count for list view and page view in preview mode.
    - Fix set variable actions on null list and map variables.
    - Fix set variable action for list and map items.
- TextField Improvements
    - Implement TextField model for better shrink-wrapping.
    - Fix TextField not submitting on focus change.
    - Fix TextField not invoking onSubmitted actions.
    - Fix text field always being wrapped with SizedBox.
    - Allow horizontally shrink-wrapping text fields.
- Variable Improvements
    - Implement custom value notifier for SDK use with controllable notify feature.
    - Avoid notifying variable changes when actions are executed on canvas load.
    - Fix canvas load crash when variables notify.
    - Fix ManagedListenableBuilder notifying when not mounted.

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

- New simplified variables system. Variables passed into the CodelesslyWidget can now be referenced by name in the
  Codelessly Editor.

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
