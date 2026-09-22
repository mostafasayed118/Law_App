import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/legalhub_theme.dart';
import '../../../app/service_locator.dart';
import '../../../features/auth/presentation/auth_cubit.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/message.dart';
import '../domain/message_gateway.dart';
import 'message_thread_detail_cubit.dart';
import 'message_thread_detail_state.dart';
part 'message_thread_detail_surface.dart';
part 'message_thread_detail_tile.dart';
part 'message_thread_composer.dart';

/// Thread-detail surface (sixth §14 un-deferral, realtime slice D-RT5;
/// realtime push slice D-LV1/D-LV4).
///
/// The **first thread-open affordance**: tapping a thread row in the list
/// opens this screen, which loads that thread's message rows from the
/// [MessageGateway] seam (the dev fake in env-less runs, the env-gated
/// Supabase implementation in configured builds), subscribes to live INSERT
/// delivery (D-LV4), and renders them. This is the surface where message
/// **bodies** first appear — the D-MSG1 consummation, scoped to the real
/// read path. The **composer is the write surface (D-LV1) — insert-only**: a
/// single message field + send; there is deliberately **no edit, no delete,
/// no attachment affordance** (no edit/delete/attachments/read-receipts),
/// and the local-only demo note keeps the synthetic list honest (R1).
class MessageThreadDetailScreen extends StatelessWidget {
  const MessageThreadDetailScreen({
    required this.threadId,
    this.threadTitle,
    super.key,
  });

  final String threadId;

  /// The tapped row's title, passed by the list route (D-RT5/Q3: the title
  /// is already client-side — no embed is needed). Falls back to the
  /// localized generic title when absent (e.g. a deep link with no extra).
  final String? threadTitle;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MessageThreadDetailCubit>(
      create: (BuildContext context) =>
          MessageThreadDetailCubit(serviceLocator<MessageGateway>()),
      child: _DetailSurface(threadId: threadId, threadTitle: threadTitle),
    );
  }
}
