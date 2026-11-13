import 'package:flutter/material.dart';
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/features/media/embedded_player_web.dart';

void main() => runApp(const MaterialApp(home: PlayerHarness()));

class PlayerHarness extends StatefulWidget {
  const PlayerHarness({super.key});
  @override
  State<PlayerHarness> createState() => _PlayerHarnessState();
}

class _PlayerHarnessState extends State<PlayerHarness> {
  bool playing = false;
  double position = 1.25;
  String id = 'sample';
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Row(
          children: [
            TextButton(onPressed: () => setState(() => playing = !playing), child: const Text('Toggle')),
            TextButton(onPressed: () => setState(() => position = 3.5), child: const Text('Seek')),
            TextButton(onPressed: () => setState(() => id = 'other'), child: const Text('Source')),
          ],
        ),
        Expanded(
          child: EmbeddedPlayer(
            node: api.Node.fromJson({
              'type': 'embeddedVideo',
              'props': {'videoId': id, 'playing': playing, 'positionSeconds': position, 'volume': .4},
            })!,
          ),
        ),
      ],
    ),
  );
}
