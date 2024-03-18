import 'package:codelessly_api/codelessly_api.dart';
import 'package:equatable/equatable.dart';

/// Represents the privacy controls of a given model that this mixin
/// is applied to.
abstract class PrivacyBase with SerializableMixin, EquatableMixin {
  /// The id of the owner user of the object.
  final String owner;

  /// The team that this object belongs to.
  final String? team;

  /// The ids of the users that can edit the object.
  final Set<String> editors;

  /// The ids of the users that can view the object.
  final Set<String> viewers;

  Set<String> get whitelistedUsers => {owner, ...editors, ...viewers};

  /// Whether the object is public or not. If it is public, then
  /// it is accessible to read by anyone on the platform.
  final bool public;

  /// Creates a new [PrivacyBase] with the given parameters.
  const PrivacyBase({
    required this.owner,
    this.team,
    Set<String>? editors,
    Set<String>? viewers,
    this.public = false,
  })  : editors = editors ?? const <String>{},
        viewers = viewers ?? const <String>{};

  /// Returns a new instance of this object but with the properties from
  /// the given [PrivacyBase] object.
  PrivacyBase copyWithPrivacyFrom(PrivacyBase privacy);

  @override
  List<Object?> get props => [owner, team, editors, viewers, public];
}
