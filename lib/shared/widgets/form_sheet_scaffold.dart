import 'package:flutter/material.dart';

import 'package:legalhub/app/legalhub_theme.dart';

/// Shared shell for the app's create-form bottom sheets.
///
/// The approvals, compliance-alert, and video create sheets repeated the same
/// `SafeArea` → keyboard-inset padding → `SingleChildScrollView` → stretch
/// `Column` scaffold around a `titleLarge` heading. This widget owns that
/// shell only: a title, the caller's body in render order, and an optional
/// trailing action bar (the submit/cancel buttons). Domain fields, validation,
/// and submit logic stay with each feature.
class FormSheetScaffold extends StatelessWidget {
  const FormSheetScaffold({
    required this.title,
    required this.body,
    this.actions,
    super.key,
  });

  /// The sheet heading, already localized by the caller.
  final String title;

  /// The sheet body in render order (banners, form fields, inline errors).
  final List<Widget> body;

  /// Optional trailing action bar rendered after [body].
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: LegalHubTheme.spaceMd),
              ...body,
              ...?actions,
            ],
          ),
        ),
      ),
    );
  }
}
