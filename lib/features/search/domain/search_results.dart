import 'package:equatable/equatable.dart';

import '../../discovery/domain/attorney.dart';
import '../../documents/domain/document.dart';
import '../../matters/domain/matter.dart';
import '../../messaging/domain/message_thread.dart';

/// Grouped unified-search results (Phase 11, slice 11.0, owner decision D-S1).
///
/// A pure client-side aggregation view over the four existing synthetic
/// lists: one ordered subset per kind (matters / documents / threads /
/// attorneys), each preserving the source list's order. The SearchCubit
/// builds this from the D-S1 filtered subsets — **metadata only**: the same
/// non-PII fields the standalone list surfaces already render, never a
/// document body, message text, or attorney contact detail (D-S3 keeps the
/// Phase 8/9 AC-2 absence lines). No new identity or server surface: this is
/// a grouping of rows that already exist behind the Phase 6–10 gateway
/// seams.
class SearchResults extends Equatable {
  const SearchResults({
    required this.matters,
    required this.documents,
    required this.threads,
    required this.attorneys,
  });

  final List<Matter> matters;
  final List<Document> documents;
  final List<MessageThread> threads;
  final List<Attorney> attorneys;

  /// True when every group has no matches (the no-match empty projection).
  bool get isEmpty =>
      matters.isEmpty &&
      documents.isEmpty &&
      threads.isEmpty &&
      attorneys.isEmpty;

  @override
  List<Object?> get props => <Object?>[matters, documents, threads, attorneys];
}
