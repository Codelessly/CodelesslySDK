import 'package:material_ui/material_ui.dart';
import 'package:skip_shell/storyboard/models/phone_frame.dart';

/// A widget that displays content within a phone frame
class PhoneFrameViewer extends StatelessWidget {
  final Widget child;
  final PhoneFrame frame;
  final bool isDarkMode;

  /// Optional: Key for RepaintBoundary around content (for component screenshots)
  final GlobalKey? componentBoundaryKey;

  const PhoneFrameViewer({
    super.key,
    required this.child,
    required this.frame,
    required this.isDarkMode,
    this.componentBoundaryKey,
  });

  @override
  Widget build(BuildContext context) {
    // Optionally wrap child with RepaintBoundary for component screenshots
    Widget contentChild = child;
    if (componentBoundaryKey != null) {
      contentChild = RepaintBoundary(
        key: componentBoundaryKey,
        child: child,
      );
    }

    // Wrap child to prevent navigation pops
    final wrappedChild = PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        debugPrint('Storyboard: Blocked system back button');
      },
      child: Navigator(
        key: ValueKey('storyboard_nav_${child.hashCode}'),
        observers: [_NoPopNavigatorObserver()],
        pages: [
          _NoPopPage(
            key: ValueKey('storyboard_page_${child.hashCode}'),
            child: contentChild,
          ),
        ],
        onDidRemovePage: (page) {
          debugPrint('Storyboard: Blocked page removal');
        },
      ),
    );

    if (frame == PhoneFrames.none) {
      return wrappedChild;
    }

    final contentWithMediaQuery = MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: Size(frame.width, frame.height),
        devicePixelRatio: frame.devicePixelRatio,
        textScaler: const TextScaler.linear(1.0),
        padding: _getPaddingForFrame(frame),
        viewInsets: EdgeInsets.zero,
        viewPadding: _getPaddingForFrame(frame),
      ),
      child: wrappedChild,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: frame.width,
              height: frame.height,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(frame.borderRadius),
                  border: Border.all(
                    color: isDarkMode ? Colors.white24 : Colors.black26,
                    width: 8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(frame.borderRadius - 4),
                  child: contentWithMediaQuery,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  EdgeInsets _getPaddingForFrame(PhoneFrame frame) {
    if (frame == PhoneFrames.iphone17Pro ||
        frame == PhoneFrames.iphone17) {
      return const EdgeInsets.only(top: 47, bottom: 34);
    }

    if (frame == PhoneFrames.iphoneSE4) {
      return const EdgeInsets.only(top: 47, bottom: 34);
    }

    if (frame.platform == 'android') {
      return const EdgeInsets.only(top: 24, bottom: 16);
    }

    return const EdgeInsets.only(top: 24, bottom: 0);
  }
}

/// Widget for selecting a phone frame
class PhoneFrameSelector extends StatelessWidget {
  final PhoneFrame selectedFrame;
  final ValueChanged<PhoneFrame> onFrameSelected;
  final bool isDarkMode;

  const PhoneFrameSelector({
    super.key,
    required this.selectedFrame,
    required this.onFrameSelected,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device Frame',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildFrameButton(PhoneFrames.none),
          const SizedBox(height: 12),
          Text(
            'iOS Devices',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          ...PhoneFrames.ios.map(_buildFrameButton),
          const SizedBox(height: 12),
          Text(
            'Android Devices',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          ...PhoneFrames.android.map(_buildFrameButton),
        ],
      ),
    );
  }

  Widget _buildFrameButton(PhoneFrame frame) {
    final isSelected = frame == selectedFrame;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onFrameSelected(frame),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDarkMode
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.08))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? (isDarkMode ? Colors.white24 : Colors.black26)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  frame.platform == 'ios'
                      ? Icons.phone_iphone
                      : frame.platform == 'android'
                          ? Icons.phone_android
                          : Icons.crop_free,
                  size: 16,
                  color: isSelected
                      ? (isDarkMode ? Colors.white : Colors.black87)
                      : (isDarkMode ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        frame.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? (isDarkMode ? Colors.white : Colors.black87)
                              : (isDarkMode ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      if (frame.description.isNotEmpty)
                        Text(
                          frame.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode ? Colors.white54 : Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: isDarkMode
                        ? Colors.green.shade400
                        : Colors.green.shade600,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoPopNavigatorObserver extends NavigatorObserver {
  @override
  void didPop(Route route, Route? previousRoute) {
    debugPrint('Storyboard: Blocked didPop');
  }
}

class _NoPopRoute<T> extends MaterialPageRoute<T> {
  _NoPopRoute({
    required super.builder,
    required super.settings,
  });

  @override
  bool get willHandlePopInternally => true;

  @override
  Future<RoutePopDisposition> willPop() async {
    debugPrint('Storyboard: Blocked willPop');
    return RoutePopDisposition.doNotPop;
  }
}

class _NoPopPage<T> extends MaterialPage<T> {
  const _NoPopPage({
    required super.key,
    required super.child,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    return _NoPopRoute<T>(
      builder: (context) => child,
      settings: this,
    );
  }
}
