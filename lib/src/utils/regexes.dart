/// A regex that matches any variable path in a string.
/// This is a strict matching regex that doesn't allow partial match.
///
/// Note: This is a complete regex that can be used to match any variable path
///       in a string. This doesn't work when the text/path is actively being
///       composed. For that, use [variablePathComposingRegex]. Composing regex
///       allows for partial match on {} curly braces.
///
/// ============================================================================
///   Ruleset used to generate this regex:
/// ============================================================================
///   1. Must start with an alphabet character, followed by zero or more
///      alphanumeric characters or underscores. This applies to any nested
///      properties/path names as well.
///   2. [] accessor should only allow numbers in between.
///
/// ============================================================================
///   Test cases used to validate this regex:
/// ============================================================================
/// // valid
/// ${data.hello}
///
/// // valid
/// ${hello}
///
/// // valid
/// ${list[0]}
///
/// // invalid
/// ${list[name]}
///
/// // valid
/// ${data2.hey}
///
/// // valid
/// ${d.a}
///
/// // invalid
/// ${_abc}
///
/// // invalid
/// ${0abc}
///
/// // invalid
/// ${model.0data}
///
/// // valid
/// ${model_.data}
///
/// // valid
/// ${model.dat2}
///
/// // invalid
/// ${model._data}
///
/// // valid
/// ${my_model.data}
///
/// // invalid
/// ${my_model._new_data}
///
/// // valid
/// ${my_model.new_data}
///
/// // valid
/// ${model.list[5]}
///
/// // valid
/// ${model.json.name}
///
/// // invalid
/// ${model.list[name]}
///
/// ============================================================================
///
/// ============================================================================
///   Regex explanation:
/// ============================================================================
/// \$\{                            # Matches the starting "${" literal
///   (?<value>                     # Named capture group "value" for the entire variable expression:
///     (?<name>                    # Named capture group "name" for the variable name:
///       [a-zA-Z]                  # Matches a single alphabet character
///       [a-zA-Z0-9_]*             # Matches zero or more alphanumeric characters or underscores
///     )                           # End of the named capture group "name"
///     (
///       (?<accessor>\[\d+\])      # Named capture group "accessor" for array access:
///                                 #   - \[\d+\] matches one or more digits surrounded by square brackets
///       |
///       (?:                       # Non-capturing group for nested path access:
///         \.                      # Matches a dot (for nested properties)
///         (?<path>                # Named capture group "path" for nested property name:
///           [a-zA-Z]+             # Matches one or more alphabet characters
///           [a-zA-Z0-9_]*         # Matches zero or more alphanumeric characters or underscores
///           (?:                   # Non-capturing group for optional array access:
///             \[\d+\]             # Matches one or more digits surrounded by square brackets
///           )*                    # End of the non-capturing group, allows for zero or more occurrences
///         )                       # End of the named capture group "path"
///       )
///     )*                          # End of the outer group, allows for zero or more occurrences
/// ============================================================================
///
/// Try it out here: https://regex101.com/r/FOyWLJ/1
const String variablePathPattern =
    r'\$\{(?<value>(?<name>[a-zA-Z][a-zA-Z0-9_]*)((?<accessor>\[\d+\])|(?:\.(?<path>[a-zA-Z]+[a-zA-Z0-9_]*(?:\[\d+\])*))*)?)\}';
final RegExp variablePathRegex = RegExp(variablePathPattern);

const String variablePathComposingPattern =
    r'\$\{?(?<value>(?<name>[a-zA-Z][a-zA-Z0-9_]*)((?<accessor>\[\d+\])|(?:\.(?<path>[a-zA-Z]+[a-zA-Z0-9_]*(?:\[\d+\])*))*)?)\}?';
final RegExp variablePathComposingRegex = RegExp(variablePathComposingPattern);

/// A regex that matches any variable path identifier in a string that is
/// wrapped in ${} curly braces.
const String variableSyntaxIdentifierPattern = r'\${(?<value>.+)}';
final RegExp variableSyntaxIdentifierRegex =
    RegExp(variableSyntaxIdentifierPattern);

/// A regex that matches any variable name identifier in a string that is
/// wrapped in ${} curly braces. This is a lenient matching regex that allows
/// partial match within the curly braces.
///
/// Rules for the variable name match:
///  1. Must start with an alphabet character, followed by zero or more
///     alphanumeric characters or underscores.
///
/// Regex explanation:
///
/// \$\{?                        # Matches the starting "${" literal (optional)
/// (?<name>                     # Named capture group "name" for the variable name:
///   [a-zA-Z]+                  # Matches one or more alphabet characters
///   [a-zA-Z0-9_]*              # Matches zero or more alphanumeric characters or underscores
/// )                            # End of the named capture group "name"
/// \}?                          # Matches the closing "}" literal (optional)
const String variableNameIdentifierPattern =
    r'\$\{?(?<name>[a-zA-Z]+[a-zA-Z0-9_]*)\}?';
final RegExp variableNameIdentifierRegex =
    RegExp(variableNameIdentifierPattern);

/// A regex that matches a simple variable input. This is a strict matching
/// regex that doesn't allow partial match. e.g. ${id}
///
/// This is primarily used in cases where an input placeholder is needed which
/// will be replaced with a value at runtime or from somewhere else.
/// e.g. API input variables
///
/// Rules for the variable name match:
///     1. Must start with an alphabet character, followed by zero or more
///        alphanumeric characters or underscores.
///     2. Must be wrapped in ${} curly braces.
///     3. Must not contain any nested properties or array accessors.
///     4. Must not contain any whitespace characters.
///     5. Must not contain any special characters.
///
/// Regex explanation:
///
/// \${                          # Matches the starting "${" literal
///   ([a-zA-Z]+                 # Matches one or more alphabet characters
///   [a-zA-Z0-9_]*)             # Matches zero or more alphanumeric characters or underscores
/// }                            # Matches the closing "}" literal
const String inputPattern = r'\${([a-zA-Z]+[a-zA-Z0-9_]*)}';
final RegExp inputRegex = RegExp(inputPattern);

const String rawVariableNamePattern = r'[A-Za-z]+[A-Za-z0-9_]*';
final RegExp rawVariableNameRegex = RegExp(rawVariableNamePattern);