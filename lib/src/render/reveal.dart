// Automatic scroll-to-view when a node appears or reveal.when turns true.
import 'dart:async';
import 'package:codelessly_api/codelessly_api.dart' as api;
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

  void configure(api.Reveal model, bool interactive) {
    _model = model;
    final enabled = interactive && model.when;
    if (enabled != _enabled) {
      _enabled = enabled;
      _queued = false;
      _generation++;
      _delay?.cancel();
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
        final duration = Duration(milliseconds: _model.duration);
        RenderObject target = this;
        for (var parent = this.parent; parent != null; parent = parent.parent) {
          if (parent is RenderDesignScroll && parent.interactive) {
            parent.reveal(target, alignment: _model.alignment, duration: duration, curve: Curves.easeInOut);
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
                position.animateTo(to, duration: duration, curve: Curves.easeInOut);
              }
            }
            target = parent;
          }
        }
      }

      if (_model.delay == 0) {
        reveal();
      } else {
        _delay = Timer(Duration(milliseconds: _model.delay), reveal);
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
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
