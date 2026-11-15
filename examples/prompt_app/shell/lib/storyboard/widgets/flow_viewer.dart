import 'package:material_ui/material_ui.dart';
import 'package:skip_shell/storyboard/models/flow_step.dart';
import 'package:skip_shell/storyboard/models/phone_frame.dart';
import 'single_flow_viewer.dart';
import 'multiflow_viewer.dart';

/// A widget that displays a flow of screens in phone frames with connecting arrows
///
/// This is a wrapper that automatically selects between:
/// - SingleFlowViewer: For simple linear flows
/// - MultiFlowViewer: For complex flows with groups and multiple rows/columns
@Deprecated('Use SingleFlowViewer or MultiFlowViewer directly instead')
class FlowViewer extends StatelessWidget {
  final FlowDefinition flow;
  final bool isDarkMode;
  final PhoneFrame frame;

  const FlowViewer({
    super.key,
    required this.flow,
    required this.isDarkMode,
    this.frame = PhoneFrames.iphone17,
  });

  @override
  Widget build(BuildContext context) {
    final hasGroups = flow.groups.isNotEmpty;

    if (hasGroups) {
      return MultiFlowViewer(
        flow: flow,
        isDarkMode: isDarkMode,
        frame: frame,
      );
    } else {
      return SingleFlowViewer(
        flow: flow,
        isDarkMode: isDarkMode,
        frame: frame,
      );
    }
  }
}
