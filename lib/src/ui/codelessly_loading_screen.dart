import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CodelesslyLoadingScreen extends StatefulWidget {
  final String? subtitle;

  const CodelesslyLoadingScreen({super.key, this.subtitle});

  @override
  State<CodelesslyLoadingScreen> createState() =>
      _CodelesslyLoadingScreenState();
}

class _CodelesslyLoadingScreenState extends State<CodelesslyLoadingScreen> {
  Widget buildContent() {
    if (widget.subtitle == null) {
      return const Center(
        child: CupertinoActivityIndicator(),
      );
    }
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoActivityIndicator(),
          const SizedBox(height: 8),
          Text(
            widget.subtitle!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'packages/codelessly_sdk/assets/codelessly_logo.png',
            width: 300,
            height: 300,
            color: Theme.of(context).primaryColor.withOpacity(0.1),
          ),
          buildContent(),
        ],
      ),
    );
  }
}
