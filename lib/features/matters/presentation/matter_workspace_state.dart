import 'package:equatable/equatable.dart';

import '../../../core/state/view_state.dart';
import '../../billing/domain/invoice.dart';
import '../../documents/domain/document.dart';
import '../../messaging/domain/message_thread.dart';
import '../../storage/domain/file_metadata.dart';

/// Immutable state of the per-matter workspace (audit: matters god-feature).
///
/// One [ViewState] per workspace list — threads, documents, invoices, files
/// — so each section keeps its own loading/success/empty/error lifecycle
/// (and its own retry) exactly as when each section owned a foreign cubit.
/// All four start loading: the first open never re-emits a redundant
/// loading frame, matching the standalone surfaces' contract.
class MatterWorkspaceState extends Equatable {
  const MatterWorkspaceState({
    this.threads = const ViewLoading<List<MessageThread>>(),
    this.documents = const ViewLoading<List<Document>>(),
    this.invoices = const ViewLoading<List<Invoice>>(),
    this.files = const ViewLoading<List<FileMetadata>>(),
  });

  final ViewState<List<MessageThread>> threads;
  final ViewState<List<Document>> documents;
  final ViewState<List<Invoice>> invoices;
  final ViewState<List<FileMetadata>> files;

  MatterWorkspaceState copyWith({
    ViewState<List<MessageThread>>? threads,
    ViewState<List<Document>>? documents,
    ViewState<List<Invoice>>? invoices,
    ViewState<List<FileMetadata>>? files,
  }) {
    return MatterWorkspaceState(
      threads: threads ?? this.threads,
      documents: documents ?? this.documents,
      invoices: invoices ?? this.invoices,
      files: files ?? this.files,
    );
  }

  @override
  List<Object?> get props => <Object?>[threads, documents, invoices, files];
}
