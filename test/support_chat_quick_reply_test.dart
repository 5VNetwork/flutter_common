import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_common/support/support_chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('quick reply chip sends the canned message', (tester) async {
    final sent = <String>[];
    final controller = InMemoryChatController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Chat(
            currentUserId: 'agent',
            resolveUser: (id) async => User(id: id),
            chatController: controller,
            onMessageSend: sent.add,
            builders: supportChatBuilders(
              quickReplies: const [
                SupportChatQuickReply(label: 'Hi', message: 'Hello there'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(ActionChip, 'Hi'));
    await tester.pump();
    // EmptyChatList starts a 50ms timer on first layout.
    await tester.pump(const Duration(milliseconds: 60));

    expect(sent, ['Hello there']);
  });

  testWidgets('edit chip does not send a message', (tester) async {
    final sent = <String>[];
    var edited = false;
    final controller = InMemoryChatController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Chat(
            currentUserId: 'agent',
            resolveUser: (id) async => User(id: id),
            chatController: controller,
            onMessageSend: sent.add,
            builders: supportChatBuilders(
              quickReplies: const [
                SupportChatQuickReply(label: 'Hi', message: 'Hello there'),
              ],
              onEditQuickReplies: () => edited = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(ActionChip, 'Edit'));
    await tester.pump(const Duration(milliseconds: 60));

    expect(edited, isTrue);
    expect(sent, isEmpty);
  });

  testWidgets('quick reply chips wrap onto multiple rows', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = InMemoryChatController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Chat(
            currentUserId: 'agent',
            resolveUser: (id) async => User(id: id),
            chatController: controller,
            onMessageSend: (_) {},
            builders: supportChatBuilders(
              quickReplies: const [
                SupportChatQuickReply(label: 'One'),
                SupportChatQuickReply(label: 'Two'),
                SupportChatQuickReply(label: 'Three'),
                SupportChatQuickReply(label: 'Four'),
                SupportChatQuickReply(label: 'Five'),
                SupportChatQuickReply(label: 'Six'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final first = tester.getTopLeft(find.widgetWithText(ActionChip, 'One'));
    final last = tester.getTopLeft(find.widgetWithText(ActionChip, 'Six'));
    expect(last.dy, greaterThan(first.dy));
  });
}
