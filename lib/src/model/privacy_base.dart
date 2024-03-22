import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_json_annotation/codelessly_json_annotation.dart';
import 'package:equatable/equatable.dart';

enum Role {
  owner('Owner'),
  editor('Editor'),
  viewer('Viewer');

  final String label;

  const Role(this.label);
}

/// Represents the privacy controls of a given model that this mixin
/// is applied to.
abstract class PrivacyBase with SerializableMixin, EquatableMixin {
  /// Backwards compatibility for the old owner field.
  static Object? readRole(Map<dynamic, dynamic> json, String? key) {
    if (json.containsKey('owner')) {
      return {
        json['owner']: Role.owner.name,
      };
    }
    return json[key];
  }

  /// A set of user ids that are allowed to access the project in some way
  /// defined by the [roles] map.
  final Set<String> users;

  /// The roles of each user from the [users] set.
  @JsonKey(readValue: readRole)
  final Map<String, Role> roles;

  /// The list of teams associated with a particular document.
  final Set<String> teams;

  /// Whether the object is public or not. If it is public, then
  /// it is accessible to read by anyone on the platform.
  final bool public;

  /// An owner ID must always exist in the roles map. It's an error
  /// if it doesn't.
  String get owner => roles.keys.firstWhere((id) => roles[id] == Role.owner);

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

  // assert(
  //   roles.containsValue(Role.owner),
  //   'An owner must exist in the roles map.',
  // );

  /// Creates a new [PrivacyBase] derived from another [PrivacyBase].
  PrivacyBase.private({required PrivacyBase privacy})
      : this(
          teams: privacy.teams,
          users: privacy.users,
          roles: privacy.roles,
          public: privacy.public,
        );

  @override
  List<Object?> get props => [users, roles, teams, public];
}
