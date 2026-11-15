// The flow "A session, start to finish": the real generated screens, each
// put in the state that step of a session has, side by side in the
// storyboard's flow viewer. It follows the person and the token set chosen
// in the panel, and the store.
import 'package:flutter/widgets.dart';
import 'package:soft_saas_ui/soft_saas_ui.dart';

import '../storyboard/models/flow_step.dart';
import '../storyboard/models/item_status.dart';
import '../storyboard/models/phone_frame.dart';
import '../storyboard/widgets/single_flow_viewer.dart';
import 'skip_screen.dart';

/// The jumps counted in the flow's session.
const int kFlowJumps = 12;

/// The session's own state while it runs: the first round, twelve seconds in.
const Map<String, Object?> kRunning = {'phase': 'work', 'left': 28, 'round': 1, 'count': kFlowJumps, 'elapsed': 12};

/// And when it is done. `saved` keeps the screen from saying so again.
const Map<String, Object?> kFinished = {
  'phase': 'done',
  'left': 0,
  'round': 8,
  'count': kFlowJumps,
  'elapsed': 320,
  'saved': true,
};

/// The store as Home shows it after the session: what `finish_session` does.
Map<String, Object?> afterASession(Map<String, Object?> data) => {
  'streak': ((data['streak'] as num?) ?? 0) + 1,
  'sessionsThisWeek': ((data['sessionsThisWeek'] as num?) ?? 0) + 1,
};

Widget _step(String id, String screen, {Map<String, Object?> state = const {}, bool after = false}) => SkipScreen(
  key: ValueKey('flow-$id'),
  screen: screen,
  state: state,
  over: after ? afterASession : null,
  interactive: false,
);

final FlowDefinition sessionFlow = FlowDefinition(
  name: 'A session, start to finish',
  description: 'Home, the session ready, running and finished, and Home again with the session in the store.',
  rowCount: 1,
  maxColumnsPerRow: 5,
  steps: [
    FlowStep(id: 'home', label: 'Home', column: 0, status: ItemStatus.completed, builder: () => _step('home', 'home')),
    FlowStep(
      id: 'ready',
      label: 'Session, ready',
      column: 1,
      status: ItemStatus.completed,
      builder: () => _step('ready', 'session'),
    ),
    FlowStep(
      id: 'running',
      label: 'Session, running',
      column: 2,
      status: ItemStatus.completed,
      builder: () => _step('running', 'session', state: kRunning),
    ),
    FlowStep(
      id: 'finished',
      label: 'Session, finished',
      column: 3,
      status: ItemStatus.completed,
      builder: () => _step('finished', 'session', state: kFinished),
    ),
    FlowStep(
      id: 'home_again',
      label: 'Home again',
      column: 4,
      status: ItemStatus.completed,
      builder: () => _step('home_again', 'home', after: true),
    ),
  ],
  connections: const [
    FlowConnection(fromStepId: 'home', toStepId: 'ready', label: 'start_session'),
    FlowConnection(fromStepId: 'ready', toStepId: 'running', label: 'Start'),
    FlowConnection(fromStepId: 'running', toStepId: 'finished', label: 'finish_session'),
    FlowConnection(fromStepId: 'finished', toStepId: 'home_again', label: 'open_home'),
  ],
);

class SessionFlowPage extends StatelessWidget {
  const SessionFlowPage({super.key});

  @override
  Widget build(BuildContext context) => SingleFlowViewer(
    flow: sessionFlow,
    isDarkMode: SoftSaaSTheme.isDark(context),
    // The frame the screens were generated for: 390 by 844.
    frame: PhoneFrames.iphoneSE4,
  );
}
