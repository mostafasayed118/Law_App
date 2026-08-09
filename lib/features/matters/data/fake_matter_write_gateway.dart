import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../domain/matter_write_gateway.dart';

/// Development-only matter-creation implementation (F-01 step 2 client swap,
/// C-D3): a deterministic in-memory create path that mirrors the server
/// gates the battery pins — the platform-owner refusal (F2-D2, battery
/// 12/13), the active-member assignee guard (F2-D4), and the blank-title
/// validation — WITHOUT a provider.
///
/// No real backend (the env-gate convention: env-less runs and ALL tests
/// keep the fake): [createMatter] returns a deterministic id (a counter, so
/// tests are stable — never clock- or randomness-based), refuses the
/// fixture platform-owner id as an assignee with `matter_write_owner_forbidden`
/// (the fake honors the same invariant the batteries pin), rejects blank
/// titles and non-member assignees, and records created matters
/// **instance-scoped** (the fake determinism pin — the future fake-read
/// handoff (design Q4) would share state via a static list at that point).
class FakeMatterWriteGateway implements MatterWriteGateway {
  /// The fixture platform-owner id (mirrors `supabase/tests/00_fixtures.sql`
  /// row `10000000-…-0001` — the owner the batteries pin as never
  /// assignable). The fake refuses it as client or attorney, mirroring the
  /// RPC's F2-D2 refusal.
  static const String platformOwnerId = '10000000-0000-4000-8000-000000000001';

  /// The demo org id (mirrors `FakeOrganizationGateway.demoOrganizationId`).
  static const String demoOrganizationId = 'org-demo';

  /// The fake's roster = the demo org's active members (mirrors the
  /// `FakeOrganizationGateway` seed: the demo org has exactly one member —
  /// the demo user). The assignee dropdowns (roster seam) offer exactly
  /// this set in env-less runs, so the fake and the form stay consistent.
  static const Map<String, String> roster = <String, String>{
    'demo-user': 'Demo user',
  };

  /// Instance-scoped created matters (the determinism pin): a test or dev
  /// run sees only its own creates, never shared state.
  final List<CreatedMatter> _created = <CreatedMatter>[];

  /// The matters created through this instance, in creation order.
  List<CreatedMatter> get created => List<CreatedMatter>.unmodifiable(_created);

  @override
  Future<Result<CreatedMatter>> createMatter(
    CreateMatterRequest request,
  ) async {
    // F2-D1 mirror: the fake knows one org; any other id is a denial (the
    // RPC's `permission denied` for a non-partner/cross-org caller).
    if (request.organizationId != demoOrganizationId) {
      return _failure(
        'matter_write_denied',
        'You do not have permission to create matters in this organization.',
      );
    }
    // F2-D2 mirror (checked before F2-D4, mirroring the RPC's order): the
    // platform-owner id is never assignable.
    if (request.assignedClientId == platformOwnerId ||
        request.assignedAttorneyId == platformOwnerId) {
      return _failure(
        'matter_write_owner_forbidden',
        'The platform owner cannot be assigned to a matter.',
      );
    }
    // F2-D4 mirror: an assignee must be an active member of the org.
    if (request.assignedClientId != null &&
        !roster.containsKey(request.assignedClientId)) {
      return _failure(
        'matter_write_assignee_invalid',
        'The assigned member is not an active member of this organization.',
      );
    }
    if (request.assignedAttorneyId != null &&
        !roster.containsKey(request.assignedAttorneyId)) {
      return _failure(
        'matter_write_assignee_invalid',
        'The assigned member is not an active member of this organization.',
      );
    }
    // Validation mirror: trimmed non-empty title (the RPC's check).
    if (request.title.trim().isEmpty) {
      return _failure('matter_write_validation', 'A matter title is required.');
    }
    final CreatedMatter created = CreatedMatter(
      id: 'created-${_created.length + 1}',
      title: request.title.trim(),
      practiceArea: request.practiceArea,
    );
    _created.add(created);
    return Result<CreatedMatter>.success(created);
  }

  Result<CreatedMatter> _failure(String code, String userMessage) {
    return Result<CreatedMatter>.failure(
      AppError(code: code, userMessage: userMessage),
    );
  }
}
