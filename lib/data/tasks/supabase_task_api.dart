/// Provider-neutral task-board table seam.
///
/// The seam is the only surface the task gateway talks to: plain map rows
/// out, typed [SupabaseTaskException]s on failure. Provider types never
/// cross this boundary (same discipline as [SupabaseMessageApi]).
library;

/// Typed reasons a task read or write can fail, mapped from the PostgREST
/// surface. The reads are plain RLS-scoped SELECTs; the writes are the four
/// audited RPCs whose in-function gates raise the stable
/// `permission denied` text (the send_message D-SM1 shape) and whose
/// validation gates raise `using errcode = 'check_violation'` (surfaced by
/// PostgREST as SQLSTATE `23514` — the Batch B convention).
enum SupabaseTaskFailureKind {
  /// The caller is not permitted to read the rows or perform the write
  /// (RLS denied, the in-function assignment gate, the assignee-only
  /// acknowledge gate, or no session / no EXECUTE grant).
  denied,

  /// A write the server refused as invalid (empty title, illegal
  /// transition, terminal state, dead or owner assignee, unknown status).
  validation,

  /// The provider is unavailable or rate-limited.
  providerUnavailable,

  /// An unspecified failure.
  unknown,
}

/// A typed failure crossing the [SupabaseTaskApi] seam.
class SupabaseTaskException implements Exception {
  const SupabaseTaskException({required this.kind, required this.message});

  final SupabaseTaskFailureKind kind;
  final String message;

  @override
  String toString() => 'SupabaseTaskException(${kind.name}): $message';
}

/// Tasks table surface backed by the Supabase PostgREST client.
///
/// The read is RLS-scoped (`tasks_select_assigned`): the policy returns only
/// the rows whose matter the caller is assigned to (client or attorney) as
/// an active member of the task's org, with the org-mismatch equality
/// load-bearing. Rows carry ids + the embedded matter title — the gateway
/// resolves the VO's title-keyed `matterRef` from the embed, falling back to
/// the raw matter id (D-MSR4).
///
/// The writes are the four audited RPCs — the ONLY task write paths (no
/// INSERT/UPDATE/DELETE policy or grant exists on `tasks`). Each RPC returns
/// the persisted row as jsonb, so the gateway maps the VO from the response
/// directly with NO follow-up fetch re-read (the send_message D-SM2
/// convention).
abstract interface class SupabaseTaskApi {
  /// The caller's assignment-scoped `tasks` rows.
  ///
  /// Columns requested: `id`, `organization_id`, `matter_id`, `title`,
  /// `status`, `assignee_id`, `acknowledged_by`, `acknowledged_at`,
  /// `created_at`, `matters(title)` — the read surface the [TaskItem] VO needs (no
  /// content column exists on tasks).
  Future<List<Map<String, dynamic>>> fetchTasks();

  /// Creates a task through the audited `create_task` RPC and returns the
  /// persisted row. [title] is already trimmed by the caller.
  Future<Map<String, dynamic>> createTask({
    required String matterId,
    required String title,
    String? assigneeId,
  });

  /// Advances a task through the audited `advance_task_status` RPC and
  /// returns the persisted row. [toStatus] is the server enum value
  /// (`todo`, `in_progress`, `blocked`, `done`).
  Future<Map<String, dynamic>> advanceTaskStatus(
    String taskId,
    String toStatus,
  );

  /// Re-assigns a task through the audited `assign_task` RPC and returns
  /// the persisted row.
  Future<Map<String, dynamic>> assignTask(String taskId, String assigneeId);

  /// Acknowledges a task through the audited `acknowledge_task` RPC and
  /// returns the persisted row.
  Future<Map<String, dynamic>> acknowledgeTask(String taskId);
}
