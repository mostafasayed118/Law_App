import '../../../core/errors/result.dart';
import 'pending_approval.dart';

/// Pending-approvals integration boundary (v1 queue, 2026-08-09).
///
/// **Read-only demo surface.** The approvals queue is conceptually coupled to
/// the human-review workflows (conflicts/waivers/walls/filings — D-06/D-03);
/// those stay deferred, so this demo fake serves synthetic generic rows only
/// and never implies a real approval authority (INSTRUCTIONS §4.4).
abstract interface class ApprovalsGateway {
  Future<Result<List<PendingApproval>>> fetchApprovals();
}
