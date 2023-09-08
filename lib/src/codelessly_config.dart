import 'package:equatable/equatable.dart';

import 'constants.dart';
import 'model/publish_source.dart';

/// Holds initialization configuration options for the SDK.
class CodelesslyConfig with EquatableMixin {
  /// The SDK auth token used to authenticate the SDK with the Codelessly
  /// servers.
  final String authToken;

  /// A project slug configured in the publish settings of the Codelessly
  /// editor.
  final String? slug;

  /// A convenience getter that returns a non-null unique identifier for this
  /// [CodelesslyConfig] instance since either [authToken] or [slug] will be
  /// non-null.
  String get uniqueID => slug ?? authToken;

  /// Allows the SDK to automatically send crash reports back to Codelessly's
  /// servers for developer analysis.
  final bool automaticallySendCrashReports;

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

  /// The project ID of the Firebase project to use. This is used to
  /// initialize Firebase.
  ///
  /// Note that if this is changed changed when widget is already initialized,
  /// it will have no effect. Only the value provided when the widget is
  /// initialized will be used.
  final String firebaseProjectId;

  /// Base URL of the Firebase Cloud Functions instance to use.
  final String firebaseCloudFunctionsBaseURL;

  /// Creates a new instance of [CodelesslyConfig].
  ///
  /// [authToken] is the token required to authenticate and initialize the SDK.
  ///
  /// [automaticallySendCrashReports] allows the SDK to automatically send
  /// crash reports back to Codelessly's servers for developer analysis.
  ///
  /// No device data is sent with the crash report. Only the stack trace and
  /// the error message.
  CodelesslyConfig({
    required this.authToken,
    this.slug,
    this.automaticallySendCrashReports = true,
    this.isPreview = false,
    this.preload = true,
    this.firebaseProjectId = defaultFirebaseProjectId,
    this.firebaseCloudFunctionsBaseURL = defaultFirebaseCloudFunctionsBaseURL,
  });

  /// Creates a new instance of [CodelesslyConfig] with the provided optional
  /// parameters.
  CodelesslyConfig copyWith({
    String? authToken,
    String? slug,
    bool? automaticallySendCrashReports,
    bool? isPreview,
    bool? preload,
    String? firebaseProjectId,
    String? firebaseCloudFunctionsBaseURL,
  }) =>
      CodelesslyConfig(
        authToken: authToken ?? this.authToken,
        slug: slug ?? this.slug,
        automaticallySendCrashReports: automaticallySendCrashReports ??
            this.automaticallySendCrashReports,
        isPreview: isPreview ?? this.isPreview,
        preload: preload ?? this.preload,
        firebaseProjectId: firebaseProjectId ?? this.firebaseProjectId,
        firebaseCloudFunctionsBaseURL:
            firebaseCloudFunctionsBaseURL ?? this.firebaseCloudFunctionsBaseURL,
      );

  @override
  List<Object?> get props => [
        authToken,
        slug,
        automaticallySendCrashReports,
        isPreview,
        preload,
        firebaseProjectId,
        firebaseCloudFunctionsBaseURL,
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
