import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CodelesslyLoadingScreen extends StatefulWidget {
  const CodelesslyLoadingScreen({super.key});

  @override
  State<CodelesslyLoadingScreen> createState() => _CodelesslyLoadingScreenState();
}

class _CodelesslyLoadingScreenState extends State<CodelesslyLoadingScreen> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
