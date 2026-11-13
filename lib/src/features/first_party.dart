// The first-party feature layers and the runner that installs them: what a
// default Codelessly runs. The core runtime (lib/src/runtime) imports none of
// this; an app that wants the renderer and core interactivity alone uses
// CoreActions (or `CodelesslyActions(features: const [])`).
import '../runtime/actions/feature.dart';
import '../runtime/actions/runner.dart';
import 'media/media.dart';

export 'media/media.dart' show SpeechScope, mediaFeature;

/// The first-party features, as a default [CodelesslyActions] installs them.
const List<CodelesslyFeature> kFirstPartyFeatures = [mediaFeature];

/// The default [ActionRunner]: [CoreActions] with the first-party features
/// ([kFirstPartyFeatures]: auth, cloud data and APIs, commerce, media,
/// engage), so every action type the API declares runs. An app overrides or
/// adds handlers by action type ([handlers]) and installs its own features
/// beside (or instead of) the first-party ones ([features]).
class CodelesslyActions extends CoreActions {
  const CodelesslyActions({super.handlers, super.features = kFirstPartyFeatures});

  /// Forgets which `onceKey`s ran (tests, a sign out that should count again).
  static void resetOnceKeys() => CoreActions.resetOnceKeys();
}
