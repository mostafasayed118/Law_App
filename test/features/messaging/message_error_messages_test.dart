import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/features/messaging/presentation/message_error_messages.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  group('messageSendErrorMessage', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));

    test('maps the client-side length code to the max-length copy', () {
      expect(
        messageSendErrorMessage(
          en,
          const AppError(
            code: 'message_too_long',
            userMessage: 'provider copy',
          ),
        ),
        'Message is too long. The maximum is 2000 characters.',
      );
    });

    test('maps a denial kind to the denied copy', () {
      expect(
        messageSendErrorMessage(
          en,
          const AppError(
            code: 'message_send_denied',
            userMessage: 'provider copy',
            kind: AppErrorKind.denied,
          ),
        ),
        'You do not have permission to send messages on this thread.',
      );
    });

    test('maps an unavailable kind to the retry copy', () {
      expect(
        messageSendErrorMessage(
          en,
          const AppError(
            code: 'message_send_unavailable',
            userMessage: 'provider copy',
            kind: AppErrorKind.unavailable,
          ),
        ),
        'Sending is temporarily unavailable. Please try again.',
      );
    });

    test('maps everything else to the generic failure copy', () {
      expect(
        messageSendErrorMessage(
          en,
          const AppError(
            code: 'message_send_failed',
            userMessage: 'provider copy',
          ),
        ),
        'Unable to send the message. Please try again.',
      );
    });

    test('localizes the max-length copy', () {
      expect(
        messageSendErrorMessage(
          ar,
          const AppError(
            code: 'message_too_long',
            userMessage: 'provider copy',
          ),
        ),
        'الرسالة طويلة جدًا. الحد الأقصى 2000 حرفًا.',
      );
    });
  });
}
