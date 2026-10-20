import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/features/tasks/presentation/task_error_messages.dart';
import 'package:legalhub/l10n/app_localizations.dart';

void main() {
  group('taskErrorMessage', () {
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

    test('maps a denial kind to the denied copy', () {
      expect(
        taskErrorMessage(
          en,
          const AppError(
            code: 'task_create_denied',
            userMessage: 'provider copy',
            kind: AppErrorKind.denied,
          ),
        ),
        'You do not have permission to do that.',
      );
    });

    test('maps an unavailable kind to the retry copy', () {
      expect(
        taskErrorMessage(
          en,
          const AppError(
            code: 'task_assign_unavailable',
            userMessage: 'provider copy',
            kind: AppErrorKind.unavailable,
          ),
        ),
        'This is temporarily unavailable. Please try again.',
      );
    });

    test('maps an _invalid code to the validation copy', () {
      expect(
        taskErrorMessage(
          en,
          const AppError(
            code: 'task_create_invalid',
            userMessage: 'provider copy',
          ),
        ),
        'That change is not valid. Check the details and try again.',
      );
    });

    test('maps everything else to the generic failure copy', () {
      expect(
        taskErrorMessage(
          en,
          const AppError(
            code: 'task_read_failed',
            userMessage: 'provider copy',
          ),
        ),
        'Something went wrong. Please try again.',
      );
    });
  });
}
