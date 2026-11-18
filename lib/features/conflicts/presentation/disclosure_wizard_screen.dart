import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/active_org_store.dart';
import 'package:legalhub/app/legalhub_motion.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/compliance/domain/compliance_gateway.dart';
import 'package:legalhub/features/conflicts/data/matter_gateway_conflict_search_source.dart';
import 'package:legalhub/features/conflicts/domain/conflict_disclosure.dart';
import 'package:legalhub/features/conflicts/presentation/disclosure_cubit.dart';
import 'package:legalhub/features/matters/domain/matter.dart';
import 'package:legalhub/features/matters/domain/matter_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

part 'disclosure_steps.dart';

/// One route, wizard state in a Cubit, steps as views — the /book pattern.
/// No shell destination; no data travels in route parameters.
class DisclosureWizardScreen extends StatelessWidget {
  const DisclosureWizardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DisclosureCubit>(
      create: (BuildContext context) => DisclosureCubit(
        matters: serviceLocator<MatterGateway>(),
        search: MatterGatewayConflictSearchSource(
          serviceLocator<MatterGateway>(),
        ),
        alerts: serviceLocator<ComplianceAlertsGateway>(),
        org: serviceLocator<ActiveOrgStore>(),
      )..loadMatters(),
      child: const _DisclosureWizard(),
    );
  }
}
