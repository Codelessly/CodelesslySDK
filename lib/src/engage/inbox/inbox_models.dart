// The inbox's data on the device: cards, their actions, the remotely managed
// configuration, and the controller's state. Mirrors the backend's contract
// in CodelesslyEditor firebase/functions/src/engage/inbox/model.ts.
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// How a card is drawn by the default UI.
enum InboxCardType {
  /// Title, body and an optional thumbnail.
  classic,

  /// A wide image above the title and body.
  captioned,

  /// The image alone.
  image,

  /// A highlighted card with up to two buttons.
  announcement,

  /// A holdout: never drawn, but its impression is logged so the editor
  /// can compare it with the cards that were shown.
  control;

  static InboxCardType parse(Object? value) => InboxCardType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => InboxCardType.classic,
  );
}

/// What an action does when tapped.
enum InboxActionKind {
  /// Opens an http(s) URL through the app's `openUrl` callback.
  url,

  /// Opens an app deep link through the app's `openUrl` callback.
  deeplink,

  /// Hands a key to the app's `onCustomAction` callback.
  custom,

  /// Removes the card from the inbox.
  dismiss;

  static InboxActionKind parse(Object? value) => InboxActionKind.values
      .firstWhere((t) => t.name == value, orElse: () => InboxActionKind.url);
}

/// A button on a card, or what a tap on the card itself does.
@immutable
class InboxAction {
  const InboxAction({
    required this.id,
    required this.kind,
    this.label = '',
    this.value = '',
  });

  final String id;
  final String label;
  final InboxActionKind kind;

  /// The URL, deep link or custom key; empty for [InboxActionKind.dismiss].
  final String value;

  /// [value] as a URI, for url and deeplink actions.
  Uri? get uri =>
      kind == InboxActionKind.url || kind == InboxActionKind.deeplink
      ? Uri.tryParse(value)
      : null;

  static InboxAction? fromJson(Object? json) {
    if (json is! Map) return null;
    return InboxAction(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      kind: InboxActionKind.parse(json['kind']),
      value: json['value']?.toString() ?? '',
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'kind': kind.name,
    'value': value,
  };

  @override
  bool operator ==(Object other) =>
      other is InboxAction &&
      other.id == id &&
      other.label == label &&
      other.kind == kind &&
      other.value == value;

  @override
  int get hashCode => Object.hash(id, label, kind, value);
}

/// One content card in a user's inbox, personalized by the server.
@immutable
class InboxCard {
  const InboxCard({
    required this.id,
    this.type = InboxCardType.classic,
    this.title = '',
    this.body = '',
    this.imageUrl = '',
    this.imageAspectRatio = 2,
    this.tap,
    this.actions = const [],
    this.pinned = false,
    this.dismissible = true,
    this.priority = 0,
    this.category = '',
    this.tags = const [],
    this.extras = const {},
    this.layoutId = '',
    this.sentAt,
    this.expiresAt,
    this.read = false,
    this.clicked = false,
    this.version = 0,
  });

  final String id;
  final InboxCardType type;
  final String title;
  final String body;
  final String imageUrl;

  /// Width over height of the image, for its placeholder.
  final double imageAspectRatio;

  /// What a tap on the card does; null when only its buttons act.
  final InboxAction? tap;

  /// At most two buttons.
  final List<InboxAction> actions;
  final bool pinned;
  final bool dismissible;
  final int priority;
  final String category;
  final List<String> tags;

  /// Custom key-value data set in the editor, for the app's own use.
  final Map<String, Object?> extras;

  /// A Codelessly layout that draws this card instead of the default UI.
  final String layoutId;
  final DateTime? sentAt;
  final DateTime? expiresAt;
  final bool read;
  final bool clicked;
  final int version;

  bool get isControl => type == InboxCardType.control;
  bool get hasImage => imageUrl.isNotEmpty;

  /// Whether the card has expired at [now].
  bool expiredAt(DateTime now) =>
      expiresAt != null && !now.isBefore(expiresAt!);

  InboxCard copyWith({bool? read, bool? clicked}) => InboxCard(
    id: id,
    type: type,
    title: title,
    body: body,
    imageUrl: imageUrl,
    imageAspectRatio: imageAspectRatio,
    tap: tap,
    actions: actions,
    pinned: pinned,
    dismissible: dismissible,
    priority: priority,
    category: category,
    tags: tags,
    extras: extras,
    layoutId: layoutId,
    sentAt: sentAt,
    expiresAt: expiresAt,
    read: read ?? this.read,
    clicked: clicked ?? this.clicked,
    version: version,
  );

  static InboxCard? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    final ratio = json['imageAspectRatio'];
    return InboxCard(
      id: json['id'] as String,
      type: InboxCardType.parse(json['type']),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      imageAspectRatio: ratio is num && ratio > 0 ? ratio.toDouble() : 2,
      tap: InboxAction.fromJson(json['tap']),
      actions: [
        for (final a in (json['actions'] as List?) ?? const [])
          ?InboxAction.fromJson(a),
      ],
      pinned: json['pinned'] == true,
      dismissible: json['dismissible'] != false,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      category: json['category']?.toString() ?? '',
      tags: [for (final t in (json['tags'] as List?) ?? const []) '$t'],
      extras: json['extras'] is Map
          ? Map<String, Object?>.from(json['extras'] as Map)
          : const {},
      layoutId: json['layoutId']?.toString() ?? '',
      sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
      read: json['read'] == true,
      clicked: json['clicked'] == true,
      version: (json['version'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'imageUrl': imageUrl,
    'imageAspectRatio': imageAspectRatio,
    'tap': tap?.toJson(),
    'actions': [for (final a in actions) a.toJson()],
    'pinned': pinned,
    'dismissible': dismissible,
    'priority': priority,
    'category': category,
    'tags': tags,
    'extras': extras,
    'layoutId': layoutId,
    'sentAt': sentAt?.toUtc().toIso8601String(),
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'read': read,
    'clicked': clicked,
    'version': version,
  };

  /// The card as a Codelessly layout binds it: `card.title`,
  /// `card.actions[0].label`, `card.hasImage`, `card.extras.sku`.
  Map<String, Object?> toValue() => {
    ...toJson(),
    'unread': !read,
    'hasImage': hasImage,
    'hasActions': actions.isNotEmpty,
    'action1': actions.isNotEmpty ? actions[0].toJson() : null,
    'action2': actions.length > 1 ? actions[1].toJson() : null,
  };

  @override
  bool operator ==(Object other) =>
      other is InboxCard &&
      other.id == id &&
      other.version == version &&
      other.read == read &&
      other.clicked == clicked &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, version, read, clicked, title, body);
}

/// The default UI's look, managed from the editor. Every field is optional;
/// unset fields follow the app's [ThemeData].
@immutable
class InboxUiConfig {
  const InboxUiConfig({
    this.title,
    this.emptyTitle,
    this.emptyBody,
    this.pinnedLabel,
    this.markAllReadLabel,
    this.showMarkAllRead = true,
    this.showCategories = false,
    this.accentColor,
    this.backgroundColor,
    this.cardColor,
    this.titleColor,
    this.bodyColor,
    this.unreadColor,
    this.darkAccentColor,
    this.darkBackgroundColor,
    this.darkCardColor,
    this.darkTitleColor,
    this.darkBodyColor,
    this.darkUnreadColor,
    this.cornerRadius,
    this.cardSpacing,
    this.imageAspectRatio,
    this.dense = false,
    this.swipeToDismiss = true,
    this.layoutId,
    this.cardLayoutId,
  });

  final String? title;
  final String? emptyTitle;
  final String? emptyBody;
  final String? pinnedLabel;
  final String? markAllReadLabel;
  final bool showMarkAllRead;
  final bool showCategories;
  final Color? accentColor;
  final Color? backgroundColor;
  final Color? cardColor;
  final Color? titleColor;
  final Color? bodyColor;
  final Color? unreadColor;
  final Color? darkAccentColor;
  final Color? darkBackgroundColor;
  final Color? darkCardColor;
  final Color? darkTitleColor;
  final Color? darkBodyColor;
  final Color? darkUnreadColor;
  final double? cornerRadius;
  final double? cardSpacing;
  final double? imageAspectRatio;
  final bool dense;
  final bool swipeToDismiss;

  /// A Codelessly layout for the whole inbox.
  final String? layoutId;

  /// A Codelessly layout for each card without its own layout.
  final String? cardLayoutId;

  static Color? _color(Object? value) {
    if (value is! String) return null;
    final hex = value.replaceFirst('#', '');
    final n = int.tryParse(hex, radix: 16);
    if (n == null) return null;
    if (hex.length == 6) return Color(0xFF000000 | n);
    if (hex.length == 8) {
      // #AARRGGBB
      return Color(n);
    }
    return null;
  }

  static String? _text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static double? _num(Object? value) => value is num ? value.toDouble() : null;

  factory InboxUiConfig.fromJson(Object? json) {
    if (json is! Map) return const InboxUiConfig();
    return InboxUiConfig(
      title: _text(json['title']),
      emptyTitle: _text(json['emptyTitle']),
      emptyBody: _text(json['emptyBody']),
      pinnedLabel: _text(json['pinnedLabel']),
      markAllReadLabel: _text(json['markAllReadLabel']),
      showMarkAllRead: json['showMarkAllRead'] != false,
      showCategories: json['showCategories'] == true,
      accentColor: _color(json['accentColor']),
      backgroundColor: _color(json['backgroundColor']),
      cardColor: _color(json['cardColor']),
      titleColor: _color(json['titleColor']),
      bodyColor: _color(json['bodyColor']),
      unreadColor: _color(json['unreadColor']),
      darkAccentColor: _color(json['darkAccentColor']),
      darkBackgroundColor: _color(json['darkBackgroundColor']),
      darkCardColor: _color(json['darkCardColor']),
      darkTitleColor: _color(json['darkTitleColor']),
      darkBodyColor: _color(json['darkBodyColor']),
      darkUnreadColor: _color(json['darkUnreadColor']),
      cornerRadius: _num(json['cornerRadius']),
      cardSpacing: _num(json['cardSpacing']),
      imageAspectRatio: _num(json['imageAspectRatio']),
      dense: json['dense'] == true,
      swipeToDismiss: json['swipeToDismiss'] != false,
      layoutId: _text(json['layoutId']),
      cardLayoutId: _text(json['cardLayoutId']),
    );
  }
}

/// The inbox's remotely managed configuration.
@immutable
class InboxConfig {
  const InboxConfig({
    this.refreshInterval = const Duration(minutes: 5),
    this.minRefreshInterval = const Duration(seconds: 10),
    this.ui = const InboxUiConfig(),
    this.version = 0,
    this.raw = const {},
  });

  /// How long fetched cards stay fresh before the inbox refreshes on its own.
  final Duration refreshInterval;

  /// The shortest gap between two refreshes, even forced ones.
  final Duration minRefreshInterval;
  final InboxUiConfig ui;
  final int version;

  /// The JSON this config came from, for caching.
  final Map<String, Object?> raw;

  factory InboxConfig.fromJson(Object? json) {
    if (json is! Map) return const InboxConfig();
    final refresh = (json['refreshIntervalSeconds'] as num?)?.toInt() ?? 300;
    final min = (json['minRefreshSeconds'] as num?)?.toInt() ?? 10;
    return InboxConfig(
      refreshInterval: Duration(seconds: refresh.clamp(30, 86400)),
      minRefreshInterval: Duration(seconds: min.clamp(0, 3600)),
      ui: InboxUiConfig.fromJson(json['ui']),
      version: (json['version'] as num?)?.toInt() ?? 0,
      raw: Map<String, Object?>.from(json),
    );
  }
}

/// A snapshot of the inbox, as [CodelesslyInbox.state] reports it.
@immutable
class InboxState {
  const InboxState({
    this.cards = const [],
    this.unreadCount = 0,
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.available = true,
    this.fromCache = false,
    this.error,
    this.lastUpdated,
  });

  /// The cards to show: pinned first, then by priority, then newest.
  /// Control cards, dismissed and expired cards are not in it.
  final List<InboxCard> cards;
  final int unreadCount;

  /// A refresh is running.
  final bool loading;
  final bool loadingMore;

  /// More cards can be loaded with [CodelesslyInbox.loadMore].
  final bool hasMore;

  /// False when the backend is unreachable and nothing is cached: the inbox
  /// shows its empty state and does nothing else.
  final bool available;

  /// The cards came from the device cache, not (yet) from the server.
  final bool fromCache;

  /// Why the last refresh failed, for display; null when it succeeded.
  final String? error;
  final DateTime? lastUpdated;

  bool get isEmpty => cards.isEmpty;
  List<InboxCard> get pinned => [
    for (final c in cards)
      if (c.pinned) c,
  ];
  List<InboxCard> get unpinned => [
    for (final c in cards)
      if (!c.pinned) c,
  ];

  InboxState copyWith({
    List<InboxCard>? cards,
    int? unreadCount,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    bool? available,
    bool? fromCache,
    String? error,
    bool clearError = false,
    DateTime? lastUpdated,
  }) => InboxState(
    cards: cards ?? this.cards,
    unreadCount: unreadCount ?? this.unreadCount,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    available: available ?? this.available,
    fromCache: fromCache ?? this.fromCache,
    error: clearError ? null : (error ?? this.error),
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );

  /// The inbox as a Codelessly layout binds it: `inbox.unread`,
  /// `inbox.loading`, `inbox.empty`.
  Map<String, Object?> toValue({String? category, String? title}) => {
    'unread': unreadCount,
    'loading': loading,
    'loadingMore': loadingMore,
    'empty': cards.isEmpty,
    'hasMore': hasMore,
    'error': error,
    'available': available,
    'category': category,
    'title': title,
  };
}

/// What was tapped, handed to the app's tap callback.
@immutable
class InboxCardTap {
  const InboxCardTap(this.card, this.action);
  final InboxCard card;

  /// The button, or the card's own tap action. Null when the card has no
  /// tap action and was tapped anyway.
  final InboxAction? action;

  InboxActionKind? get kind => action?.kind;
  Uri? get uri => action?.uri;

  /// The custom action key, for [InboxActionKind.custom].
  String? get key =>
      action?.kind == InboxActionKind.custom ? action!.value : null;
}
