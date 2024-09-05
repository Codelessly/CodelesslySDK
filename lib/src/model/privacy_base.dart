import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_json_annotation/codelessly_json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'privacy_base.g.dart';

enum Role {
  admin('Admin'),
  editor('Editor'),
  viewer('Viewer');

  final String label;

  const Role(this.label);

  /// ----------------- POWER HIERARCHY -----------------

  bool isHigherLevelThan(Role other) => switch (this) {
        admin => other != admin,
        editor => other == viewer,
        viewer => false,
      };

  bool isHigherOrEqualLevelThan(Role other) =>
      isHigherLevelThan(other) || this == other;

  bool isLowerLevelThan(Role other) => !isHigherLevelThan(other);

  bool isLowerOrEqualLevelThan(Role other) =>
      isLowerLevelThan(other) || this == other;

  bool get isLowestLevel => this == viewer;

  bool get isHighestLevel => this == admin;

  /// ----------------- PERMISSIONS -----------------

  /// Only admins can modify project metadata.
  bool get canManageProject => switch (this) {
        admin => true,
        editor || viewer => false,
      };

  /// Only admins and editors can edit projects.
  bool get canEditProject => switch (this) {
        admin || editor => true,
        viewer => false,
      };

  /// Only admins and editors can manage team members.
  bool get canManageTeam => switch (this) {
        admin || editor => true,
        viewer => false,
      };

  /// Anyone can manage project members.
  bool get canManageProjectMembers => true;
}

/// Represents the privacy controls of a given model that this mixin
/// is applied to.
abstract class PrivacyBase with SerializableMixin, EquatableMixin {
  /// The owner of the document. The owner is the user who is responsible for
  /// the document and has the highest level of access to it. In terms of
  /// permissions, it's equivalent to the [Role.admin] role, however this owner
  /// is responsible for billing and other administrative tasks.
  final String owner;

  /// A set of user ids that are allowed to access the project in some way
  /// defined by the [roles] map.
  final Set<String> users;

  /// The roles of each user from the [users] set.
  final Map<String, Role> roles;

  /// The list of teams associated with a particular document.
  final Set<String> teams;

  /// Whether the object is public or not. If it is public, then
  /// it is accessible to read by anyone on the platform.
  final bool public;

  /// Creates a new [PrivacyBase] with the given parameters.
  factory PrivacyBase.from({
    required String owner,
    required Set<String> teams,
    required Set<String> users,
    required Map<String, Role> roles,
    required bool public,
  }) =>
      _PrivacyBaseImpl(
        owner: owner,
        teams: teams,
        users: users,
        roles: roles,
        public: public,
      );

  /// An owner ID must always exist in the roles map. It's an error
  /// if it doesn't.
  @JsonKey(includeFromJson: false, includeToJson: false)
  Set<String> get admins =>
      roles.keys.where((id) => roles[id] == Role.admin).toSet();

  /// A list of user ids that are editors of this object.
  @JsonKey(includeFromJson: false, includeToJson: false)
  List<String> get editors => roles.entries
      .where((entry) => entry.value == Role.editor)
      .map((entry) => entry.key)
      .toList();

  /// A list of user ids that are viewers of this object.
  @JsonKey(includeFromJson: false, includeToJson: false)
  List<String> get viewers => roles.entries
      .where((entry) => entry.value == Role.viewer)
      .map((entry) => entry.key)
      .toList();

  /// Creates a new [PrivacyBase] with the given parameters.
  const PrivacyBase({
    required this.owner,
    required Set<String>? teams,
    required Set<String>? users,
    required this.roles,
    required bool? public,
  })  : teams = teams ?? const {},
        users = users ?? const {},
        public = public ?? false;

  /// Creates a new [PrivacyBase] derived from another [PrivacyBase].
  PrivacyBase.private({required PrivacyBase privacy, bool? public})
      : this(
          owner: privacy.owner,
          teams: privacy.teams,
          users: privacy.users,
          roles: privacy.roles,
          public: public ?? privacy.public,
        );

  /// While this PrivacyBase object is extended by other models, calling
  /// toJson on those models will return data in addition to these core
  /// privacy properties.
  ///
  /// This function, however, will only return the core privacy properties
  /// by themselves. It's useful when you need to append these properties to
  /// a map manually, e.g:
  ///
  /// dataWithPrivacy: {
  ///   someKeys: someValues,
  ///   ...privacyBase.privacy.toJson(),
  /// }
  @JsonKey(includeFromJson: false, includeToJson: false)
  PrivacyBase get privacy => _PrivacyBaseImpl(
        owner: owner,
        teams: teams,
        users: users,
        roles: roles,
        public: public,
      );

  @override
  List<Object?> get props => [users, roles, teams, public];
}

/// A base implementation of the [PrivacyBase] to extract privacy fields from
/// an inherited model without worrying about the other fields that may be
/// present in the model.
@JsonSerializable()
final class _PrivacyBaseImpl extends PrivacyBase {
  const _PrivacyBaseImpl({
    required super.owner,
    required super.teams,
    required super.users,
    required super.roles,
    required super.public,
  });

  @override
  Map toJson() => _$PrivacyBaseImplToJson(this);
}
