// Automatic scroll-to-view when a node appears or reveal.when turns true;
// with reveal.follow, kept in view while the content moves until the user
// scrolls away.
import 'dart:async';
import 'package:codelessly_api/core.dart' as api;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'layout/design_scroll.dart';

class RenderReveal extends RenderProxyBox {
  api.Reveal _model = const api.Reveal();
  bool _enabled = false;
  bool _queued = false;
  int _generation = 0;
  Timer? _delay;

  /// The scrollables followed (reveal.follow), each with what tells a user's
  /// scroll since: a design scroll's count of user scrolls, a Flutter
  /// viewport's offset as it was left (there, any other move ends it).
  List<(Object, double)>? _following;

  void configure(api.Reveal model, bool interactive) {
    _model = model;
    final enabled = interactive && model.when;
    if (enabled != _enabled) {
      _enabled = enabled;
      _queued = false;
      _generation++;
      _delay?.cancel();
      _following = null;
    }
    _schedule();
  }

  void _schedule() {
    if (!_enabled || _queued || !attached) return;
    _queued = true;
    final generation = _generation;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!attached || !_enabled || generation != _generation || !hasSize) return;
      void reveal() {
        if (!attached || !_enabled || generation != _generation) return;
        _following = null;
        final duration = Duration(milliseconds: _model.duration);
        final moves = <Future<void>>[];
        RenderObject target = this;
        for (var parent = this.parent; parent != null; parent = parent.parent) {
          if (parent is RenderDesignScroll && parent.interactive) {
            moves.add(parent.reveal(target, alignment: _model.alignment, duration: duration, curve: Curves.easeInOut));
            target = parent;
          } else if (parent is RenderViewportBase && parent.offset is ScrollPosition) {
            final position = parent.offset as ScrollPosition;
            if (position.hasContentDimensions) {
              final to = parent
                  .getOffsetToReveal(target, _model.alignment)
                  .offset
                  .clamp(position.minScrollExtent, position.maxScrollExtent)
                  .toDouble();
              if (_model.duration == 0) {
                position.jumpTo(to);
              } else {
                moves.add(position.animateTo(to, duration: duration, curve: Curves.easeInOut));
              }
            }
            target = parent;
          }
        }
        if (_model.follow) Future.wait(moves).then((_) => _startFollowing(generation));
      }

      if (_model.delay == 0) {
        reveal();
      } else {
        _delay = Timer(Duration(milliseconds: _model.delay), reveal);
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// The scrollables this node is revealed in, innermost first.
  Iterable<Object> _scrollables() sync* {
    for (var parent = this.parent; parent != null; parent = parent.parent) {
      if (parent is RenderDesignScroll && parent.interactive) yield parent;
      if (parent is RenderViewportBase && parent.offset is ScrollPosition) yield parent.offset as ScrollPosition;
    }
  }

  static double? _pixelsOf(Object s) => switch (s) {
        RenderDesignScroll d => d.pixels,
        ScrollPosition p => p.hasPixels ? p.pixels : null,
        _ => null,
      };

  /// What [_following] keeps for [s] (see there).
  static double? _markOf(Object s) => switch (s) {
        RenderDesignScroll d => d.userScrolls.toDouble(),
        _ => _pixelsOf(s),
      };

  static double? _maxOf(Object s) => switch (s) {
        RenderDesignScroll d => d.maxScrollExtent,
        ScrollPosition p => p.hasContentDimensions ? p.maxScrollExtent : null,
        _ => null,
      };

  void _startFollowing(int generation) {
    if (!attached || !_enabled || generation != _generation) return;
    _following = [for (final s in _scrollables()) if (_markOf(s) case final m?) (s, m)];
    _followAfterFrame(generation);
  }

  /// After every frame (none are asked for: an idle screen costs nothing),
  /// reveals the node again where the content has moved it, as long as no
  /// one else has scrolled.
  void _followAfterFrame(int generation) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final following = _following;
      if (following == null || !attached || !_enabled || generation != _generation || !hasSize) return;
      for (final (s, mark) in following) {
        final now = _markOf(s);
        // Shorter content clamps a viewport's offset to its new end: not a
        // scroll. (A design scroll counts its user's scrolls instead.)
        final clamped = s is ScrollPosition && now != null && now < mark && now == _maxOf(s);
        if (now != mark && !clamped) {
          _following = null; // scrolled by the user
          return;
        }
      }
      RenderObject target = this;
      for (var parent = this.parent; parent != null; parent = parent.parent) {
        if (parent is RenderDesignScroll && parent.interactive) {
          parent.reveal(target, alignment: _model.alignment);
          target = parent;
        } else if (parent is RenderViewportBase && parent.offset is ScrollPosition) {
          final position = parent.offset as ScrollPosition;
          if (position.hasContentDimensions) {
            position.jumpTo(parent
                .getOffsetToReveal(target, _model.alignment)
                .offset
                .clamp(position.minScrollExtent, position.maxScrollExtent)
                .toDouble());
          }
          target = parent;
        }
      }
      _following = [for (final s in _scrollables()) if (_markOf(s) case final m?) (s, m)];
      _followAfterFrame(generation);
    });
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _queued = false;
    _schedule();
  }

  @override
  void detach() {
    _generation++;
    _following = null;
    _delay?.cancel();
    _queued = false;
    super.detach();
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }
}
