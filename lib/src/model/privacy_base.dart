import 'package:equatable/equatable.dart';

/// Represents the privacy controls of a given model that this mixin
/// is applied to.
abstract class PrivacyBase with EquatableMixin {
  /// The id of the owner user of the object.
  final String owner;

  /// The ids of the users that can edit the object.
  final Set<String> editors;

  /// The ids of the users that can view the object.
  final Set<String> viewers;

  /// Whether the object is public or not. If it is public, then
  /// it is accessible to read by anyone.
  final bool public;

  /// Creates a new [PrivacyBase] with the given parameters.
  const PrivacyBase({
    required this.owner,
    Set<String>? editors,
    Set<String>? viewers,
    this.public = false,
  }) : editors = editors ?? const <String>{},
       viewers = viewers ?? const <String>{};

  @override
  List<Object?> get props => [owner, editors, viewers, public];
}
