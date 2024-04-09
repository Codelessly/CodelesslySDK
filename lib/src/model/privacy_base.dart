import 'package:codelessly_api/codelessly_api.dart';
import 'package:equatable/equatable.dart';

enum Role {
  owner('Admin'),
  editor('Editor'),
  viewer('Viewer');

  final String label;

  const Role(this.label);

  String get article => switch (this) {
        owner || editor => 'an',
        viewer => 'a',
      };

  /// ----------------- POWER HIERARCHY -----------------

  bool isHigherLevelThan(Role other) => switch (this) {
        owner => other != owner,
        editor => other == viewer,
        viewer => false,
      };

  bool isHigherOrEqualLevelThan(Role other) =>
      isHigherLevelThan(other) || this == other;

  bool isLowerLevelThan(Role other) => !isHigherLevelThan(other);

  bool isLowerOrEqualLevelThan(Role other) =>
      isLowerLevelThan(other) || this == other;

  bool get isLowestLevel => this == viewer;

  bool get isHighestLevel => this == owner;

  /// ----------------- PERMISSIONS -----------------

  /// Only owners can modify project metadata.
  bool get canManageProject => switch (this) {
        owner => true,
        editor || viewer => false,
      };

  /// Only owners and editors can edit projects.
  bool get canEditProject => switch (this) {
        owner || editor => true,
        viewer => false,
      };

  /// Only owners and editors can manage team members.
  bool get canManageTeam => switch (this) {
        owner || editor => true,
        viewer => false,
      };

  /// Anyone can manage project members.
  bool get canManageProjectMembers => true;
}

/// Represents the privacy controls of a given model that this mixin
/// is applied to.
abstract class PrivacyBase with SerializableMixin, EquatableMixin {
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

  /// An owner ID must always exist in the roles map. It's an error
  /// if it doesn't.
  Set<String> get owners =>
      roles.keys.where((id) => roles[id] == Role.owner).toSet();

  /// A list of user ids that are editors of this object.
  List<String> get editors => roles.entries
      .where((entry) => entry.value == Role.editor)
      .map((entry) => entry.key)
      .toList();

  /// A list of user ids that are viewers of this object.
  List<String> get viewers => roles.entries
      .where((entry) => entry.value == Role.viewer)
      .map((entry) => entry.key)
      .toList();

  /// Creates a new [PrivacyBase] with the given parameters.
  const PrivacyBase({
    required Set<String>? teams,
    required Set<String>? users,
    required this.roles,
    required bool? public,
  })  : teams = teams ?? const {},
        users = users ?? const {},
        public = public ?? false;

  /// Creates a new [PrivacyBase] derived from another [PrivacyBase].
  PrivacyBase.private({required PrivacyBase privacy})
      : this(
          teams: privacy.teams,
          users: privacy.users,
          roles: privacy.roles,
          public: privacy.public,
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
  ///   ...privacyBase.toMinimalJson(),
  /// }
  Map<String, dynamic> toMinimalPrivacyJson() => {
        'users': users.toList(),
        'roles': {
          for (final MapEntry(:key, :value) in roles.entries) key: value.name,
        },
        'teams': teams.toList(),
        'public': public,
      };

  @override
  List<Object?> get props => [users, roles, teams, public];
}
