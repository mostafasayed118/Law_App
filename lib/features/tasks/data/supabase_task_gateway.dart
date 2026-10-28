import 'package:legalhub/core/errors/app_error.dart';
import 'package:legalhub/core/errors/app_message_key.dart';
import 'package:legalhub/core/errors/result.dart';
import 'package:legalhub/data/tasks/supabase_task_api.dart';
import 'package:legalhub/features/tasks/domain/task_gateway.dart';
import 'package:legalhub/features/tasks/domain/task_item.dart';

/// [TaskBoardGateway] backed by the Supabase provider via [SupabaseTaskApi].
///
/// Domain mapping happens here (contract §5 pattern, same as
/// [SupabaseMessageGateway]): raw rows from the seam become [TaskItem] VOs,
/// the server `todo`/`in_progress`/`done` enum maps to the VO's [TaskStatus],
/// the embedded `matters(title)` select resolves the title-keyed `matterRef`
/// (D-MSR4), and typed [SupabaseTaskException]s become [AppError]s. The
/// `TaskItem` VO and all presentation are untouched — this is the
/// env-gated seam-compatible swap of the task-writes slice (Gate 3 spec
/// 2026-09-27).
class SupabaseTaskGateway implements TaskBoardGateway {
  SupabaseTaskGateway(this._api);

  final SupabaseTaskApi _api;

  @override
  Future<Result<List<TaskItem>>> fetchTasks() async {
    try {
      final List<Map<String, dynamic>> rows = await _api.fetchTasks();
      return Result<List<TaskItem>>.success(
        List<TaskItem>.unmodifiable(rows.map(_taskFromRow)),
      );
    } on SupabaseTaskException catch (e) {
      return Result<List<TaskItem>>.failure(
        _taskFailureFor(
          e,
          codePrefix: 'task_read',
          deniedMessage: 'You do not have permission to view these tasks.',
          validationMessage: 'Unable to load tasks. Please try again.',
          unavailableMessage:
              'Tasks are temporarily unavailable. Please try again.',
          failedMessage: 'Unable to load tasks. Please try again.',
          deniedKey: AppMessageKey.errYouDoNotHavePermissionToViewThese2,
          validationKey: AppMessageKey.errUnableToLoadTasksPleaseTryAgain,
          unavailableKey:
              AppMessageKey.errTasksAreTemporarilyUnavailablePleaseTryAgain,
          failedKey: AppMessageKey.errUnableToLoadTasksPleaseTryAgain,
        ),
      );
    } on FormatException catch (e) {
      // Provider drift (unexpected id/title/status shape) surfaces loudly,
      // never as a silently wrong task.
      return Result<List<TaskItem>>.failure(
        AppError(
          code: 'task_read_failed',
          userMessage: 'Unable to load tasks. Please try again.',
          messageKey: AppMessageKey.errUnableToLoadTasksPleaseTryAgain,
          technicalMessage: e.message,
        ),
      );
    }
  }

  @override
  Future<Result<TaskItem>> createTask({
    required String matterId,
    required String title,
    String? assigneeId,
  }) async {
    try {
      final Map<String, dynamic> row = await _api.createTask(
        matterId: matterId,
        title: title,
        assigneeId: assigneeId,
      );
      return Result<TaskItem>.success(_taskFromRow(row));
    } on SupabaseTaskException catch (e) {
      return Result<TaskItem>.failure(
        _taskFailureFor(
          e,
          codePrefix: 'task_create',
          deniedMessage:
              'You do not have permission to create tasks on this matter.',
          validationMessage:
              'The task could not be created. Check the title and try again.',
          unavailableMessage:
              'Creating the task is temporarily unavailable. Please try again.',
          failedMessage: 'Unable to create the task. Please try again.',
          deniedKey: AppMessageKey.errYouDoNotHavePermissionToCreateTasks,
          validationKey: AppMessageKey.errTheTaskCouldNotBeCreatedCheckThe,
          unavailableKey:
              AppMessageKey.errCreatingTheTaskIsTemporarilyUnavailablePleaseTry,
          failedKey: AppMessageKey.errUnableToCreateTheTaskPleaseTryAgain,
        ),
      );
    } on FormatException catch (e) {
      return Result<TaskItem>.failure(
        AppError(
          code: 'task_create_failed',
          userMessage: 'Unable to create the task. Please try again.',
          messageKey: AppMessageKey.errUnableToCreateTheTaskPleaseTryAgain,
          technicalMessage: e.message,
        ),
      );
    }
  }

  @override
  Future<Result<TaskItem>> advanceTask(String taskId, TaskStatus to) {
    return _runWrite(
      () => _api.advanceTaskStatus(taskId, _serverStatusFor(to)),
      codePrefix: 'task_advance',
      deniedMessage: 'You do not have permission to advance this task.',
      validationMessage:
          'The task cannot move to that status. It may already be done.',
      unavailableMessage:
          'Updating the task is temporarily unavailable. Please try again.',
      failedMessage: 'Unable to update the task. Please try again.',
      deniedKey: AppMessageKey.errYouDoNotHavePermissionToAdvanceThis,
      validationKey: AppMessageKey.errTheTaskCannotMoveToThatStatusIt,
      unavailableKey:
          AppMessageKey.errUpdatingTheTaskIsTemporarilyUnavailablePleaseTry,
      failedKey: AppMessageKey.errUnableToUpdateTheTaskPleaseTryAgain,
    );
  }

  @override
  Future<Result<TaskItem>> assignTask(String taskId, String? assigneeId) {
    return _runWrite(
      () => _api.assignTask(taskId, assigneeId),
      codePrefix: 'task_assign',
      deniedMessage: 'You do not have permission to re-assign this task.',
      validationMessage:
          'That person cannot be assigned this task. Choose an active member of the organization.',
      unavailableMessage:
          'Re-assigning the task is temporarily unavailable. Please try again.',
      failedMessage: 'Unable to re-assign the task. Please try again.',
      deniedKey: AppMessageKey.errYouDoNotHavePermissionToReAssign,
      validationKey: AppMessageKey.errThatPersonCannotBeAssignedThisTaskChoose,
      unavailableKey:
          AppMessageKey.errReAssigningTheTaskIsTemporarilyUnavailablePlease,
      failedKey: AppMessageKey.errUnableToReAssignTheTaskPleaseTry,
    );
  }

  @override
  Future<Result<TaskItem>> acknowledgeTask(String taskId) {
    return _runWrite(
      () => _api.acknowledgeTask(taskId),
      codePrefix: 'task_acknowledge',
      deniedMessage: 'Only the assigned person can acknowledge this task.',
      validationMessage: 'Unable to acknowledge the task. Please try again.',
      unavailableMessage:
          'Acknowledging the task is temporarily unavailable. Please try again.',
      failedMessage: 'Unable to acknowledge the task. Please try again.',
      deniedKey: AppMessageKey.errOnlyTheAssignedPersonCanAcknowledgeThisTask,
      validationKey: AppMessageKey.errUnableToAcknowledgeTheTaskPleaseTryAgain,
      unavailableKey: AppMessageKey
          .errAcknowledgingTheTaskIsTemporarilyUnavailablePleaseTry,
      failedKey: AppMessageKey.errUnableToAcknowledgeTheTaskPleaseTryAgain,
    );
  }

  /// Runs one task write RPC through the shared row-mapping + failure path.
  Future<Result<TaskItem>> _runWrite(
    Future<Map<String, dynamic>> Function() write, {
    required String codePrefix,
    required String deniedMessage,
    required String validationMessage,
    required String unavailableMessage,
    required String failedMessage,
    required AppMessageKey deniedKey,
    required AppMessageKey validationKey,
    required AppMessageKey unavailableKey,
    required AppMessageKey failedKey,
  }) async {
    try {
      return Result<TaskItem>.success(_taskFromRow(await write()));
    } on SupabaseTaskException catch (e) {
      return Result<TaskItem>.failure(
        _taskFailureFor(
          e,
          codePrefix: codePrefix,
          deniedMessage: deniedMessage,
          validationMessage: validationMessage,
          unavailableMessage: unavailableMessage,
          failedMessage: failedMessage,
          deniedKey: deniedKey,
          validationKey: validationKey,
          unavailableKey: unavailableKey,
          failedKey: failedKey,
        ),
      );
    } on FormatException catch (e) {
      // Provider drift in the returned row surfaces loudly, never as a
      // silently wrong updated task.
      return Result<TaskItem>.failure(
        AppError(
          code: '${codePrefix}_failed',
          userMessage: failedMessage,
          messageKey: failedKey,
          technicalMessage: e.message,
        ),
      );
    }
  }

  /// Maps one raw task row to the [TaskItem] VO.
  ///
  /// Every cast below is guarded above (id/title/status), so a malformed
  /// row surfaces as a typed FormatException → AppError, never a raw
  /// TypeError across the boundary. The server status enum
  /// (`todo`/`in_progress`/`blocked`/`done`) maps onto the VO's
  /// [TaskStatus]; any other value is provider drift and fails loudly.
  /// `acknowledged` derives from `acknowledged_at` being set — the stamp
  /// itself never crosses (no timestamp PII in the VO).
  TaskItem _taskFromRow(Map<String, dynamic> row) {
    final Object? id = row['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('Task row has no id');
    }
    final Object? title = row['title'];
    if (title is! String || title.isEmpty) {
      throw FormatException('Task row has no title');
    }
    final Object? organizationId = row['organization_id'];
    if (organizationId is! String || organizationId.isEmpty) {
      throw FormatException('Task row has no organization_id');
    }
    final Object? matterId = row['matter_id'];
    if (matterId is! String || matterId.isEmpty) {
      throw FormatException('Task row has no matter_id');
    }
    final Object? status = row['status'];
    final TaskStatus mapped = switch (status) {
      'todo' => TaskStatus.todo,
      'in_progress' => TaskStatus.inProgress,
      'blocked' => TaskStatus.blocked,
      'done' => TaskStatus.done,
      _ => throw FormatException('Task row has unknown status: $status'),
    };
    final Object? assignee = row['assignee_id'];
    final Object? acknowledgedAt = row['acknowledged_at'];
    return TaskItem(
      id: id,
      organizationId: organizationId,
      matterId: matterId,
      title: title,
      // D-MSR4: the embedded matters(title) join resolves under the same
      // RLS gate; an absent embed falls back to the raw matter id, never a
      // fabricated title (the listMyMemberships null-embed pattern).
      matterRef: _matterRefFromRow(row, matterId),
      status: mapped,
      // Tasks carry no due date column — the VO's dueAt keeps its contract
      // with the row's creation timestamp (server-owned, never fabricated).
      dueAt: _createdAtFromRow(row),
      assigneeId: assignee is String && assignee.isNotEmpty ? assignee : null,
      acknowledged: acknowledgedAt is String && acknowledgedAt.isNotEmpty,
    );
  }

  /// Resolves the VO's title-keyed `matterRef` from the embedded
  /// `matters(title)` select, falling back to the raw matter id.
  String _matterRefFromRow(Map<String, dynamic> row, Object? matterId) {
    final Object? matters = row['matters'];
    final Object? embeddedTitle = matters is Map<String, dynamic>
        ? matters['title']
        : null;
    if (embeddedTitle is String && embeddedTitle.isNotEmpty) {
      return embeddedTitle;
    }
    if (matterId is String && matterId.isNotEmpty) {
      return matterId;
    }
    throw FormatException('Task row has no matter_id');
  }

  /// Reads the server-owned creation timestamp for the VO's dueAt contract.
  DateTime _createdAtFromRow(Map<String, dynamic> row) {
    final Object? createdAt = row['created_at'];
    if (createdAt is! String || createdAt.isEmpty) {
      throw FormatException('Task row has no created_at');
    }
    return DateTime.parse(createdAt).toLocal();
  }

  /// Maps the VO's [TaskStatus] to the server enum value. The UI never
  /// offers a `blocked` transition today (the tile's next-step ladder is
  /// todo → in_progress → done), but the server domain accepts it and a
  /// blocked row can arrive from the provider — mapping it here keeps the
  /// read/write domain symmetric.
  String _serverStatusFor(TaskStatus status) {
    return switch (status) {
      TaskStatus.todo => 'todo',
      TaskStatus.inProgress => 'in_progress',
      TaskStatus.blocked => 'blocked',
      TaskStatus.done => 'done',
    };
  }

  /// Maps a provider failure to a redaction-safe [AppError] with a
  /// per-action code prefix. Distinct `task_<action>_*` codes keep each
  /// write surface's failures separable (the D-LV1 convention); the
  /// technical message is the provider's own — titles/ids never cross into
  /// errors. The typed [AppErrorKind] is preserved so presentation renders
  /// the right state: denials are not retryable, outages are (the M-1
  /// discipline — a flattened `unknown` would show either as "try again").
  AppError _taskFailureFor(
    SupabaseTaskException e, {
    required String codePrefix,
    required String deniedMessage,
    required String validationMessage,
    required String unavailableMessage,
    required String failedMessage,
    required AppMessageKey deniedKey,
    required AppMessageKey validationKey,
    required AppMessageKey unavailableKey,
    required AppMessageKey failedKey,
  }) {
    return switch (e.kind) {
      SupabaseTaskFailureKind.denied => AppError(
        code: '${codePrefix}_denied',
        userMessage: deniedMessage,
        messageKey: deniedKey,
        kind: AppErrorKind.denied,
        technicalMessage: e.message,
      ),
      SupabaseTaskFailureKind.validation => AppError(
        code: '${codePrefix}_invalid',
        userMessage: validationMessage,
        messageKey: validationKey,
        kind: AppErrorKind.unknown,
        technicalMessage: e.message,
      ),
      SupabaseTaskFailureKind.providerUnavailable => AppError(
        code: '${codePrefix}_unavailable',
        userMessage: unavailableMessage,
        messageKey: unavailableKey,
        kind: AppErrorKind.unavailable,
        technicalMessage: e.message,
      ),
      SupabaseTaskFailureKind.unknown => AppError(
        code: '${codePrefix}_failed',
        userMessage: failedMessage,
        messageKey: failedKey,
        kind: AppErrorKind.unknown,
        technicalMessage: e.message,
      ),
    };
  }
}
