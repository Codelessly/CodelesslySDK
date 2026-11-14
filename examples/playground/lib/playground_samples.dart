// The samples the playground lists, in two groups: short ones that each
// teach one part of the notation, and agent UI targets taken from
// design_systems/ssui/examples/targets.

/// One sample: `assets/samples/<id>.txt`.
class PlaygroundSample {
  const PlaygroundSample(this.id, this.title);

  final String id;
  final String title;

  String get asset => 'assets/samples/$id.txt';
}

/// A titled group of samples (a folder of the samples tree).
class PlaygroundSampleGroup {
  const PlaygroundSampleGroup(this.id, this.title, this.samples);

  final String id;
  final String title;
  final List<PlaygroundSample> samples;
}

/// The bundled samples. The first one of the first group shows at start.
const List<PlaygroundSampleGroup> playgroundSampleGroups = <PlaygroundSampleGroup>[
  PlaygroundSampleGroup('learn', 'Learn the notation', <PlaygroundSample>[
    PlaygroundSample('start_here', 'Start here'),
    PlaygroundSample('layout', 'Rows and columns'),
    PlaygroundSample('state_and_actions', 'State and actions'),
    PlaygroundSample('lists', 'Lists'),
    PlaygroundSample('components', 'Components'),
    PlaygroundSample('mistakes', 'Mistakes'),
  ]),
  PlaygroundSampleGroup('agent', 'Agent UI', <PlaygroundSample>[
    PlaygroundSample('approval_card', 'Approval card'),
    PlaygroundSample('elicitation_form', 'Elicitation form'),
    PlaygroundSample('job_progress', 'Job progress'),
    PlaygroundSample('todo_list', 'To-do list'),
    PlaygroundSample('tool_call', 'Tool call'),
    PlaygroundSample('data_table', 'Data table'),
    PlaygroundSample('comparison', 'Comparison'),
    PlaygroundSample('chart', 'Chart'),
    PlaygroundSample('schedule', 'Schedule'),
    PlaygroundSample('quota_banner', 'Quota banner'),
    PlaygroundSample('voice_conversation', 'Voice conversation'),
  ]),
];

/// Every sample, in list order.
final List<PlaygroundSample> playgroundSamples = <PlaygroundSample>[
  for (final PlaygroundSampleGroup group in playgroundSampleGroups) ...group.samples,
];

/// One bundled design system: `assets/design_systems/<id>.json`.
class PlaygroundDesignSystem {
  const PlaygroundDesignSystem(this.id, this.name);

  final String id;
  final String name;

  String get asset => 'assets/design_systems/$id.json';
}

/// The design systems the preview can be drawn in (tool/bundle.sh).
const List<PlaygroundDesignSystem> playgroundDesignSystems = <PlaygroundDesignSystem>[
  PlaygroundDesignSystem('ssui', 'Soft SaaS UI'),
  PlaygroundDesignSystem('paper', 'Paper'),
  PlaygroundDesignSystem('harbor', 'Harbor'),
];

/// The widths the preview can be shown at.
const List<int> playgroundWidths = <int>[320, 420, 720];
