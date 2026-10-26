import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:legalhub/app/legalhub_theme.dart';
import 'package:legalhub/app/router.dart';
import 'package:legalhub/app/service_locator.dart';
import 'package:legalhub/core/practice_area.dart';
import 'package:legalhub/core/state/view_state.dart';
import 'package:legalhub/features/booking/domain/booking_prefill.dart';
import 'package:legalhub/features/discovery/domain/attorney.dart';
import 'package:legalhub/features/discovery/domain/attorney_gateway.dart';
import 'package:legalhub/l10n/app_localizations.dart';
import 'package:legalhub/shared/demo_labels.dart';
import 'package:legalhub/shared/widgets/widgets.dart';

import 'discovery_cubit.dart';
import 'discovery_state.dart';

part 'attorney_profile_surface.dart';

/// Attorney profile surface (Phase 6, slice 6.2).
///
/// Read-only (D-A1): renders the synthetic non-PII profile — name, practice
/// area, locale, short bio (D-A4) — plus the local-only demo note (R1). The
/// "Book with this attorney" action pre-fills the booking wizard's draft with
/// an optional `attorneyId`/name via the transient [BookingPrefill] holder
/// (D-A3, the D-B7 additive slice) and navigates to `/book` — the wizard
/// itself is untouched (no attorney step, spec row 153; nothing travels in
/// route params or GoRouter `extra`, D-B4).
class AttorneyProfileScreen extends StatelessWidget {
  const AttorneyProfileScreen({required this.attorneyId, super.key});

  final String attorneyId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DiscoveryCubit>(
      create: (BuildContext context) =>
          DiscoveryCubit(serviceLocator<AttorneyGateway>()),
      child: _ProfileSurface(attorneyId: attorneyId),
    );
  }
}
