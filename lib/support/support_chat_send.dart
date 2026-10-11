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

/// Metadata key for the human-readable reason a text send failed.
const supportChatSendErrorMetadataKey = 'supportChatSendError';

Message supportChatFailedTextMessage({
  required String id,
  required String authorId,
  required String text,
  required DateTime createdAt,
  String? error,
}) {
  return Message.text(
    id: id,
    authorId: authorId,
    createdAt: createdAt,
    text: text,
    status: MessageStatus.error,
    failedAt: DateTime.now(),
    metadata: error == null || error.trim().isEmpty
        ? null
        : {supportChatSendErrorMetadataKey: error.trim()},
  );
}

String? supportChatSendErrorFromMessage(Message message) {
  final value = message.metadata?[supportChatSendErrorMetadataKey];
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
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

/// Runs [send] for an already-inserted [pending] bubble.
///
/// Returns `null` on success, or a short error string after marking the bubble
/// failed.
Future<String?> supportChatDeliverOutboundText({
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
    return null;
  } catch (error) {
    final textMessage = pending as TextMessage;
    final reason = supportChatFormatSendError(error);
    await controller.updateMessage(
      pending,
      supportChatFailedTextMessage(
        id: textMessage.id,
        authorId: textMessage.authorId,
        text: textMessage.text,
        createdAt: textMessage.createdAt ?? DateTime.now(),
        error: reason,
      ),
    );
    return reason;
  }
}

/// Turns a send exception into a short string for the bubble / snackbar.
String supportChatFormatSendError(Object error) {
  final raw = error.toString().trim();
  var message = raw;
  const prefixes = [
    'Exception: ',
    'StateError: ',
    'Bad state: ',
    'PostgrestException: ',
  ];
  for (final prefix in prefixes) {
    if (message.startsWith(prefix)) {
      message = message.substring(prefix.length).trim();
      break;
    }
  }

  final lower = message.toLowerCase();
  if (lower.contains('row-level security') ||
      lower.contains('violates row-level security')) {
    return 'Send blocked (conversation closed or user mismatch). '
        'If the chat was closed, wait for the customer to message again.';
  }
  if (message.isEmpty) return 'Unknown send error';
  return message;
}
