import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/features/library/domain/legal_article_detail.dart';
import 'package:legalhub/features/library/domain/legal_document.dart';
import 'package:legalhub/features/library/domain/legal_document_detail.dart';
import 'package:legalhub/features/library/domain/legal_enums.dart';
import 'package:legalhub/features/library/domain/legal_search_hit.dart';

/// Legal Library integration boundary (ADR-0009).
///
/// Four reads and no writes: this slice is browse + read + search, and the
/// library is populated by the owner's importer, not by the app. The
/// configured build binds the Supabase-backed implementation; env-less builds
/// and all tests keep the credential-free fake, which mirrors the seed and the
/// server's search semantics.
///
/// Failures arrive as [Failure] with an `AppError`, never raw exceptions.
abstract interface class LibraryGateway {
  /// Documents in the library, newest publication first.
  ///
  /// [category] narrows to one taxonomy bucket; null means all. [limit] is
  /// clamped by the caller's adapter to the server's hard cap.
  Future<Result<List<LegalDocument>>> listDocuments({
    LegalCategory? category,
    int limit = 50,
    int offset = 0,
  });

  /// One document with its articles in reading order.
  Future<Result<LegalDocumentDetail>> getDocument(String id);

  /// One article with its document context and its neighbours.
  Future<Result<LegalArticleDetail>> getArticle(String id);

  /// Ranked article hits for [query].
  ///
  /// An empty or whitespace-only [query] is a success with no hits — the
  /// surface's "nothing asked yet" arm — never a failure.
  Future<Result<List<LegalSearchHit>>> search({
    required String query,
    LegalCategory? category,
    int limit = 20,
    int offset = 0,
  });
}
