import 'package:flutter_common/support/support_chat_send.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatSendError maps RLS failures to a clear closed/mismatch hint', () {
    final formatted = supportChatFormatSendError(
      Exception(
        'PostgrestException(message: new row violates row-level security '
        'policy for table "support_messages", code: 42501)',
      ),
    );
    expect(formatted, contains('conversation closed or user mismatch'));
  });

  test('formatSendError keeps plain StateError text', () {
    expect(
      supportChatFormatSendError(
        StateError(
          'Conversation is closed. Wait for the customer to message again.',
        ),
      ),
      'Conversation is closed. Wait for the customer to message again.',
    );
  });

  test('failed text message stores error in metadata', () {
    final failed = supportChatFailedTextMessage(
      id: 'local-text-1',
      authorId: 'agent',
      text: 'hi',
      createdAt: DateTime.utc(2026, 1, 1),
      error: 'Conversation is closed',
    );
    expect(supportChatSendErrorFromMessage(failed), 'Conversation is closed');
  });
}
