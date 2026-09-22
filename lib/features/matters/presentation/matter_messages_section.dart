import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/service_locator.dart';
import '../../../features/messaging/domain/message_gateway.dart';
import '../../../features/messaging/domain/message_thread.dart';
import '../../../features/messaging/presentation/message_cubit.dart';
import '../../../features/messaging/presentation/message_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/formatting/date_formatting.dart';
import '../../../shared/widgets/widgets.dart';

part 'matter_messages_section_body.dart';

/// Per-matter Messages section on the matter details surface (Phase 10,
/// slice 10.1, owner decisions D-W1/D-W3/D-W4).
///
/// Provides its own [MessageCubit] (feature-scoped, per-section
/// `BlocProvider`) and renders the subset of the synthetic thread list whose
/// [MessageThread.matterRef] equals [matterRef] — a client-side view over the
/// fake list (the D-M5 pattern; there is no per-matter fetch). **Thread
/// metadata only**: each row renders the D-MSG4 title/participants/date
/// fields and nothing else — no message body, no preview, no thread-open
/// affordance, no composer (D-W4 body-less line). An empty per-matter subset
/// renders the localized empty copy (AC-3).
class MatterMessagesSection extends StatelessWidget {
  const MatterMessagesSection({required this.matterRef, super.key});

  /// The matter title to filter by (matches [MessageThread.matterRef],
  /// D-MSG4/D-W2).
  final String matterRef;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MessageCubit>(
      create: (BuildContext context) =>
          MessageCubit(serviceLocator<MessageGateway>()),
      child: _MessagesSectionBody(matterRef: matterRef),
    );
  }
}
