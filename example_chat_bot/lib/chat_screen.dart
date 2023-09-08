import 'dart:async';

import 'package:bubble/bubble.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:example_chat_bot/main.dart';
import 'package:example_chat_bot/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';

import 'background_painter.dart';
import 'constants.dart';

const layouts = [
  '0R0bRontTC4rlrlzOIkq',
  '0R0bRone19zPAwRqCg01',
  '0R0bRonmXXXD1NgH7HyS',
];

const prompts = [
  "How's the weather today?",
  'Is there anything important on the news today?',
  "Who's Aurora?"
];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController animController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  late final Animation<double> anim = CurvedAnimation(
    parent: animController,
    curve: Curves.easeInOut,
  );

  /// Blocks the UI (mainly the send button).
  bool busy = false;

  /// The current index of the chat bubbles.
  int chatProgress = 0;

  /// The text shown in the user's text field.
  late final TextEditingController promptController = TextEditingController()
    ..text = prompts[0];

  /// The scroll controller to allow us to scroll to the bottom of the chat
  /// whenever a new message is sent.
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Codelessly.instance.configure(
      config: CodelesslyConfig(
        authToken: authToken,
        automaticallySendCrashReports: false,
        isPreview: false,
        firebaseProjectId: 'codeless-dev',
        firebaseCloudFunctionsBaseURL:
            'https://us-central1-codeless-dev.cloudfunctions.net',
        // preload: false,
      ),
    );
  }

  @override
  void dispose() {
    animController.dispose();
    promptController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  /// The user's message bubbles.
  Widget rightBubble(BuildContext context, String text) {
    return Bubble(
      margin: const BubbleEdges.all(4),
      nip: BubbleNip.rightBottom,
      alignment: Alignment.centerRight,
      color: context.colorScheme.primaryContainer,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Text(
          text,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  /// The CodelesslyGPT's message bubbles.
  Widget leftBubble(BuildContext context, String text) {
    return Bubble(
      margin: const BubbleEdges.all(4),
      nip: BubbleNip.leftBottom,
      alignment: Alignment.centerLeft,
      color: context.colorScheme.secondaryContainer,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Text(
          text,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  /// The CodelesslyGPT's SDK message bubbles.
  Widget sdkBubble(BuildContext context, String layoutID) =>
      CodelesslyChatBubble(layoutID: layoutID);

  /// A centered version of the CodelesslyGPT's SDK message bubbles.
  Widget sdkBubbleCentered(
    BuildContext context,
    String layoutID, {
    bool unlimitedHeight = false,
  }) {
    return Container(
      width: double.infinity,
      height: unlimitedHeight ? null : 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colorScheme.secondaryContainer,
      ),
      child: CodelesslyWidget(
        layoutID: layoutID,
      ),
    );
  }

  /// The first answer from the CodelesslyGPT.
  Widget firstAnswer(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        leftBubble(context, "Here's what I found:"),
        sdkBubble(
          context,
          layouts[0],
          // unlimitedHeight: true,
        ),
      ]);

  /// The second answer from the CodelesslyGPT.
  Widget secondAnswer(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        leftBubble(context, "Here are the top headlines from today:"),
        sdkBubble(context, layouts[1]),
      ]);

  /// The third answer from the CodelesslyGPT.
  Widget thirdAnswer(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        leftBubble(
          context,
          "Here's what I found about Aurora Aksnes:",
        ),
        sdkBubble(context, layouts[2]),
      ]);

  /// Slides a widget from the [xOffset] if [condition] is true to its
  /// original position.
  Widget slideIf(bool condition, double xOffset, Widget child) =>
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeInOutQuart,
        switchOutCurve: Curves.easeOutQuart,
        transitionBuilder: (child, animation) => SlideTransition(
          position: Tween<Offset>(
            begin: Offset(xOffset, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
        child: condition ? child : const SizedBox.shrink(),
      );

  /// Slides a widget from the right if [condition] is true to its
  Widget slideRightIf(bool condition, Widget child) =>
      slideIf(condition, -1, child);

  /// Slides a widget from the left if [condition] is true to its
  Widget slideLeftIf(bool condition, Widget child) =>
      slideIf(condition, 1, child);

  /// Progresses the chat by one step.
  Future<void> progressChat() async {
    // Lazily initialize the SDK instance!
    // if (chatProgress == 0) {
    // codelessly.init();
    // }

    // "Send" the message
    setState(() {
      chatProgress++;
      promptController.clear();
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(seconds: 1),
        curve: Curves.fastOutSlowIn,
      );
    });

    // "Wait for network request to finish"
    await Future.delayed(const Duration(seconds: 1));

    // "Receive" the message
    setState(() {
      chatProgress++;
      if (chatProgress ~/ 2 < prompts.length) {
        promptController.text = prompts[chatProgress ~/ 2];
      }
    });

    // Delay to allow the full response to load in the Widget tree so we can
    // scroll down to it.
    await Future.delayed(const Duration(milliseconds: 200));
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(seconds: 1),
      curve: Curves.fastOutSlowIn,
    );
  }

  /// Resets the entire conversation back to the first message.
  void reset() async {
    // Scroll to the top first.
    setState(() {
      busy = true;
      scrollController.animateTo(
        0,
        duration: const Duration(seconds: 1),
        curve: Curves.fastOutSlowIn,
      );
    });

    // Wait until almost to the end of the scrolling progress for aesthetics.
    await Future.delayed(const Duration(milliseconds: 500));

    // Reset the chat progress and the prompt.
    // Everything will slide away from the view.
    if (mounted) {
      setState(() {
        chatProgress = 0;
        promptController.text = prompts[0];
      });
    }

    // If we reset the CodelesslySDK immediately, the messages will pop away
    // while sliding away from the view, so let's wait until the exit
    // animations are done before resetting the SDK.
    await Future.delayed(const Duration(seconds: 2));

    // Reset the SDK.
    await Codelessly.instance.reset();
    // await codelessly.init();

    // Unblock the UI (send button).
    if (mounted) {
      setState(() {
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box(settingsPath);
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box box, child) {
        final currentMode = getThemeMode(box);
        return Scaffold(
          appBar: AppBar(
            backgroundColor:
                context.colorScheme.primaryContainer.withOpacity(0.9),
            surfaceTintColor: Colors.transparent,
            // elevation: 10,
            // shadowColor: Colors.black,
            leading: SizedBox(
              child: Image.asset(
                'packages/codelessly_sdk/assets/codelessly_logo.png',
              ),
            ),
            automaticallyImplyLeading: false,
            title: const Text('CodelesslyGPT'),
            actions: [
              const SizedBox(width: 8),
              IconButton(
                onPressed: busy ? null : reset,
                icon: busy
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          color: context.colorScheme.onPrimaryContainer,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.restart_alt),
                tooltip: 'Clear cache & reset chat',
              ),
              // theme mode.
              IconButton(
                onPressed: () {
                  box.put(
                    'themeMode',
                    currentMode == ThemeMode.light ? 'dark' : 'light',
                  );
                },
                icon: Icon(
                  currentMode == ThemeMode.light
                      ? Icons.dark_mode
                      : Icons.light_mode,
                ),
                tooltip: 'Toggle theme mode',
              ),
              const SizedBox(width: 8),
            ],
            centerTitle: true,
          ),
          extendBodyBehindAppBar: true,
          body: Builder(
            builder: (context) {
              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  // Background
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.colorScheme.background.withOpacity(0.75),
                    ),
                    position: DecorationPosition.foreground,
                    child: AnimatedBuilder(
                        animation: anim,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: BackgroundPaint(
                              blue: const Color(0xFF4350CC),
                              lightBlue: Colors.lightBlueAccent,
                              purple: const Color(0xFFFE48EF),
                              yellow: Colors.yellow,
                              anim: anim.value,
                            ),
                          );
                        }),
                  ),

                  // Contents
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildChatView(context),
                      buildUserInteractionArea(context),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Expanded buildChatView(BuildContext context) {
    return Expanded(
      child: Scrollbar(
        controller: scrollController,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SizedBox.expand(
              child: ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      SizedBox(
                          height: (Scaffold.of(context).appBarMaxHeight ?? 56)),
                      leftBubble(context, 'Hi, how can I assist you today?'),
                      slideLeftIf(
                        chatProgress >= 1,
                        rightBubble(context, prompts[0]),
                      ),
                      slideRightIf(
                        chatProgress >= 2,
                        firstAnswer(context),
                      ),
                      slideLeftIf(
                        chatProgress >= 3,
                        rightBubble(context, prompts[1]),
                      ),
                      slideRightIf(
                        chatProgress >= 4,
                        secondAnswer(context),
                      ),
                      slideLeftIf(
                        chatProgress >= 5,
                        rightBubble(context, prompts[2]),
                      ),
                      slideRightIf(
                        chatProgress >= 6,
                        thirdAnswer(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Center buildUserInteractionArea(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(8),
        clipBehavior: Clip.hardEdge,
        constraints: const BoxConstraints(maxWidth: 800),
        decoration: BoxDecoration(
          color: context.colorScheme.primaryContainer,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(8),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: promptController,
                  readOnly: true,
                  keyboardType: TextInputType.text,
                  textAlign: TextAlign.left,
                  autofocus: true,
                  autocorrect: false,
                  cursorRadius: const Radius.circular(2),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    alignLabelWithHint: true,
                    icon: const Material(
                      color: Colors.transparent,
                      shape: CircleBorder(),
                      clipBehavior: Clip.hardEdge,
                      child: Icon(Icons.add, size: 24),
                    ),
                    errorMaxLines: 1,
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    isDense: true,
                    suffixIcon: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.hardEdge,
                      child: IconButton(
                        icon: const Icon(Icons.mic_none, size: 24),
                        onPressed: () {},
                      ),
                    ),
                    filled: true,
                    fillColor: context.colorScheme.onPrimaryContainer,
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                        width: 1,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(
                        width: 1,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(
                        width: 0,
                        color: Colors.transparent,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(
                        width: 0,
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.fastOutSlowIn,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.colorScheme.onPrimaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: chatProgress % 2 != 0
                      ? Border.all(
                          color: context.colorScheme.onSurfaceVariant,
                          width: 1,
                        )
                      : null,
                ),
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  onTap: chatProgress % 2 == 0 && chatProgress < 6 && !busy
                      ? progressChat
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutQuart,
                      switchOutCurve: Curves.easeInQuart,
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                      child: chatProgress % 2 != 0
                          ? SizedBox.square(
                              key: const ValueKey('loading'),
                              dimension: 14,
                              child: CircularProgressIndicator(
                                color: context.colorScheme.onSurface,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.send,
                              key: const ValueKey('send'),
                              // size: 20,
                              color: context.colorScheme.onSurface,
                            ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class CodelesslyChatBubble extends StatefulWidget {
  final String layoutID;

  const CodelesslyChatBubble({
    super.key,
    required this.layoutID,
  });

  @override
  State<CodelesslyChatBubble> createState() => _CodelesslyChatBubbleState();
}

class _CodelesslyChatBubbleState extends State<CodelesslyChatBubble> {
  @override
  Widget build(BuildContext context) {
    return Bubble(
      margin: const BubbleEdges.only(left: 12, right: 12, bottom: 8),
      padding: const BubbleEdges.all(2),
      radius: const Radius.circular(8),
      alignment: Alignment.centerLeft,
      color: context.colorScheme.secondaryContainer,
      elevation: 0,
      child: Container(
        clipBehavior: Clip.antiAlias,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: CodelesslyWidget(
          layoutID: widget.layoutID,
          loadingBuilder: (context) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: context.colorScheme.onSurface,
              ),
            );
          },
          errorBuilder: (context, exception) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: context.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      exception.toString(),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          layoutBuilder: (context, layout) {
            return SizedBox(
              height: 400,
              child: layout,
            );
          },
        ),
      ),
    );
  }
}
