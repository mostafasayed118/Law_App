part of 'matter_create_screen.dart';

class _CreateSurface extends StatefulWidget {
  const _CreateSurface();

  @override
  State<_CreateSurface> createState() => _CreateSurfaceState();
}

class _CreateSurfaceState extends State<_CreateSurface> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  PracticeArea _practiceArea = PracticeArea.corporate;
  String? _assignedClientId;
  String? _assignedAttorneyId;

  /// The active org id, resolved once on open from the [ActiveOrgStore]
  /// (after the store re-seeds from the session — the hub pattern). Null
  /// means no org is selected for this session: the surface shows the honest
  /// no-org message instead of a silently dead form (review R-2).
  String? _organizationId;

  /// The active org's active members (the assignee options), loaded once on
  /// open via the roster seam; null while loading.
  List<OrgMember>? _members;

  @override
  void initState() {
    super.initState();
    _seedAndResolveOrg();
  }

  /// Mirrors the org hub's idempotent seed (ActiveOrgStore.syncFromSession
  /// keys on the session userId), so a cold start / deep link to
  /// `/matters/new` resolves the session's active org the same way a hub
  /// visit would — then reads the store.
  void _seedAndResolveOrg() {
    final ActiveOrgStore store = serviceLocator<ActiveOrgStore>();
    store.syncFromSession(serviceLocator<AuthCubit>().state.session);
    final String? organizationId = store.activeOrganizationId;
    _organizationId = organizationId;
    if (organizationId != null) {
      _loadMembers(organizationId);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadMembers(String organizationId) async {
    // The read lives behind the cubit (audit 2026-09-21, H-4): presentation no
    // longer touches OrganizationGateway directly. The F2-D4 active-member
    // filter moved with it.
    final List<OrgMember> members = await context
        .read<MatterCreateCubit>()
        .loadMembers(organizationId);
    if (!mounted) {
      return;
    }
    setState(() => _members = members);
  }

  Future<void> _submit() async {
    final String? organizationId = _organizationId;
    if (organizationId == null) {
      // The no-org message is already on screen (initState resolved null);
      // the guard keeps a race (org selected after open) from submitting
      // with a null routing hint.
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await context.read<MatterCreateCubit>().submit(
      CreateMatterRequest(
        organizationId: organizationId,
        title: _title.text,
        practiceArea: _practiceArea,
        assignedClientId: _assignedClientId,
        assignedAttorneyId: _assignedAttorneyId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String? organizationId = _organizationId;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.matterCreateTitle)),
      body: SafeArea(
        child: organizationId == null
            // Honest no-org state (review R-2): the create intent needs the
            // ACTIVE org id (a routing hint — the server re-derives
            // membership); without a selection the form would be a silent
            // dead end, so the surface says so instead.
            ? Padding(
                padding: const EdgeInsetsDirectional.all(
                  LegalHubTheme.marginMobile,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.matterCreateNoOrg,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : BlocBuilder<MatterCreateCubit, MatterCreateState>(
                builder: (BuildContext context, MatterCreateState state) {
                  return switch (state) {
                    MatterCreateSuccess(createdMatter: final created) =>
                      _SuccessView(
                        matterId: created.id,
                        onDone: () => context.pop(),
                      ),
                    MatterCreateSubmitting() ||
                    MatterCreateInitial() ||
                    MatterCreateFailure() => _FormView(
                      formKey: _formKey,
                      titleController: _title,
                      practiceArea: _practiceArea,
                      assignedClientId: _assignedClientId,
                      assignedAttorneyId: _assignedAttorneyId,
                      members: _members,
                      submitting: state is MatterCreateSubmitting,
                      error: state is MatterCreateFailure ? state.error : null,
                      onPracticeAreaChanged: (PracticeArea area) =>
                          setState(() => _practiceArea = area),
                      onClientChanged: (String? id) =>
                          setState(() => _assignedClientId = id),
                      onAttorneyChanged: (String? id) =>
                          setState(() => _assignedAttorneyId = id),
                      onSubmit: _submit,
                      scheme: scheme,
                    ),
                  };
                },
              ),
      ),
    );
  }
}
