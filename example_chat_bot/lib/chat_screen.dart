import 'package:bubble/bubble.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:example_chat_bot/main.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const layouts = [
  '0Qq5F2I4ZH7u0XtMu3KE',
  '0Qq3UXthyzNKDS35vgek',
  '0Qq3kdoATbhyplzBqeUc',
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

class _ChatScreenState extends State<ChatScreen> {
  /// A local codelessly SDK to allow us to lazily load the instance once at
  /// least the first message is sent instead of when the app first starts.
  final Codelessly codelessly = Codelessly(
    config: const CodelesslyConfig(
      authToken: authToken,
      automaticallyCollectCrashReports: false,
    ),
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

  /// The color of the CodelesslyGPT's message bubbles.
  final Color leftColor = const Color(0xFFff74ee);

  /// The color of the user's message bubbles.
  final Color rightColor = const Color(0xFF5C69E5);

  /// The background color of the chat screen.
  final Color bg = const Color(0xFFFAFAFA);

  /// The text style of the CodelesslyGPT's message bubbles.
  final TextStyle leftStyle =
      GoogleFonts.poppins().copyWith(color: Colors.black, fontSize: 12);

  /// The text style of the user's message bubbles.
  final TextStyle rightStyle =
      GoogleFonts.poppins().copyWith(color: Colors.white, fontSize: 12);

  @override
  void dispose() {
    promptController.dispose();
    scrollController.dispose();
    codelessly.dispose();
    super.dispose();
  }

  /// The user's message bubbles.
  Widget rightBubble(BuildContext context, String text) {
    return Bubble(
      margin: const BubbleEdges.all(4),
      nip: BubbleNip.rightBottom,
      alignment: Alignment.centerRight,
      color: rightColor,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Text(text, style: rightStyle),
      ),
    );
  }

  /// The CodelesslyGPT's message bubbles.
  Widget leftBubble(BuildContext context, String text) {
    return Bubble(
      margin: const BubbleEdges.all(4),
      nip: BubbleNip.leftBottom,
      alignment: Alignment.centerLeft,
      color: leftColor,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Text(text, style: leftStyle),
      ),
    );
  }

  /// The CodelesslyGPT's SDK message bubbles.
  Widget sdkBubble(BuildContext context, String layoutID) {
    return Bubble(
      margin: const BubbleEdges.only(left: 4, right: 4, bottom: 4),
      padding: const BubbleEdges.all(2),
      alignment: Alignment.centerLeft,
      color: leftColor,
      child: Container(
        height: 400,
        clipBehavior: Clip.antiAlias,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
        ),
        child: CodelesslyWidget(
          layoutID: layoutID,
          codelessly: codelessly,
        ),
      ),
    );
  }

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
      decoration: BoxDecoration(color: leftColor),
      child: CodelesslyWidget(
        layoutID: layoutID,
        codelessly: codelessly,
        isPreview: false,
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
          'Aurora Aksnes (born 15 June 1996), known mononymously'
          'as Aurora, is a Norwegian singer, songwriter and record'
          "producer. Here's what I found about here:",
        ),
        sdkBubbleCentered(context, layouts[2]),
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
    if (chatProgress == 0) {
      codelessly.init();
    }

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
    await codelessly.resetAndClearCache();

    // Unblock the UI (send button).
    if (mounted) {
      setState(() {
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        leading: SizedBox(
          child: Image.asset(
            'packages/codelessly_sdk/assets/codelessly_logo.png',
          ),
        ),
        automaticallyImplyLeading: false,
        title: const Text('CodelesslyGPT'),
        actions: [
          IconButton(
            onPressed: busy ? null : reset,
            icon: busy
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      color: rightColor,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.restart_alt),
            tooltip: 'Clear cache & reset chat',
          )
        ],
        shadowColor: const Color(0x8D000000),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF5C69E5),
        centerTitle: true,
        titleSpacing: 0,
        titleTextStyle: GoogleFonts.getFont(
          'Poppins',
          color: const Color(0xFF5C69E5),
          fontSize: 18,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Scrollbar(
                controller: scrollController,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: false),
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          leftBubble(
                              context, 'Hi, how can I assist you today?'),
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
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                clipBehavior: Clip.hardEdge,
                constraints: const BoxConstraints(maxWidth: 800),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A000000),
                      spreadRadius: 0,
                      offset: Offset(0, -4),
                      blurRadius: 6,
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: promptController,
                          readOnly: true,
                          decoration: InputDecoration(
                            icon: const Material(
                              color: Colors.transparent,
                              shape: CircleBorder(),
                              clipBehavior: Clip.hardEdge,
                              child: Icon(
                                Icons.add,
                                size: 24,
                                color: Color(0xFF5C69E5),
                              ),
                            ),
                            labelStyle: GoogleFonts.getFont(
                              'Roboto',
                              color: Colors.black,
                              fontSize: 14,
                            ),
                            errorStyle: GoogleFonts.getFont(
                              'Roboto',
                              color: const Color(0xFFFF0000),
                              fontSize: 12,
                            ),
                            errorMaxLines: 1,
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 16),
                            suffixIcon: Material(
                              color: Colors.transparent,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.hardEdge,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.mic_none,
                                  size: 24,
                                  color: Color(0xFF5C69E5),
                                ),
                                onPressed: () {},
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            focusColor: Colors.black,
                            hoverColor: const Color(0x197F7F7F),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(100.0),
                              borderSide: const BorderSide(
                                color: Color(0xFFFF0000),
                                width: 3,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(100.0),
                              borderSide: const BorderSide(
                                color: Color(0xFF5C69E5),
                                width: 2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(100.0),
                              borderSide: const BorderSide(
                                color: Color(0xFF5C69E5),
                                width: 2,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(100.0),
                              borderSide: const BorderSide(
                                color: Color(0xFF5C69E5),
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(100.0),
                              borderSide: const BorderSide(
                                color: Color(0xFF5C69E5),
                                width: 2,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(100.0),
                              borderSide: const BorderSide(
                                color: Color(0xFF5C69E5),
                                width: 2,
                              ),
                            ),
                            alignLabelWithHint: true,
                          ),
                          keyboardType: TextInputType.text,
                          style: GoogleFonts.getFont(
                            'Roboto',
                            color: Colors.black,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.left,
                          autofocus: true,
                          autocorrect: false,
                          cursorHeight: 14,
                          cursorRadius: const Radius.circular(2),
                          cursorColor: const Color(0xFF5C69E5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox.square(
                      dimension: 40,
                      child: TextButton(
                        onPressed:
                            chatProgress % 2 == 0 && chatProgress < 6 && !busy
                                ? progressChat
                                : null,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0x005C69E5),
                          foregroundColor: const Color(0xFF5C69E5),
                          shadowColor: const Color(0xFFA5A5A5),
                          padding: EdgeInsets.zero,
                          textStyle: GoogleFonts.getFont(
                            'Roboto',
                            color: const Color(0xFF5C69E5),
                            fontSize: 13,
                          ),
                          shape: const CircleBorder(
                            side: BorderSide(
                              color: Color(0xFF5C69E5),
                              width: 2,
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOutQuart,
                          switchOutCurve: Curves.easeInQuart,
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: chatProgress % 2 != 0
                              ? SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    color: rightColor,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.send,
                                  size: 20,
                                  color: Color(0xFF5C69E5),
                                ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
