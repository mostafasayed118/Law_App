import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/state/view_state.dart';
import '../../billing/domain/billing_gateway.dart';
import '../../billing/domain/invoice.dart';
import '../../documents/domain/document.dart';
import '../../documents/domain/document_gateway.dart';
import '../../messaging/domain/message_gateway.dart';
import '../../messaging/domain/message_thread.dart';
import '../../storage/domain/file_metadata.dart';
import '../../storage/domain/storage_gateway.dart';
import 'matter_workspace_state.dart';

/// Owns the per-matter workspace lists (audit: matters god-feature).
///
/// The four workspace sections (messages, documents, invoices, files) used
/// to each provide a *foreign feature's* presentation cubit
/// (`MessageCubit`, `DocumentCubit`, `BillingCubit`, `StorageCubit`), which
/// coupled matters' presentation to four sibling presentations and made
/// matters untestable in isolation. This composite cubit orchestrates the
/// four **domain** gateways directly — domain-to-domain composition, which
/// the layering allows — and exposes the same four [ViewState] lifecycles
/// the sections rendered before, so the section bodies keep their exact
/// rendering and retry behavior.
///
/// Loads run per list (a section triggers only its own loader on open, and
/// retry reloads only the failed list); [load] loads all four in parallel
/// for callers that need the whole workspace at once. Per-list in-flight
/// guards mirror the standalone cubits' contract: the initial state IS
/// loading, so the flag — not a state check — suppresses duplicate calls.
class MatterWorkspaceCubit extends Cubit<MatterWorkspaceState> {
  MatterWorkspaceCubit(
    this._messageGateway,
    this._documentGateway,
    this._billingGateway,
    this._storageGateway,
  ) : super(const MatterWorkspaceState());

  final MessageGateway _messageGateway;
  final DocumentGateway _documentGateway;
  final BillingGateway _billingGateway;
  final StorageGateway _storageGateway;

  bool _loadingThreads = false;
  bool _loadingDocuments = false;
  bool _loadingInvoices = false;
  bool _loadingFiles = false;

  /// Loads all four workspace lists in parallel.
  Future<void> load() async {
    await (loadThreads(), loadDocuments(), loadInvoices(), loadFiles()).wait;
  }

  /// Loads the thread-metadata list (messages section).
  Future<void> loadThreads() async {
    if (isClosed || _loadingThreads) {
      return;
    }
    _loadingThreads = true;
    if (state.threads is! ViewLoading<List<MessageThread>>) {
      emit(state.copyWith(threads: const ViewLoading<List<MessageThread>>()));
    }
    try {
      final Result<List<MessageThread>> result = await _messageGateway
          .fetchThreads();
      if (isClosed) {
        return;
      }
      emit(state.copyWith(threads: _toViewState(result)));
    } finally {
      _loadingThreads = false;
    }
  }

  /// Loads the document-metadata list (documents section).
  Future<void> loadDocuments() async {
    if (isClosed || _loadingDocuments) {
      return;
    }
    _loadingDocuments = true;
    if (state.documents is! ViewLoading<List<Document>>) {
      emit(state.copyWith(documents: const ViewLoading<List<Document>>()));
    }
    try {
      final Result<List<Document>> result = await _documentGateway
          .fetchDocuments();
      if (isClosed) {
        return;
      }
      emit(state.copyWith(documents: _toViewState(result)));
    } finally {
      _loadingDocuments = false;
    }
  }

  /// Loads the invoice list (invoices section).
  Future<void> loadInvoices() async {
    if (isClosed || _loadingInvoices) {
      return;
    }
    _loadingInvoices = true;
    if (state.invoices is! ViewLoading<List<Invoice>>) {
      emit(state.copyWith(invoices: const ViewLoading<List<Invoice>>()));
    }
    try {
      final Result<List<Invoice>> result = await _billingGateway
          .fetchInvoices();
      if (isClosed) {
        return;
      }
      emit(state.copyWith(invoices: _toViewState(result)));
    } finally {
      _loadingInvoices = false;
    }
  }

  /// Loads the file-metadata list (files section).
  Future<void> loadFiles() async {
    if (isClosed || _loadingFiles) {
      return;
    }
    _loadingFiles = true;
    if (state.files is! ViewLoading<List<FileMetadata>>) {
      emit(state.copyWith(files: const ViewLoading<List<FileMetadata>>()));
    }
    try {
      final Result<List<FileMetadata>> result = await _storageGateway
          .fetchFiles();
      if (isClosed) {
        return;
      }
      emit(state.copyWith(files: _toViewState(result)));
    } finally {
      _loadingFiles = false;
    }
  }

  /// Maps a gateway result to the shared [ViewState] vocabulary: an empty
  /// list is [ViewEmpty], a failure renders through [viewStateForFailure]
  /// (the denied/unavailable arms the offline/unauthorized variants need).
  ViewState<List<T>> _toViewState<T>(Result<List<T>> result) {
    return switch (result) {
      Success<List<T>>(value: final List<T> items) =>
        items.isEmpty ? ViewEmpty<List<T>>() : ViewSuccess<List<T>>(items),
      Failure<List<T>>(error: final AppError error) =>
        viewStateForFailure<List<T>>(error),
    };
  }
}
