import 'package:equatable/equatable.dart';

import 'model/publish_source.dart';

/// Holds initialization configuration options for the SDK.
class CodelesslyConfig with EquatableMixin {
  /// The SDK auth token required for using the SDK.
  final String authToken;

  /// Allows the SDK to automatically send crash reports back to Codelessly's
  /// servers for developer analysis.
  final bool automaticallyCollectCrashReports;

  /// Whether [CodelesslyWidget]s should show the preview versions of their
  /// layouts.
  ///
  /// Defaults to false.
  final bool isPreview;

  /// Notifies the data manager to download all layouts and fonts of the
  /// configured project during the initialization process of the SDK.
  final bool preload;

  /// The source of the data that should be used when initializing the SDK.
  /// The value will be determined by the [isPreview] and [authToken] values.
  ///
  /// If the authentication data reveals that the layout is a template, then
  /// the value will be [PublishSource.template].
  ///
  /// If the [isPreview] value is true, then the value will be
  /// [PublishSource.preview], otherwise it will be [PublishSource.publish].
  late PublishSource publishSource =
      isPreview ? PublishSource.preview : PublishSource.publish;

  /// Creates a new instance of [CodelesslyConfig].
  ///
  /// [authToken] is the token required to authenticate and initialize the SDK.
  ///
  /// [automaticallyCollectCrashReports] allows the SDK to automatically send
  /// crash reports back to Codelessly's servers for developer analysis.
  ///
  /// No device data is sent with the crash report. Only the stack trace and
  /// the error message.
  CodelesslyConfig({
    required this.authToken,
    this.automaticallyCollectCrashReports = true,
    this.isPreview = false,
    this.preload = true,
  });

  /// Creates a new instance of [CodelesslyConfig] with the provided optional
  /// parameters.
  CodelesslyConfig copyWith({
    String? authToken,
    bool? automaticallyCollectCrashReports,
    bool? isPreview,
    bool? preload,
  }) =>
      CodelesslyConfig(
        authToken: authToken ?? this.authToken,
        automaticallyCollectCrashReports: automaticallyCollectCrashReports ??
            this.automaticallyCollectCrashReports,
        isPreview: isPreview ?? this.isPreview,
        preload: preload ?? this.preload,
      );

  @override
  List<Object?> get props => [
        authToken,
        automaticallyCollectCrashReports,
        isPreview,
        preload,
      ];
}

/// SDK initialization state enums.
enum CodelesslyStatus {
  /// The SDK has not been initialized.
  empty,

  /// The SDK has loaded settings and is ready to be initialized.
  configured,

  /// The SDK is initializing.
  loading,

  /// The SDK is loaded and is ready to use.
  loaded,

  /// The SDK has an error..
  error,
}
