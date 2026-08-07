import '../../../core/errors/result.dart';
import 'file_metadata.dart';

/// Matter-scoped storage integration boundary (fourth §14 un-deferral,
/// storage slice D-STR7).
///
/// This slice **builds** the minimal consumer-attached surface (there was no
/// Phase 8–12 fake to swap): a dev fake is registered for env-less runs and
/// ALL tests, and the env-gated Supabase implementation takes over only in
/// configured builds behind `env.isConfigured` (the documents/messages flip
/// pattern). **Metadata only** — no byte content, no download affordance
/// ever crosses this boundary (D-STR3/D-STR9).
///
/// Return convention matches the project's [Result] boundary (§D.4) —
/// failures arrive as [Failure] with [AppError], never raw exceptions.
abstract interface class StorageGateway {
  /// The caller's assignment-scoped file-metadata list (active member of the
  /// file's org AND assigned on its matter, matrix §4 — the
  /// `files_select_assigned` RLS gate server-side). Deterministic and
  /// read-only.
  Future<Result<List<FileMetadata>>> fetchFiles();
}
