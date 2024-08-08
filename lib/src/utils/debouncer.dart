import 'dart:async';

/// typedef for action function for [DeBouncer]
typedef DeBounceAction<R> = FutureOr<R> Function();

/// de-bounces [run] method calls and runs it only once in given [duration].
/// It will ignore any calls to [run] until [duration] has passed since the
/// last call to [run].
/// It can be used to de-bounce any method calls like search, filter, etc.
final class DeBouncer {
  /// Allows to create an instance with optional [Duration] with
  /// immediateFirstRun set to false. See [immediateFirstRun] for more details.
  DeBouncer([Duration? duration])
      : duration = duration ?? const Duration(milliseconds: 300),
        immediateFirstRun = false;

  /// Allows to create an instance with optional [Duration] with
  /// immediateFirstRun set to true. See [immediateFirstRun] for more details.
  DeBouncer.immediate([Duration? duration])
      : duration = duration ?? const Duration(milliseconds: 300),
        immediateFirstRun = true;

  /// de-bounce period. Default is 300 milliseconds.
  /// It will ignore any calls to [run] until [duration] has passed since the
  /// last call to [run].
  final Duration duration;

  /// Allows to run the first call immediately. Default is false.
  /// If set to true, the first call to [run] will be executed immediately
  /// calling the [action] and then it will wait for [duration] to run the next
  /// call if there's any.
  ///
  /// If set to false, any call to [run] will be ignored until [duration] has
  /// passed since the last call to [run] and then it will run the [action].
  final bool immediateFirstRun;

  Timer? _timer;

  int _counter = 0;

  /// Returns true if timer is running and a call is scheduled to run in future
  /// else returns false.
  bool get isRunning => _timer?.isActive ?? false;

  /// Runs [action] after debounced interval.
  /// If [immediateFirstRun] is set to true, it will run the [action]
  /// immediately for the first call and then it will wait for [duration] to
  /// run the next call if there's any.
  ///
  /// This [immediateFirstRun] will override the instance level setting. If
  /// not provided, it will use the instance level setting.
  ///
  /// Returns a [Future] that completes with the result of the [action] call
  /// when it is executed. If [action] is async, it will wait for the
  /// future to complete and then it will complete the returned future.
  ///
  /// Note that returned future will complete with the result of the [action]
  /// call only when it is executed. If the [action] is not executed due to
  /// debouncing, the returned future will not complete.
  ///
  /// [forceRunAfter] will force run the provided [action] instead of debouncing
  /// if the number of debounces that have occurred exceed the value provided.
  /// This is useful if you have a long and continuous stream of events that
  /// should be debounced but need to be broken up. An example of this is
  /// debouncing server events by clumping multiple events together and only
  /// updating the server occasionally.
  Future<R> run<R>(
    DeBounceAction<R> action, {
    bool? immediateFirstRun,
    int? forceRunAfter,
  }) {
    immediateFirstRun ??= this.immediateFirstRun;
    final completer = Completer<R>();

    _counter++;

    if (((forceRunAfter != null && forceRunAfter < _counter) ||
            immediateFirstRun) &&
        !isRunning) {
      // Reset the counter for forced runs.
      if (forceRunAfter != null) _counter = 0;

      // Execute the action immediately and cancel the previous timer if any!
      _timer?.cancel();
      // fake timer to prevent immediate call on next run.
      _timer = Timer(duration, () {});
      return _runAction<R>(action, completer);
    }

    _timer?.cancel();
    _timer = Timer(duration, () => _runAction<R>(action, completer));

    return completer.future;
  }

  Future<R> _runAction<R>(DeBounceAction<R> action, Completer<R> completer) {
    final FutureOr<R> result = action();
    if (result is Future<R>) {
      // action is async and returns a future. Wait for the future to complete
      // and then complete the completer.
      result
          .then((result) => completer.complete(result))
          .catchError((Object e) => completer.completeError(e));
      return completer.future;
    }

    // action is sync and returns a value.
    completer.complete(result);
    return completer.future;
  }

  /// alias for [run]. This also makes it so that you can use the instance
  /// as a function.
  ///
  /// e.g.
  /// ```dart
  /// final debouncer = DeBouncer();
  /// debouncer(() async {
  ///   // your action here
  ///   print('debounced action');
  /// });
  /// ```
  ///
  /// Returns a [Future] that completes with the result of the [action] call
  /// when it is executed. See [run] for more details.
  Future<R> call<R>(DeBounceAction<R> action) => run<R>(action);

  /// Allows to cancel current timer.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

/// global instance of [DeBouncer] to be used for debouncing actions. It can be
/// used to debounce actions across the application. Use [debounce] function to
/// debounce actions using this instance.
///
/// CAUTION:
/// This instance will be shared across the application. If you want to have
/// different debounce settings for different actions, you should create an
/// instance of [DeBouncer] and use it for debouncing actions.
///
/// Also, it is recommended to use this instance only for simple use cases where
/// you don't need to debounce 2 different actions at the same time! Otherwise,
/// it will cause conflicts between the actions and you may not get the desired
/// results. If you need to debounce multiple actions, you should create an
/// instance of [DeBouncer] for each action.
///
/// See [debounce] function for more details.
final DeBouncer debouncer = DeBouncer();

/// Helper function to debounce [action] calls using global [deBouncer] instance.
/// If [immediateFirstRun] is set to true, it will run the [action] immediately
/// for the first call and then it will wait for [duration] to run the next call
/// if there's any.
///
/// This is helpful when you want to debounce a method call without creating an
/// instance of [DeBouncer] class. However, you can create an instance of
/// [DeBouncer] and use it for debouncing actions as well.
///
/// CAUTION:
/// This function will use the global instance of [DeBouncer] and it will be
/// shared across the application. If you want to have different debounce
/// settings for different actions, you should create an instance of
/// [DeBouncer] and use it for debouncing actions.
///
/// Also, it is recommended to
/// use this function only for simple use cases where you don't need to
/// debounce 2 different actions at the same time! Otherwise, it will cause
/// conflicts between the actions and you may not get the desired results.
/// If you need to debounce multiple actions, you should create an instance
/// of [DeBouncer] for each action.
///
/// To cancel the current timer, you can call [DeBouncer.cancel] method on
/// the global instance of [deBouncer].
///
/// e.g.
/// ```dart
/// // Using global instance of deBouncer to debounce actions.
/// debounce(() {
///   // your action here
///   print('debounced action');
/// });
/// ```
///
/// ```dart
/// debouncer.cancel(); // cancels the current action on global instance.
/// ```
///
/// This will run the action immediately for the first call and then it will
/// wait for 300 milliseconds to run the next call if there's any.
Future<R> debounce<R>(DeBounceAction<R> action,
        {bool immediateFirstRun = false}) =>
    debouncer.run<R>(action, immediateFirstRun: immediateFirstRun);
