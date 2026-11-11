// The inbox's default UI: an embeddable list, a card, an unread badge and a
// full-screen presenter. Theme-aware (light and dark, the app's ThemeData),
// overridable by the editor's remote UI config, and replaceable by a
// Codelessly layout through CodelesslyInbox.layoutBuilder.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'inbox_controller.dart';
import 'inbox_models.dart';

/// Builds a card's image; the default is [Image.network] with a placeholder.
/// Apps with an image cache (cached_network_image) can pass their own.
typedef InboxImageBuilder =
    Widget Function(BuildContext context, String url, double aspectRatio);

/// Builds one card in place of [CodelesslyInboxCard].
typedef InboxCardBuilder =
    Widget Function(
      BuildContext context,
      InboxCard card,
      CodelesslyInbox inbox,
    );

/// The colors and sizes the default UI uses: the remote config where set,
/// else the app's theme.
@immutable
class InboxStyle {
  const InboxStyle({
    required this.accent,
    required this.background,
    required this.card,
    required this.title,
    required this.body,
    required this.unread,
    required this.muted,
    required this.radius,
    required this.spacing,
    required this.dense,
  });

  final Color accent;
  final Color background;
  final Color card;
  final Color title;
  final Color body;
  final Color unread;
  final Color muted;
  final double radius;
  final double spacing;
  final bool dense;

  factory InboxStyle.of(BuildContext context, InboxUiConfig ui) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    Color pick(Color? light, Color? darkValue, Color fallback) =>
        (dark ? darkValue : light) ?? fallback;
    final accent = pick(ui.accentColor, ui.darkAccentColor, scheme.primary);
    return InboxStyle(
      accent: accent,
      background: pick(
        ui.backgroundColor,
        ui.darkBackgroundColor,
        scheme.surface,
      ),
      card: pick(ui.cardColor, ui.darkCardColor, scheme.surfaceContainerLow),
      title: pick(ui.titleColor, ui.darkTitleColor, scheme.onSurface),
      body: pick(ui.bodyColor, ui.darkBodyColor, scheme.onSurfaceVariant),
      unread: pick(ui.unreadColor, ui.darkUnreadColor, accent),
      muted: scheme.outline,
      radius: ui.cornerRadius ?? 16,
      spacing: ui.cardSpacing ?? (ui.dense ? 8 : 12),
      dense: ui.dense,
    );
  }
}

/// A short "time ago" label for a card.
String inboxTimeAgo(DateTime? at, DateTime now) {
  if (at == null) return '';
  final d = now.difference(at);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  if (d.inDays < 365) return '${(d.inDays / 7).floor()}w';
  return '${(d.inDays / 365).floor()}y';
}

/// The user's inbox as an embeddable list: pull to refresh, a pinned
/// section, swipe to dismiss, an empty state, impressions logged as cards
/// come into view, and taps handled through [onCardTap] and the inbox's
/// callbacks.
///
/// ```dart
/// CodelesslyInboxView(inbox: inbox)
/// ```
class CodelesslyInboxView extends StatefulWidget {
  const CodelesslyInboxView({
    super.key,
    required this.inbox,
    this.onCardTap,
    this.category,
    this.padding,
    this.cardBuilder,
    this.emptyBuilder,
    this.imageBuilder,
    this.refreshOnOpen = true,
  });

  final CodelesslyInbox inbox;

  /// Sees every tap first; return true to skip the default handling.
  final InboxCardTapHandler? onCardTap;

  /// Shows only cards of this category.
  final String? category;
  final EdgeInsetsGeometry? padding;
  final InboxCardBuilder? cardBuilder;
  final WidgetBuilder? emptyBuilder;
  final InboxImageBuilder? imageBuilder;

  /// Refreshes when shown, if the cards are older than the configured
  /// refresh interval.
  final bool refreshOnOpen;

  @override
  State<CodelesslyInboxView> createState() => _CodelesslyInboxViewState();
}

class _CodelesslyInboxViewState extends State<CodelesslyInboxView> {
  @override
  void initState() {
    super.initState();
    widget.inbox.opened();
    if (widget.refreshOnOpen) unawaited(widget.inbox.refresh());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InboxState>(
      valueListenable: widget.inbox.state,
      builder: (context, state, _) {
        final ui = widget.inbox.config.ui;
        final cards = widget.category == null
            ? state.cards
            : [
                for (final c in state.cards)
                  if (c.category == widget.category) c,
              ];
        final layoutId = ui.layoutId;
        final builder = CodelesslyInbox.layoutBuilder;
        if (layoutId != null && builder != null) {
          final custom = builder(
            context,
            InboxLayoutRequest(
              layoutId: layoutId,
              inbox: widget.inbox,
              data: {
                'cards': [for (final c in cards) c.toValue()],
                'pinned': [
                  for (final c in cards)
                    if (c.pinned) c.toValue(),
                ],
                'others': [
                  for (final c in cards)
                    if (!c.pinned) c.toValue(),
                ],
                'inbox': state.toValue(
                  category: widget.category,
                  title: ui.title,
                ),
              },
            ),
          );
          if (custom != null) return custom;
        }
        final style = InboxStyle.of(context, ui);
        return ColoredBox(
          color: style.background,
          child: RefreshIndicator(
            color: style.accent,
            onRefresh: () => widget.inbox.refresh(force: true),
            child: _body(context, state, cards, style, ui),
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    InboxState state,
    List<InboxCard> cards,
    InboxStyle style,
    InboxUiConfig ui,
  ) {
    if (cards.isEmpty) {
      if (state.loading && state.lastUpdated == null) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: CircularProgressIndicator()),
          ],
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child:
                  widget.emptyBuilder?.call(context) ??
                  _InboxEmpty(ui: ui, style: style, error: state.error),
            ),
          ],
        ),
      );
    }
    final pinned = [
      for (final c in cards)
        if (c.pinned) c,
    ];
    final others = [
      for (final c in cards)
        if (!c.pinned) c,
    ];
    final entries = <Object>[
      if (pinned.isNotEmpty) ui.pinnedLabel ?? 'Pinned',
      ...pinned,
      if (pinned.isNotEmpty && others.isNotEmpty) ui.title ?? 'Latest',
      ...others,
      if (state.hasMore) const _More(),
    ];
    final padding =
        widget.padding ??
        EdgeInsets.symmetric(horizontal: 16, vertical: style.spacing);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      // Build only what is on screen, so building a card means seeing it
      // (impressions are logged on build).
      // The SDK supports Flutter versions before scrollCacheExtent.
      // ignore: deprecated_member_use
      cacheExtent: 0,
      padding: padding,
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        Widget child;
        if (entry is String) {
          child = _SectionHeader(label: entry, style: style);
        } else if (entry is _More) {
          unawaited(widget.inbox.loadMore());
          child = const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        } else {
          final card = entry as InboxCard;
          final built =
              widget.cardBuilder?.call(context, card, widget.inbox) ??
              CodelesslyInboxCard(
                card: card,
                inbox: widget.inbox,
                onCardTap: widget.onCardTap,
                imageBuilder: widget.imageBuilder,
              );
          child = _Impression(
            key: ValueKey('impression-${card.id}'),
            card: card,
            inbox: widget.inbox,
            child: card.dismissible && ui.swipeToDismiss
                ? Dismissible(
                    key: ValueKey('dismiss-${card.id}'),
                    direction: DismissDirection.endToStart,
                    background: _DismissBackground(style: style),
                    onDismissed: (_) => widget.inbox.dismiss(card),
                    child: built,
                  )
                : built,
          );
          child = Padding(
            padding: EdgeInsets.only(bottom: style.spacing),
            child: child,
          );
        }
        // Readable on tablets: a centered column at most 680 wide.
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: child,
          ),
        );
      },
    );
  }
}

class _More {
  const _More();
}

/// Logs a card's impression once it is built (on screen).
class _Impression extends StatefulWidget {
  const _Impression({
    super.key,
    required this.card,
    required this.inbox,
    required this.child,
  });
  final InboxCard card;
  final CodelesslyInbox inbox;
  final Widget child;

  @override
  State<_Impression> createState() => _ImpressionState();
}

class _ImpressionState extends State<_Impression> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.inbox.logImpression(widget.card);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.style});
  final String label;
  final InboxStyle style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
    child: Semantics(
      header: true,
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: style.muted,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({required this.style});
  final InboxStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(style.radius),
      ),
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}

class _InboxEmpty extends StatelessWidget {
  const _InboxEmpty({required this.ui, required this.style, this.error});
  final InboxUiConfig ui;
  final InboxStyle style;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: style.muted),
            const SizedBox(height: 16),
            Text(
              ui.emptyTitle ?? "You're all caught up",
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(color: style.title),
            ),
            const SizedBox(height: 8),
            Text(
              ui.emptyBody ?? 'New messages will show up here.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: style.body),
            ),
          ],
        ),
      ),
    );
  }
}

/// One card, drawn by type: classic (text with a thumbnail), captioned
/// (wide image above text), image only, and announcement (highlighted, with
/// buttons). A card with a layout id renders that Codelessly layout instead,
/// when the SDK's layout builder is connected.
class CodelesslyInboxCard extends StatelessWidget {
  const CodelesslyInboxCard({
    super.key,
    required this.card,
    required this.inbox,
    this.onCardTap,
    this.imageBuilder,
  });

  final InboxCard card;
  final CodelesslyInbox inbox;
  final InboxCardTapHandler? onCardTap;
  final InboxImageBuilder? imageBuilder;

  void _tap([InboxAction? action]) =>
      unawaited(inbox.handleTap(card, action: action, onTap: onCardTap));

  @override
  Widget build(BuildContext context) {
    final ui = inbox.config.ui;
    final layoutId = card.layoutId.isNotEmpty ? card.layoutId : ui.cardLayoutId;
    final builder = CodelesslyInbox.layoutBuilder;
    if (layoutId != null && builder != null) {
      final custom = builder(
        context,
        InboxLayoutRequest(
          layoutId: layoutId,
          inbox: inbox,
          card: card,
          data: {
            'card': card.toValue(),
            'inbox': inbox.state.value.toValue(title: ui.title),
          },
        ),
      );
      if (custom != null) return custom;
    }
    final style = InboxStyle.of(context, ui);
    final announcement = card.type == InboxCardType.announcement;
    final background = announcement
        ? Color.alphaBlend(style.accent.withValues(alpha: 0.10), style.card)
        : style.card;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(style.radius),
      side: announcement
          ? BorderSide(color: style.accent.withValues(alpha: 0.35))
          : BorderSide.none,
    );
    return Semantics(
      container: true,
      customSemanticsActions: {
        if (card.dismissible)
          const CustomSemanticsAction(label: 'Dismiss'): () =>
              unawaited(inbox.dismiss(card)),
        if (!card.read)
          const CustomSemanticsAction(label: 'Mark as read'): () =>
              unawaited(inbox.markRead(card)),
      },
      child: Material(
        color: background,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _tap,
          child: switch (card.type) {
            InboxCardType.image => Semantics(
              label: card.title.isNotEmpty ? card.title : 'Image',
              image: true,
              child: _imageOnly(context, style),
            ),
            InboxCardType.captioned => _captioned(context, style),
            _ => _classic(context, style, announcement),
          },
        ),
      ),
    );
  }

  double get _ratio => card.imageAspectRatio > 0
      ? card.imageAspectRatio
      : (inbox.config.ui.imageAspectRatio ?? 2);

  Widget _image(BuildContext context, double ratio) =>
      imageBuilder?.call(context, card.imageUrl, ratio) ??
      InboxNetworkImage(url: card.imageUrl, aspectRatio: ratio);

  Widget _imageOnly(BuildContext context, InboxStyle style) => Stack(
    children: [
      _image(context, _ratio),
      if (!card.read)
        PositionedDirectional(
          top: 12,
          end: 12,
          child: _UnreadDot(color: style.unread, outlined: true),
        ),
    ],
  );

  Widget _captioned(BuildContext context, InboxStyle style) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _image(context, _ratio),
      Padding(
        padding: EdgeInsets.all(style.dense ? 12 : 16),
        child: _text(context, style, large: false),
      ),
    ],
  );

  Widget _classic(BuildContext context, InboxStyle style, bool large) {
    final thumb = card.hasImage && !large;
    return Padding(
      padding: EdgeInsets.all(style.dense ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (large && card.hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(style.radius / 2),
              child: _image(context, _ratio),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumb) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(style.radius / 2),
                  child: SizedBox.square(
                    dimension: style.dense ? 44 : 56,
                    child: _image(context, 1),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(child: _text(context, style, large: large)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _text(BuildContext context, InboxStyle style, {required bool large}) {
    final text = Theme.of(context).textTheme;
    final time = inboxTimeAgo(card.sentAt, inbox.host.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!card.read) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _UnreadDot(color: style.unread),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: card.title.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      card.title,
                      style: (large ? text.titleMedium : text.titleSmall)
                          ?.copyWith(
                            color: style.title,
                            fontWeight: card.read
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                    ),
            ),
            if (card.pinned) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.push_pin,
                size: 14,
                color: style.muted,
                semanticLabel: 'Pinned',
              ),
            ],
            if (time.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(time, style: text.labelSmall?.copyWith(color: style.muted)),
            ],
          ],
        ),
        if (card.body.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            card.body,
            maxLines: style.dense ? 3 : 6,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(color: style.body),
          ),
        ],
        if (card.actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, a) in card.actions.indexed)
                i == 0 && large
                    ? FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: style.accent,
                          foregroundColor:
                              ThemeData.estimateBrightnessForColor(
                                    style.accent,
                                  ) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                        onPressed: () => _tap(a),
                        child: Text(_label(a)),
                      )
                    : OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: style.accent,
                        ),
                        onPressed: () => _tap(a),
                        child: Text(_label(a)),
                      ),
            ],
          ),
        ],
      ],
    );
  }

  static String _label(InboxAction a) => a.label.isNotEmpty
      ? a.label
      : switch (a.kind) {
          InboxActionKind.dismiss => 'Dismiss',
          _ => 'Open',
        };
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.color, this.outlined = false});
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Unread',
    child: Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: outlined ? Border.all(color: Colors.white, width: 1.5) : null,
      ),
    ),
  );
}

/// A network image with a placeholder while it loads and when it fails.
class InboxNetworkImage extends StatelessWidget {
  const InboxNetworkImage({
    super.key,
    required this.url,
    required this.aspectRatio,
  });
  final String url;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder(IconData icon) => ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(child: Icon(icon, color: scheme.outline)),
    );
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder(Icons.image_outlined),
        errorBuilder: (context, error, stack) =>
            placeholder(Icons.broken_image_outlined),
      ),
    );
  }
}

/// Wraps [child] (an icon, usually) with the inbox's unread count.
///
/// ```dart
/// CodelesslyInboxBadge(inbox: inbox, child: const Icon(Icons.notifications_outlined))
/// ```
class CodelesslyInboxBadge extends StatelessWidget {
  const CodelesslyInboxBadge({
    super.key,
    required this.inbox,
    required this.child,
    this.showZero = false,
    this.max = 99,
    this.dot = false,
    this.backgroundColor,
    this.textColor,
  });

  final CodelesslyInbox inbox;
  final Widget child;

  /// Show the badge at zero.
  final bool showZero;

  /// Counts above this show as `max+`.
  final int max;

  /// A dot without the number.
  final bool dot;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: inbox.unreadCount,
      builder: (context, count, _) {
        final visible = count > 0 || showZero;
        final color =
            backgroundColor ??
            inbox.config.ui.unreadColor ??
            Theme.of(context).colorScheme.error;
        return Semantics(
          label: count == 1 ? '1 unread message' : '$count unread messages',
          child: Badge(
            isLabelVisible: visible,
            backgroundColor: color,
            textColor: textColor,
            label: dot ? null : Text(count > max ? '$max+' : '$count'),
            smallSize: 8,
            child: child,
          ),
        );
      },
    );
  }
}

/// The inbox as a full screen, with an app bar and "mark all read".
class CodelesslyInboxScreen extends StatelessWidget {
  const CodelesslyInboxScreen({
    super.key,
    required this.inbox,
    this.title,
    this.onCardTap,
    this.category,
  });

  final CodelesslyInbox inbox;
  final String? title;
  final InboxCardTapHandler? onCardTap;
  final String? category;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InboxState>(
      valueListenable: inbox.state,
      builder: (context, state, _) {
        final ui = inbox.config.ui;
        final style = InboxStyle.of(context, ui);
        return Scaffold(
          backgroundColor: style.background,
          appBar: AppBar(
            title: Text(title ?? ui.title ?? 'Inbox'),
            actions: [
              if (ui.showMarkAllRead && state.unreadCount > 0)
                IconButton(
                  tooltip: ui.markAllReadLabel ?? 'Mark all as read',
                  icon: const Icon(Icons.done_all),
                  onPressed: () => unawaited(inbox.markAllRead()),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: CodelesslyInboxView(
              inbox: inbox,
              onCardTap: onCardTap,
              category: category,
            ),
          ),
        );
      },
    );
  }
}

/// Opens the inbox full screen. Completes when it is closed.
///
/// ```dart
/// showCodelesslyInbox(context, inbox);
/// ```
Future<void> showCodelesslyInbox(
  BuildContext context,
  CodelesslyInbox inbox, {
  String? title,
  InboxCardTapHandler? onCardTap,
  String? category,
}) async {
  try {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CodelesslyInboxScreen(
          inbox: inbox,
          title: title,
          onCardTap: onCardTap,
          category: category,
        ),
      ),
    );
  } catch (_) {
    // No navigator: nothing to show, nothing to throw.
  }
}
