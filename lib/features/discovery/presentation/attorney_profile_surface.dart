part of 'attorney_profile_screen.dart';

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
    // Load the profile by id on open (the roster pattern): the cubit's
    // initial profile state is already loading, so the first frame settles
    // straight into the detail once the read lands.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<DiscoveryCubit>().loadProfile(widget.attorneyId);
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
            return switch (state.profile) {
              ViewLoading() => const Center(child: CircularProgressIndicator()),
              ViewEmpty() => AppCenteredMessage(
                text: l10n.discoveryProfileNotFound,
              ),
              ViewError() => AppCenteredRetry(
                message: l10n.discoveryError,
                onRetry: () => context.read<DiscoveryCubit>().loadProfile(
                  widget.attorneyId,
                ),
                retryLabel: l10n.retry,
              ),
              ViewOffline() => AppCenteredRetry(
                message: l10n.discoveryError,
                onRetry: () => context.read<DiscoveryCubit>().loadProfile(
                  widget.attorneyId,
                ),
                retryLabel: l10n.retry,
              ),
              ViewUnauthorized() => AppCenteredMessage(
                text: l10n.stateUnauthorized,
              ),
              ViewSuccess(data: final Attorney attorney) => _profile(
                context,
                attorney,
              ),
            };
          },
        ),
      ),
    );
  }

  Widget _profile(BuildContext context, Attorney attorney) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String summary = _summaryLine(l10n, attorney);
    return ListView(
      padding: const EdgeInsetsDirectional.all(LegalHubTheme.marginMobile),
      children: <Widget>[
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              _initialOf(attorney.name),
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
        if (attorney.headline != null) ...<Widget>[
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(
            attorney.headline!,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        if (summary.isNotEmpty) ...<Widget>[
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(
            summary,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        if (attorney.city != null) ...<Widget>[
          const SizedBox(height: LegalHubTheme.spaceXs),
          Text(
            attorney.city!,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        if (attorney.yearsExperience != null) ...<Widget>[
          const SizedBox(height: LegalHubTheme.spaceXs),
          Text(
            l10n.discoveryProfileYears(attorney.yearsExperience!),
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        if (attorney.specialties.isNotEmpty) ...<Widget>[
          const SizedBox(height: LegalHubTheme.spaceXl),
          _SectionLabel(text: l10n.discoveryProfileSpecialties),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Wrap(
            spacing: LegalHubTheme.spaceSm,
            runSpacing: LegalHubTheme.spaceSm,
            children: <Widget>[
              for (final String specialty in attorney.specialties)
                LabelChip(
                  label: _specialtyLabel(l10n, specialty),
                  background: scheme.secondaryContainer,
                  foreground: scheme.onSecondaryContainer,
                  style: text.labelLarge,
                  maxLines: null,
                ),
            ],
          ),
        ],
        if (attorney.languages.isNotEmpty) ...<Widget>[
          const SizedBox(height: LegalHubTheme.spaceLg),
          _SectionLabel(text: l10n.discoveryProfileLanguages),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(attorney.languages.join(' · '), style: text.bodyMedium),
        ],
        if (attorney.bio.isNotEmpty) ...<Widget>[
          const SizedBox(height: LegalHubTheme.spaceXl),
          _SectionLabel(text: l10n.discoveryProfileBio),
          const SizedBox(height: LegalHubTheme.spaceSm),
          Text(demoAttorneyBio(l10n, attorney.bio), style: text.bodyMedium),
        ],
        const SizedBox(height: LegalHubTheme.spaceLg),
        Text(
          backendIsLocalOnly
              ? l10n.discoveryLocalOnlyNote
              : l10n.discoveryDirectoryNote,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: LegalHubTheme.spaceLg),
        ElevatedButton.icon(
          onPressed: () => _book(context, attorney),
          icon: const Icon(Icons.event_available_outlined),
          label: Text(l10n.discoveryProfileBook),
        ),
      ],
    );
  }

  /// D-A3: pre-fill the booking draft via the transient holder, then navigate.
  /// The attorney id is passed only when it is a real UUID — a synthetic
  /// `atty-*` row from an env-less build never reaches the booking RPC.
  void _book(BuildContext context, Attorney attorney) {
    final BookingPrefill prefill = serviceLocator<BookingPrefill>();
    prefill.attorneyId = attorney.hasRealId ? attorney.id : null;
    prefill.attorneyName = attorney.name;
    context.push(AppRoutes.book);
  }

  String _initialOf(String name) =>
      name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

  String _summaryLine(AppLocalizations l10n, Attorney attorney) {
    final List<String> parts = <String>[
      if (attorney.practiceArea != null)
        practiceAreaLabel(l10n, attorney.practiceArea!),
      if (attorney.locale.isNotEmpty) attorney.locale,
    ];
    return parts.join(' · ');
  }

  String _specialtyLabel(AppLocalizations l10n, String specialty) {
    for (final PracticeArea area in PracticeArea.values) {
      if (area.name == specialty.trim().toLowerCase()) {
        return practiceAreaLabel(l10n, area);
      }
    }
    return specialty;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
