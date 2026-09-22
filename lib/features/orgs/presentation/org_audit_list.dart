part of 'org_audit_screen.dart';

class _AuditList extends StatelessWidget {
  const _AuditList({required this.entries});

  final List<AuditEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(
        LegalHubTheme.marginMobile,
        LegalHubTheme.spaceSm,
        LegalHubTheme.marginMobile,
        LegalHubTheme.marginMobile,
      ),
      itemCount: entries.length,
      separatorBuilder: (BuildContext context, int index) =>
          SizedBox(height: LegalHubTheme.spaceSm),
      itemBuilder: (BuildContext context, int index) =>
          _AuditRow(entry: entries[index]),
    );
  }
}
