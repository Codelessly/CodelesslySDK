// import 'functions.dart';

// /// Alias of AsyncCallback.
// /// Example:
// ///   Future<void> onTap();
// class AsyncCallbackFunction extends CodelesslyFunction {
//   final Future<void> Function() callback;

//   AsyncCallbackFunction(this.callback);

//   void call() => callback();
// }

// /// An async wrapper for a function that takes a single parameter as an input and
// /// returns nothing.
// /// Example:
// ///   Future<void> onChanged(bool value);
// ///
// /// Must provide generic type to avoid runtime errors.
// class AsyncReturningFunction<R> extends CodelesslyFunction {
//   final Future<R> Function() callback;

//   AsyncReturningFunction(this.callback);

//   Future<R> call() async => await callback();
// }

// /// An async wrapper for a function that takes nothing as an input and
// /// returns something as output.
// /// Example:
// ///   Future<bool> isSelected();
// ///
// /// Must provide generic type to avoid runtime errors.
// class AsyncValueFunction<T> extends CodelesslyFunction {
//   final Future<void> Function(T t) callback;

//   AsyncValueFunction(this.callback);

//   void call(T t) async => await callback(t);
// }

// /// An async wrapper for a function that takes a single parameter as an input and
// /// returns something as an output.
// /// Generic type [T] refers to an input and [R] refers to an output.
// ///
// /// Example:
// ///   Future<bool> isValidEmail(String email);
// ///
// /// Must provide generic type to avoid runtime errors.
// class AsyncValueReturningFunction<T, R> extends CodelesslyFunction {
//   final Future<R> Function(T t) callback;

//   AsyncValueReturningFunction(this.callback);

//   Future<R> call(T t) async => await callback(t);
// }

// /// An async wrapper for a function that takes two parameters as an input and
// /// returns something as an output.
// /// Generic type [T1] and [T2] are parameter types and [R] is a return type.
// ///
// /// Example:
// ///   Future<double> sum(int value1, double value2);
// ///
// /// Must provide generic type to avoid runtime errors.
// class AsyncValue2ReturningFunction<T1, T2, R> extends CodelesslyFunction {
//   final Future<R> Function(T1 t1, T2 t2) callback;

//   AsyncValue2ReturningFunction(this.callback);

//   Future<R> call(T1 t1, T2 t2) async => await callback(t1, t2);
// }

// /// An Async wrapper for a function that takes three parameters as an input and
// /// returns something as an output.
// /// Generic type [T1], [T2] and [T3] are parameter types and [R] is
// /// a return type.
// ///
// /// Example:
// ///   Future<bool> isBetween(int start, int end, int value);
// ///
// /// Must provide generic type to avoid runtime errors.
// class AsyncValue3ReturningFunction<T1, T2, T3, R> extends CodelesslyFunction {
//   final Future<R> Function(T1 t1, T2 t2, T3 t3) callback;

//   AsyncValue3ReturningFunction(this.callback);

//   Future<R> call(T1 t1, T2 t2, T3 t3) async => await callback(t1, t2, t3);
// }
