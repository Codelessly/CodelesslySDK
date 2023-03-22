import 'package:codelessly_api/api.dart';

/// This is used to store retrieved data from a document in the 'websites' collection.
@Deprecated('Use SDKPublishModel instead.')
class FetchWebsiteData {
  final Map<String, SceneNode> nodes;
  final String? entryPoint;
  final List<Breakpoint>? breakpoints;

  const FetchWebsiteData({
    required this.nodes,
    required this.entryPoint,
    required this.breakpoints,
  });

  @override
  String toString() =>
      'FetchWebsiteData(nodes: $nodes, entryPoint: $entryPoint, breakpoints: $breakpoints)';
}
