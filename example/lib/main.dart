import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const String _authToken = "cSlMIT93cj1lXkBuYk5QNmImSTUsTHw2MDQ4VkdlOCZFLHc7";

/// Loads the stories from the new Codelessly Editor's backend (codeless-editor)
/// instead of the legacy one (codeless-app).
/// Run with `--dart-define=CODELESSLY_BACKEND=editor`.
const bool _useEditorBackend =
    String.fromEnvironment('CODELESSLY_BACKEND') == 'editor';

const FirebaseOptions _editorWebFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyCecNnIv_X-F1uFPJT2y8XPCLpxXdD3etk',
  appId: '1:945980228772:web:7d092a75773524dd5f1231',
  messagingSenderId: '945980228772',
  projectId: 'codeless-editor',
  authDomain: 'codeless-editor.firebaseapp.com',
  databaseURL: 'https://codeless-editor-default-rtdb.firebaseio.com',
  storageBucket: 'codeless-editor.firebasestorage.app',
  measurementId: 'G-JZ7FS97GFQ',
);

/// iOS and macOS share one Apple app registered for the bundle id
/// com.codelessly.sdk.example.
const FirebaseOptions _editorAppleFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyCCJo44CTI8YqNhX3G1HLTlHfkE38gSsTk',
  appId: '1:945980228772:ios:f4967501ad5db1e45f1231',
  messagingSenderId: '945980228772',
  projectId: 'codeless-editor',
  databaseURL: 'https://codeless-editor-default-rtdb.firebaseio.com',
  storageBucket: 'codeless-editor.firebasestorage.app',
  iosBundleId: 'com.codelessly.sdk.example',
);

const FirebaseOptions _editorAndroidFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyAS21PXCaPfCs710MMK__KblTL4lfoCrZY',
  appId: '1:945980228772:android:d3dc811e471d25db5f1231',
  messagingSenderId: '945980228772',
  projectId: 'codeless-editor',
  databaseURL: 'https://codeless-editor-default-rtdb.firebaseio.com',
  storageBucket: 'codeless-editor.firebasestorage.app',
);

/// Native platforms need the app registered for them; the rest use web's.
FirebaseOptions get _editorFirebaseOptions {
  if (kIsWeb) return _editorWebFirebaseOptions;
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => _editorAppleFirebaseOptions,
    TargetPlatform.android => _editorAndroidFirebaseOptions,
    _ => _editorWebFirebaseOptions,
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Codelessly.instance.initialize(
    config: _useEditorBackend
        ? CodelesslyConfig(
            authToken: _authToken,
            isPreview: kDebugMode,
            preload: true,
            firebaseOptions: _editorFirebaseOptions,
            firebaseProjectId: 'codeless-editor',
            firebaseCloudFunctionsBaseURL:
                'https://us-central1-codeless-editor.cloudfunctions.net',
            baseURL: 'https://codeless-editor.web.app',
          )
        : CodelesslyConfig(
            authToken: _authToken,
            isPreview: kDebugMode,
            preload: true,
          ),
  );

  runApp(const MyApp());
}

/// Codelessly's brand indigo; Material 3 derives every color role from it.
const Color _brandColor = Color(0xFF5C69E5);

/// A Codelessly layout shown as one entry in the example gallery.
class Story {
  const Story({required this.name, required this.icon, required this.builder});

  final String name;
  final IconData icon;
  final WidgetBuilder builder;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Codelessly SDK Examples',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _brandColor)),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _brandColor,
        brightness: Brightness.dark,
      ),
    ),
    home: const StoryGallery(),
  );
}

/// Lists the example layouts in a navigation drawer (inline on wide screens,
/// a modal drawer on narrow ones) and shows the selected one.
///
/// On web, `?story=<name>` opens a specific story.
class StoryGallery extends StatefulWidget {
  const StoryGallery({super.key});

  @override
  State<StoryGallery> createState() => _StoryGalleryState();
}

class _StoryGalleryState extends State<StoryGallery> {
  Map<String, dynamic> licenseData = {'license': 'FREE'};

  late int selectedIndex = _initialIndex();

  int _initialIndex() {
    final String? name = Uri.base.queryParameters['story'];
    final int index = stories.indexWhere((story) => story.name == name);
    return index == -1 ? 0 : index;
  }

  void setLicense(String license) =>
      setState(() => licenseData = {'license': license});

  late final List<Story> stories = [
    Story(
      name: 'Hello World',
      icon: Icons.waving_hand_outlined,
      builder: (context) => CodelesslyWidget(
        layoutID: '0R0yRfzR23SQfDGrbg3h',
        loadingBuilder: _loading,
      ),
    ),
    Story(
      name: 'License UI',
      icon: Icons.verified_outlined,
      builder: (context) => CodelesslyWidget(
        layoutID: '0R0yeUx1iGDe9kgW5xwn',
        data: licenseData,
        functions: {
          'onFreeSelected': (context, reference, params) => setLicense('FREE'),
          'onProSelected': (context, reference, params) => setLicense('PRO'),
          'onBusinessSelected': (context, reference, params) =>
              setLicense('BUSINESS'),
        },
        loadingBuilder: _loading,
      ),
    ),
    Story(
      name: 'Pricing UI',
      icon: Icons.sell_outlined,
      builder: (context) => CodelesslyWidget(
        layoutID: '0R0yedXWbqOrI_W7PBlo',
        loadingBuilder: _loading,
      ),
    ),
    Story(
      name: 'Pricing Card',
      icon: Icons.credit_card_outlined,
      builder: (context) => CodelesslyWidget(
        layoutID: '0R1xmqF5lXMr6LpLA9h5',
        loadingBuilder: _loading,
      ),
    ),
    Story(
      name: 'Fruit Product Card',
      icon: Icons.shopping_basket_outlined,
      builder: (context) => CodelesslyWidget(
        layoutID: '0R5hf4ABTQmzDb6e8XyR',
        data: const {
          'name': 'Mango',
          'price': 5.99,
          'count': 1,
          'description': 'Mangos are versatile fruits that can be enjoyed in many ways. You can eat them fresh as a snack or dessert, or add them to salads, smoothies, salsas, curries, cakes, pies, and more. You can also make mango juice, jam, chutney, or pickle.\n\nMangos are a great way to add some tropical flavor and nutrition to your diet.',
        },
        loadingBuilder: _loading,
      ),
    ),
  ];

  static Widget _loading(BuildContext context) =>
      const Center(child: CircularProgressIndicator());

  Widget _buildDrawer({required bool modal}) => NavigationDrawer(
    selectedIndex: selectedIndex,
    onDestinationSelected: (index) {
      setState(() => selectedIndex = index);
      if (modal) Navigator.pop(context);
    },
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
        child: Text('Examples'),
      ),
      for (final Story story in stories)
        NavigationDrawerDestination(
          icon: Icon(story.icon),
          label: Text(story.name),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.sizeOf(context).width >= 840;
    final Story story = stories[selectedIndex];

    return Scaffold(
      appBar: AppBar(title: Text(story.name)),
      drawer: wide ? null : _buildDrawer(modal: true),
      body: Row(
        children: [
          if (wide) ...[
            SizedBox(width: 280, child: _buildDrawer(modal: false)),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(story.name),
              child: Builder(builder: story.builder),
            ),
          ),
        ],
      ),
    );
  }
}
