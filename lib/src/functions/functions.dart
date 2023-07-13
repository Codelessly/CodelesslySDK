import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../codelessly_sdk.dart';

/// A function signature passing functions into [CodelesslyWidget].
typedef CodelesslyFunction<T> = FutureOr<T> Function(
    BuildContext context, CodelesslyContext reference);

/// Alias of VoidCallback.
/// Example:
///   void onTap();
// class CallbackFunction extends CodelesslyFunction {
//   final void Function() callback;

//   CallbackFunction(this.callback);

//   void call() => callback();
// }

// /// A wrapper for a function that takes a single parameter as an input and
// /// returns nothing.
// /// Example:
// ///   void onChanged(bool value);
// ///
// /// Must provide generic type to avoid runtime errors.
// class ValueFunction<T> extends CodelesslyFunction {
//   final void Function(T t) callback;

//   ValueFunction(this.callback);

//   void call(T t) => callback(t);
// }

// /// A wrapper for a function that takes nothing as an input and
// /// returns something as output.
// /// Example:
// ///   bool isSelected();
// ///
// /// Must provide generic type to avoid runtime errors.
// class ReturningFunction<R> extends CodelesslyFunction {
//   final R Function() callback;

//   ReturningFunction(this.callback);

//   R call() => callback();
// }

// /// A wrapper for a function that takes a single parameter as an input and
// /// returns something as an output.
// /// Generic type [T] refers to an input and [R] refers to an output.
// ///
// /// Example:
// ///   bool isValidEmail(String email);
// ///
// /// Must provide generic type to avoid runtime errors.
// class ValueReturningFunction<T, R> extends CodelesslyFunction {
//   final R Function(T t) callback;

//   ValueReturningFunction(this.callback);

//   R call(T t) => callback(t);
// }

// /// A wrapper for a function that takes two parameters as an input and
// /// returns something as an output.
// /// Generic type [T1] and [T2] are parameter types and [R] is a return type.
// ///
// /// Example:
// ///   double sum(int value1, double value2);
// ///
// /// Must provide generic type to avoid runtime errors.
// class Value2ReturningFunction<T1, T2, R> extends CodelesslyFunction {
//   final R Function(T1 t1, T2 t2) callback;

//   Value2ReturningFunction(this.callback);

//   R call(T1 t1, T2 t2) => callback(t1, t2);
// }

// /// A wrapper for a function that takes three parameters as an input and
// /// returns something as an output.
// /// Generic type [T1], [T2] and [T3] are parameter types and [R] is
// /// a return type.
// ///
// /// Example:
// ///   bool isBetween(int start, int end, int value);
// ///
// /// Must provide generic type to avoid runtime errors.
// class Value3ReturningFunction<T1, T2, T3, R> extends CodelesslyFunction {
//   final R Function(T1 t1, T2 t2, T3 t3) callback;

//   Value3ReturningFunction(this.callback);

//   R call(T1 t1, T2 t2, T3 t3) => callback(t1, t2, t3);
// }
