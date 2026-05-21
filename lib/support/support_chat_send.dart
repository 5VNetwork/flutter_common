import 'package:flutter_chat_core/flutter_chat_core.dart';

/// Local id prefix for outbound text not yet confirmed by the server.
const supportChatLocalTextIdPrefix = 'local-text-';

/// Local id prefix for outbound images still uploading.
const supportChatLocalImageIdPrefix = 'local-image-';

String supportChatNewLocalTextId() =>
    '$supportChatLocalTextIdPrefix${DateTime.now().microsecondsSinceEpoch}';

bool isSupportLocalTextId(String id) => id.startsWith(supportChatLocalTextIdPrefix);

bool isSupportLocalImageId(String id) => id.startsWith(supportChatLocalImageIdPrefix);

bool isSupportLocalOutboundId(String id) =>
    isSupportLocalTextId(id) || isSupportLocalImageId(id);

Message supportChatPendingTextMessage({
  required String id,
  required String authorId,
  required String text,
}) {
  return Message.text(
    id: id,
    authorId: authorId,
    createdAt: DateTime.now(),
    text: text,
    status: MessageStatus.sending,
  );
}

Message supportChatFailedTextMessage({
  required String id,
  required String authorId,
  required String text,
  required DateTime createdAt,
}) {
  return Message.text(
    id: id,
    authorId: authorId,
    createdAt: createdAt,
    text: text,
    status: MessageStatus.error,
    failedAt: DateTime.now(),
  );
}

/// Pending outbound bubble that matches [incoming] (same author + content).
Message? supportChatFindPendingOutbound({
  required List<Message> messages,
  required Message incoming,
}) {
  if (incoming is TextMessage) {
    for (final message in messages) {
      if (message is! TextMessage) continue;
      if (!isSupportLocalTextId(message.id)) continue;
      if (message.authorId != incoming.authorId) continue;
      if (message.text != incoming.text) continue;
      return message;
    }
    return null;
  }

  if (incoming is ImageMessage) {
    for (final message in messages) {
      if (message is! ImageMessage) continue;
      if (!isSupportLocalImageId(message.id)) continue;
      if (message.authorId != incoming.authorId) continue;
      return message;
    }
  }

  return null;
}

/// Realtime/API message: replace matching pending bubble instead of inserting a duplicate.
Future<void> supportChatInsertOrReconcileIncoming({
  required ChatController controller,
  required Message incoming,
}) async {
  if (controller.messages.any((message) => message.id == incoming.id)) {
    return;
  }

  final pending = supportChatFindPendingOutbound(
    messages: controller.messages,
    incoming: incoming,
  );
  if (pending != null) {
    await controller.updateMessage(pending, incoming);
    return;
  }

  await controller.insertMessage(incoming);
}

/// After send succeeds: swap pending → server message without remove+insert flicker.
Future<void> supportChatConfirmOutbound({
  required ChatController controller,
  required Message pending,
  required Message delivered,
}) async {
  final messages = controller.messages;

  if (!messages.any((message) => message.id == pending.id)) {
    if (!messages.any((message) => message.id == delivered.id)) {
      await controller.insertMessage(delivered);
    }
    return;
  }

  if (messages.any((message) => message.id == delivered.id)) {
    await controller.removeMessage(pending);
    return;
  }

  await controller.updateMessage(pending, delivered);
}

/// Inserts [pending], runs [send], then confirms with the server message.
Future<void> supportChatDeliverOutboundText({
  required ChatController controller,
  required Message pending,
  required Future<Message> Function() send,
}) async {
  try {
    final delivered = await send();
    await supportChatConfirmOutbound(
      controller: controller,
      pending: pending,
      delivered: delivered,
    );
  } catch (_) {
    final textMessage = pending as TextMessage;
    await controller.updateMessage(
      pending,
      supportChatFailedTextMessage(
        id: textMessage.id,
        authorId: textMessage.authorId,
        text: textMessage.text,
        createdAt: textMessage.createdAt ?? DateTime.now(),
      ),
    );
  }
}
