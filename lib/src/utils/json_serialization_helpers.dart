// Copyright (c) 2022, Codelessly.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE.md file.

/// JSON serialization helpers for optimizing Firebase storage.
///
/// These helpers work with `json_serializable` and `includeIfNull: false` to
/// exclude default values and empty strings from JSON output.
///
/// ## Background
///
/// The standard `json_serializable` package only supports `includeIfNull: false`
/// which excludes null values. However, empty strings and default values are
/// still serialized, causing unnecessary storage overhead in Firebase.
///
/// Our previous custom `codelessly_json_serializable` had a
/// `serialize_default_values: false` option that excluded these. This file
/// provides equivalent functionality using `@JsonKey(toJson: fn)` annotations.
///
/// ## Usage
///
/// Use `@JsonKey(toJson: ...)` with these helpers to exclude default values:
///
/// ```dart
/// @JsonSerializable()
/// class MyModel {
///   // Empty strings become null -> excluded by includeIfNull: false
///   @JsonKey(toJson: emptyStringToNull)
///   final String description;
///
///   // Default boolean values become null -> excluded
///   @JsonKey(toJson: trueToNull)
///   final bool enabled;  // Exclude when true (the default)
///
///   @JsonKey(toJson: falseToNull)
///   final bool disabled; // Exclude when false (the default)
///
///   // For custom defaults, use a static method:
///   @JsonKey(toJson: _nameToJson)
///   final String name;
///
///   static String? _nameToJson(String value) =>
///       value == 'default' ? null : value;
/// }
/// ```
library;

/// Converts an empty string to null for JSON serialization.
///
/// When used with `includeIfNull: false`, this effectively excludes
/// empty strings from the JSON output.
///
/// Example:
/// ```dart
/// @JsonKey(toJson: emptyStringToNull)
/// final String description;
/// ```
String? emptyStringToNull(String value) => value.isEmpty ? null : value;

/// Converts an empty or whitespace-only string to null for JSON serialization.
///
/// Similar to [emptyStringToNull] but also handles strings that only contain
/// whitespace characters.
String? blankStringToNull(String value) => value.trim().isEmpty ? null : value;

/// Converts `true` to null for JSON serialization.
///
/// Use this when `true` is the default value and you want to exclude it.
///
/// Example:
/// ```dart
/// @JsonKey(toJson: trueToNull)
/// final bool visible;  // Default is true, exclude when true
/// ```
bool? trueToNull(bool value) => value ? null : value;

/// Converts `false` to null for JSON serialization.
///
/// Use this when `false` is the default value and you want to exclude it.
///
/// Example:
/// ```dart
/// @JsonKey(toJson: falseToNull)
/// final bool disabled;  // Default is false, exclude when false
/// ```
bool? falseToNull(bool value) => value ? value : null;

/// Converts zero to null for JSON serialization.
///
/// Use this when `0` is the default value for an int field.
int? zeroIntToNull(int value) => value == 0 ? null : value;

/// Converts zero to null for JSON serialization.
///
/// Use this when `0.0` is the default value for a double field.
double? zeroDoubleToNull(double value) => value == 0.0 ? null : value;

/// Converts 1.0 to null for JSON serialization.
///
/// Common default for opacity and scale values.
double? oneToNull(double value) => value == 1.0 ? null : value;

/// Converts an empty list to null for JSON serialization.
///
/// Use this when an empty list is the default value.
List<T>? emptyListToNull<T>(List<T> value) => value.isEmpty ? null : value;

/// Converts an empty map to null for JSON serialization.
///
/// Use this when an empty map is the default value.
Map<K, V>? emptyMapToNull<K, V>(Map<K, V> value) => value.isEmpty ? null : value;

/// Converts an empty set to null for JSON serialization.
///
/// Use this when an empty set is the default value.
Set<T>? emptySetToNull<T>(Set<T> value) => value.isEmpty ? null : value;

/// Factory function creator for custom default value exclusion.
///
/// Creates a function that converts [defaultValue] to null.
///
/// Example:
/// ```dart
/// // At file level or as static member:
/// final String? Function(String) regularToNull = defaultToNull('regular');
///
/// // Or inline for simple cases:
/// @JsonKey(toJson: defaultToNull('regular'))
/// final String name;
/// ```
T? Function(T) defaultToNull<T>(T defaultValue) {
  return (T value) => value == defaultValue ? null : value;
}

/// Creates a toJson function that excludes multiple default values.
///
/// Example:
/// ```dart
/// // Exclude both empty string and 'N/A':
/// @JsonKey(toJson: _statusToJson)
/// final String status;
///
/// static String? _statusToJson(String v) =>
///     defaultsToNull(['', 'N/A'])(v);
/// ```
T? Function(T) defaultsToNull<T>(List<T> defaultValues) {
  return (T value) => defaultValues.contains(value) ? null : value;
}
