import 'package:equatable/equatable.dart';
import 'package:firebase_core/firebase_core.dart';

import 'constants.dart';
import 'firebase_options_prod.dart';
import 'logging/error_handler.dart';
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
  PublishSource publishSource;

  /// The project ID of the Firebase project to use. This is used to
  /// initialize Firebase.
  ///
  /// Note that if this is changed changed when widget is already initialized,
  /// it will have no effect. Only the value provided when the widget is
  /// initialized will be used.
  final FirebaseOptions firebaseOptions;

  /// Base URL of the Firebase Cloud Functions instance to use.
  final String firebaseCloudFunctionsBaseURL;

  /// Base URL of the environment to use. Helpful for hosted video players.
  final String baseURL;

  /// The unique name of the Firebase instance to use. Defaults to
  /// [kCodelesslyFirebaseApp].
  final String firebaseInstanceName;

  /// Enable or disable console logs.
  ///
  /// **DebugLogger**
  /// For further log customization, set DebugLogger.instance behavior.
  /// For example, to highlight specific logs, use `DebugLogger.instance.highlight`.
  ///  ```dart
  ///  DebugLogger.instance.highlight(name: DataManager.name);
  ///  ```
  ///
  /// **Logging Package**
  /// This library uses the logging package. Set the package logger's logging level directly.
  ///  ```dart
  ///  logging.Logger(Codelessly.name).level = logging.Level.ALL;
  ///  ```
  final bool debugLog;

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
    this.automaticallySendCrashReports = false,
    this.isPreview = false,
    this.preload = true,

    // Firebase.
    FirebaseOptions? firebaseOptions,
    this.firebaseInstanceName = kCodelesslyFirebaseApp,
    this.firebaseCloudFunctionsBaseURL = defaultFirebaseCloudFunctionsBaseURL,
    this.baseURL = defaultBaseURL,
    PublishSource? publishSource,
    this.debugLog = false,
  })  : firebaseOptions =
            firebaseOptions ?? DefaultFirebaseOptionsProd.currentPlatform,
        publishSource = publishSource ??
            (isPreview ? PublishSource.preview : PublishSource.publish);

  /// Creates a new instance of [CodelesslyConfig] with the provided optional
  /// parameters.
  CodelesslyConfig copyWith({
    String? authToken,
    String? slug,
    bool? automaticallySendCrashReports,
    bool? isPreview,
    bool? preload,
    bool? staggerDownloadQueue,
    FirebaseOptions? firebaseOptions,
    String? firebaseCloudFunctionsBaseURL,
    String? baseURL,
    String? firebaseInstanceName,
    PublishSource? publishSource,
  }) =>
      CodelesslyConfig(
        authToken: authToken ?? this.authToken,
        slug: slug ?? this.slug,
        automaticallySendCrashReports:
            automaticallySendCrashReports ?? this.automaticallySendCrashReports,
        isPreview: isPreview ?? this.isPreview,
        preload: preload ?? this.preload,
        firebaseOptions: firebaseOptions ?? this.firebaseOptions,
        firebaseCloudFunctionsBaseURL:
            firebaseCloudFunctionsBaseURL ?? this.firebaseCloudFunctionsBaseURL,
        baseURL: baseURL ?? this.baseURL,
        firebaseInstanceName: firebaseInstanceName ?? this.firebaseInstanceName,
        publishSource: publishSource ?? this.publishSource,
      );

  @override
  List<Object?> get props => [
        authToken,
        slug,
        automaticallySendCrashReports,
        isPreview,
        preload,
        firebaseOptions,
        firebaseCloudFunctionsBaseURL,
        baseURL,
        firebaseInstanceName,
        publishSource,
      ];
}

enum CLoadingState {
  initializing('Initializing'),
  initializedFirebase('Initialized Firebase'),
  createdManagers('Created Managers'),
  initializedCache('Initialized Cache'),
  initializedAuth('Initialized Auth'),
  initializedDataManagers('Initialized Data Managers'),
  initializedSlug('Initialized Slug');

  final String label;

  const CLoadingState(this.label);

  bool hasPassed(CLoadingState state) {
    return index >= state.index;
  }
}

sealed class CStatus {
  const CStatus();

  factory CStatus.empty() => CEmpty();

  factory CStatus.configured() => CConfigured();

  factory CStatus.loading(CLoadingState state) => CLoading(state);

  factory CStatus.loaded() => CLoaded();

  factory CStatus.error(CodelesslyException exception) => CError(exception);
}

class CEmpty extends CStatus {
  const CEmpty._();

  factory CEmpty() => const CEmpty._();
}

class CConfigured extends CStatus {
  const CConfigured._();

  factory CConfigured() => const CConfigured._();
}

class CLoading extends CStatus {
  final CLoadingState state;

  const CLoading(this.state);
}

class CLoaded extends CStatus {
  const CLoaded._();

  factory CLoaded() => const CLoaded._();
}

class CError extends CStatus {
  final CodelesslyException exception;

  const CError(this.exception);
}
