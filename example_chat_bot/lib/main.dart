import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';

import 'chat_screen.dart';

const String authToken = 'LW1IN0cmWWI6TDhRI0V7e3lhNDJ8NyQyckBbMHBIWngkWmI1';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HomePage());
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF5C69E5);

    return AdaptiveTheme(
      initial: AdaptiveThemeMode.light,
      light: ThemeData(
        brightness: Brightness.light,
        primaryColor: primaryColor,
      ),
      dark: ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryColor,
      ),
      builder: (theme, darkTheme) => MaterialApp(
        title: 'CodelesslyGPT',
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,
        home: const ChatScreen(),
      ),
    );
  }
}
