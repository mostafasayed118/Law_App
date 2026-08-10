import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/legalhub_theme.dart';
import '../../../app/router.dart';
import '../../../app/service_locator.dart';
import '../../../core/state/view_state.dart';
import '../../../features/booking/domain/booking_prefill.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/attorney.dart';
import '../domain/attorney_gateway.dart';
import 'discovery_cubit.dart';
import 'discovery_state.dart';

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

class _ProfileSurface extends StatefulWidget {
  const _ProfileSurface({required this.attorneyId});

  final String attorneyId;

  @override
  State<_ProfileSurface> createState() => _ProfileSurfaceState();
}

class _ProfileSurfaceState extends State<_ProfileSurface> {
  @override
  void initState() {
    super.initState();
    // Load the synthetic list on open (same pattern as the search surface);
    // the profile is resolved from the loaded list by id.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<DiscoveryCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.discoveryProfileTitle)),
      body: SafeArea(
        child: BlocBuilder<DiscoveryCubit, DiscoveryState>(
          builder: (BuildContext context, DiscoveryState state) {
            return switch (state.attorneys) {
              ViewLoading() => const Center(child: CircularProgressIndicator()),
              ViewEmpty() => AppCenteredMessage(
                text: l10n.discoveryProfileNotFound,
              ),
              ViewError() => AppCenteredRetry(
                message: l10n.discoveryError,
                onRetry: context.read<DiscoveryCubit>().load,
                retryLabel: l10n.retry,
              ),
              // The sealed ViewState set also carries offline/unauthorized
              // variants (shared vocabulary); a synthetic list has neither
              // state, so both render the not-found copy.
              ViewOffline() || ViewUnauthorized() => AppCenteredMessage(
                text: l10n.discoveryProfileNotFound,
              ),
              ViewSuccess(data: final List<Attorney> attorneys) => _profile(
                context,
                _findById(attorneys, widget.attorneyId),
              ),
            };
          },
        ),
      ),
    );
  }

  Attorney? _findById(List<Attorney> attorneys, String id) {
    for (final Attorney attorney in attorneys) {
      if (attorney.id == id) {
        return attorney;
      }
    }
    return null;
  }

  Widget _profile(BuildContext context, Attorney? attorney) {
    if (attorney == null) {
      return AppCenteredMessage(
        text: AppLocalizations.of(context).discoveryProfileNotFound,
      );
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      children: <Widget>[
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              attorney.name.isEmpty
                  ? '?'
                  : attorney.name.substring(0, 1).toUpperCase(),
              style: TextStyle(fontSize: 28, color: scheme.onPrimaryContainer),
            ),
          ),
        ),
        const SizedBox(height: LegalHubTheme.spaceLg),
        Text(
          attorney.name,
          textAlign: TextAlign.center,
          style: text.headlineMedium,
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        Text(
          '${practiceAreaLabel(l10n, attorney.practiceArea)} · ${attorney.locale}',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: LegalHubTheme.spaceXl),
        Text(
          l10n.discoveryProfileBio,
          style: text.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: LegalHubTheme.spaceSm),
        Text(attorney.bio, style: text.bodyMedium),
        const SizedBox(height: LegalHubTheme.spaceLg),
        Text(
          l10n.discoveryLocalOnlyNote,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: LegalHubTheme.spaceLg),
        ElevatedButton.icon(
          onPressed: () {
            // D-A3: pre-fill the booking draft via the transient holder, then
            // navigate. Nothing travels in the URL or GoRouter extra (D-B4).
            final BookingPrefill prefill = serviceLocator<BookingPrefill>();
            prefill.attorneyId = attorney.id;
            prefill.attorneyName = attorney.name;
            context.go(AppRoutes.book);
          },
          icon: const Icon(Icons.event_available_outlined),
          label: Text(l10n.discoveryProfileBook),
        ),
      ],
    );
  }
}
