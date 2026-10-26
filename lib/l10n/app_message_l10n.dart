import 'package:legalhub/core/errors/app_message_key.dart';
import 'package:legalhub/l10n/app_localizations.dart';

/// Resolves an [AppMessageKey] to localized copy.
///
/// Exhaustive over every [AppMessageKey] value: a new key must be mapped here
/// or the analyzer rejects the switch.
String appMessage(
  AppLocalizations l10n,
  AppMessageKey key, {
  Map<String, Object?> args = const <String, Object?>{},
}) {
  return switch (key) {
    AppMessageKey.errUnableToLoadTasksPleaseTryAgain =>
      l10n.errUnableToLoadTasksPleaseTryAgain,
    AppMessageKey.errARejectionNoteIsRequired =>
      l10n.errARejectionNoteIsRequired,
    AppMessageKey.errAcknowledgingTheAlertIsTemporarilyUnavailablePleaseTry =>
      l10n.errAcknowledgingTheAlertIsTemporarilyUnavailablePleaseTry,
    AppMessageKey.errApprovalRequestNotFound => l10n.errApprovalRequestNotFound,
    AppMessageKey.errApprovalsAreTemporarilyUnavailablePleaseTryAgain =>
      l10n.errApprovalsAreTemporarilyUnavailablePleaseTryAgain,
    AppMessageKey.errCancellingTheRequestIsTemporarilyUnavailablePleaseTry =>
      l10n.errCancellingTheRequestIsTemporarilyUnavailablePleaseTry,
    AppMessageKey.errComplianceAlertNotFound => l10n.errComplianceAlertNotFound,
    AppMessageKey.errComplianceAlertsAreTemporarilyUnavailablePleaseTryAgain =>
      l10n.errComplianceAlertsAreTemporarilyUnavailablePleaseTryAgain,
    AppMessageKey.errCreatingTheAlertIsTemporarilyUnavailablePleaseTry =>
      l10n.errCreatingTheAlertIsTemporarilyUnavailablePleaseTry,
    AppMessageKey.errCreatingTheRequestIsTemporarilyUnavailablePleaseTry =>
      l10n.errCreatingTheRequestIsTemporarilyUnavailablePleaseTry,
    AppMessageKey.errDecidingTheRequestIsTemporarilyUnavailablePleaseTry =>
      l10n.errDecidingTheRequestIsTemporarilyUnavailablePleaseTry,
    AppMessageKey.errOnlyAPartnerCanDecideThisRequest =>
      l10n.errOnlyAPartnerCanDecideThisRequest,
    AppMessageKey.errOnlyAPartnerOrComplianceOfficerCanCreate =>
      l10n.errOnlyAPartnerOrComplianceOfficerCanCreate,
    AppMessageKey.errOnlyAPartnerOrComplianceOfficerCanResolve =>
      l10n.errOnlyAPartnerOrComplianceOfficerCanResolve,
    AppMessageKey.errOnlyAnActiveOrganizationMemberCanAcknowledgeAlerts =>
      l10n.errOnlyAnActiveOrganizationMemberCanAcknowledgeAlerts,
    AppMessageKey.errOnlyTheRequesterOrAPartnerCanCancel =>
      l10n.errOnlyTheRequesterOrAPartnerCanCancel,
    AppMessageKey.errResolvingTheAlertIsTemporarilyUnavailablePleaseTry =>
      l10n.errResolvingTheAlertIsTemporarilyUnavailablePleaseTry,
    AppMessageKey.errSelectAnOrganizationToViewApprovals =>
      l10n.errSelectAnOrganizationToViewApprovals,
    AppMessageKey.errSelectAnOrganizationToViewComplianceAlerts =>
      l10n.errSelectAnOrganizationToViewComplianceAlerts,
    AppMessageKey.errTheAlertCanNoLongerBeAcknowledged =>
      l10n.errTheAlertCanNoLongerBeAcknowledged,
    AppMessageKey.errTheAlertCanNoLongerBeResolved =>
      l10n.errTheAlertCanNoLongerBeResolved,
    AppMessageKey.errTheAlertCouldNotBeCreatedCheckThe =>
      l10n.errTheAlertCouldNotBeCreatedCheckThe,
    AppMessageKey.errTheRequestCanNoLongerBeCancelled =>
      l10n.errTheRequestCanNoLongerBeCancelled,
    AppMessageKey.errTheRequestCouldNotBeCreatedCheckThe =>
      l10n.errTheRequestCouldNotBeCreatedCheckThe,
    AppMessageKey.errTheRequestCouldNotBeDecidedItMay =>
      l10n.errTheRequestCouldNotBeDecidedItMay,
    AppMessageKey.errTheRequestIsNoLongerPending =>
      l10n.errTheRequestIsNoLongerPending,
    AppMessageKey.errUnableToAcknowledgeTheAlertPleaseTryAgain =>
      l10n.errUnableToAcknowledgeTheAlertPleaseTryAgain,
    AppMessageKey.errUnableToCancelTheRequestPleaseTryAgain =>
      l10n.errUnableToCancelTheRequestPleaseTryAgain,
    AppMessageKey.errUnableToCreateTheAlertPleaseTryAgain =>
      l10n.errUnableToCreateTheAlertPleaseTryAgain,
    AppMessageKey.errUnableToCreateTheRequestPleaseTryAgain =>
      l10n.errUnableToCreateTheRequestPleaseTryAgain,
    AppMessageKey.errUnableToDecideTheRequestPleaseTryAgain =>
      l10n.errUnableToDecideTheRequestPleaseTryAgain,
    AppMessageKey.errUnableToLoadApprovalsPleaseTryAgain =>
      l10n.errUnableToLoadApprovalsPleaseTryAgain,
    AppMessageKey.errUnableToLoadComplianceAlertsPleaseTryAgain =>
      l10n.errUnableToLoadComplianceAlertsPleaseTryAgain,
    AppMessageKey.errUnableToResolveTheAlertPleaseTryAgain =>
      l10n.errUnableToResolveTheAlertPleaseTryAgain,
    AppMessageKey.errYouDoNotHavePermissionToCreateApproval =>
      l10n.errYouDoNotHavePermissionToCreateApproval,
    AppMessageKey.errYouDoNotHavePermissionToViewApprovals =>
      l10n.errYouDoNotHavePermissionToViewApprovals,
    AppMessageKey.errYouDoNotHavePermissionToViewCompliance =>
      l10n.errYouDoNotHavePermissionToViewCompliance,
    AppMessageKey.errAcknowledgingTheTaskIsTemporarilyUnavailablePleaseTry =>
      l10n.errAcknowledgingTheTaskIsTemporarilyUnavailablePleaseTry,
    AppMessageKey.errAvailableTimesAreTemporarilyUnavailablePleaseTryAgain =>
      l10n.errAvailableTimesAreTemporarilyUnavailablePleaseTryAgain,
    AppMessageKey.errBookingIsTemporarilyUnavailablePleaseTryAgain =>
      l10n.errBookingIsTemporarilyUnavailablePleaseTryAgain,
    AppMessageKey.errCreatingTheTaskIsTemporarilyUnavailablePleaseTry =>
      l10n.errCreatingTheTaskIsTemporarilyUnavailablePleaseTry,
    AppMessageKey.errMessageIsTooLongMaxMaxMessageLengthCharacters =>
      switch (args['maxMessageLength']) {
        final int maxMessageLength =>
          l10n.errMessageIsTooLongMaxMaxMessageLengthCharacters(
            maxMessageLength,
          ),
        _ => l10n.stateError,
      },
    AppMessageKey.errMessagesAreTemporarilyUnavailablePleaseTryAgain =>
      l10n.errMessagesAreTemporarilyUnavailablePleaseTryAgain,
    AppMessageKey.errOnlyTheAssignedPersonCanAcknowledgeThisTask =>
      l10n.errOnlyTheAssignedPersonCanAcknowledgeThisTask,
    AppMessageKey.errReAssigningTheTaskIsTemporarilyUnavailablePlease =>
      l10n.errReAssigningTheTaskIsTemporarilyUnavailablePlease,
    AppMessageKey.errSendingIsTemporarilyUnavailablePleaseTryAgain =>
      l10n.errSendingIsTemporarilyUnavailablePleaseTryAgain,
    AppMessageKey.errTasksAreTemporarilyUnavailablePleaseTryAgain =>
      l10n.errTasksAreTemporarilyUnavailablePleaseTryAgain,
    AppMessageKey.errThatPersonCannotBeAssignedThisTaskChoose =>
      l10n.errThatPersonCannotBeAssignedThisTaskChoose,
    AppMessageKey.errThatTimeIsNoLongerAvailableChooseAnother =>
      l10n.errThatTimeIsNoLongerAvailableChooseAnother,
    AppMessageKey.errTheBookingDetailsAreInvalidCheckThemAnd =>
      l10n.errTheBookingDetailsAreInvalidCheckThemAnd,
    AppMessageKey.errTheTaskCannotMoveToThatStatusIt =>
      l10n.errTheTaskCannotMoveToThatStatusIt,
    AppMessageKey.errTheTaskCouldNotBeCreatedCheckThe =>
      l10n.errTheTaskCouldNotBeCreatedCheckThe,
    AppMessageKey.errThreadsAreTemporarilyUnavailablePleaseTryAgain =>
      l10n.errThreadsAreTemporarilyUnavailablePleaseTryAgain,
    AppMessageKey.errUnableToAcknowledgeTheTaskPleaseTryAgain =>
      l10n.errUnableToAcknowledgeTheTaskPleaseTryAgain,
    AppMessageKey.errUnableToConfirmPleaseTryAgain =>
      l10n.errUnableToConfirmPleaseTryAgain,
    AppMessageKey.errUnableToCreateTheTaskPleaseTryAgain =>
      l10n.errUnableToCreateTheTaskPleaseTryAgain,
    AppMessageKey.errUnableToLoadAvailableTimesPleaseTryAgain =>
      l10n.errUnableToLoadAvailableTimesPleaseTryAgain,
    AppMessageKey.errUnableToLoadMessagesPleaseTryAgain =>
      l10n.errUnableToLoadMessagesPleaseTryAgain,
    AppMessageKey.errUnableToLoadThreadsPleaseTryAgain =>
      l10n.errUnableToLoadThreadsPleaseTryAgain,
    AppMessageKey.errUnableToReAssignTheTaskPleaseTry =>
      l10n.errUnableToReAssignTheTaskPleaseTry,
    AppMessageKey.errUnableToSendTheMessagePleaseTryAgain =>
      l10n.errUnableToSendTheMessagePleaseTryAgain,
    AppMessageKey.errUnableToUpdateTheTaskPleaseTryAgain =>
      l10n.errUnableToUpdateTheTaskPleaseTryAgain,
    AppMessageKey.errUpdatingTheTaskIsTemporarilyUnavailablePleaseTry =>
      l10n.errUpdatingTheTaskIsTemporarilyUnavailablePleaseTry,
    AppMessageKey.errYouDoNotHavePermissionToAdvanceThis =>
      l10n.errYouDoNotHavePermissionToAdvanceThis,
    AppMessageKey.errYouDoNotHavePermissionToBookThis =>
      l10n.errYouDoNotHavePermissionToBookThis,
    AppMessageKey.errYouDoNotHavePermissionToCreateTasks =>
      l10n.errYouDoNotHavePermissionToCreateTasks,
    AppMessageKey.errYouDoNotHavePermissionToReAssign =>
      l10n.errYouDoNotHavePermissionToReAssign,
    AppMessageKey.errYouDoNotHavePermissionToSendMessages =>
      l10n.errYouDoNotHavePermissionToSendMessages,
    AppMessageKey.errYouDoNotHavePermissionToViewAvailable =>
      l10n.errYouDoNotHavePermissionToViewAvailable,
    AppMessageKey.errYouDoNotHavePermissionToViewThese =>
      l10n.errYouDoNotHavePermissionToViewThese,
    AppMessageKey.errYouDoNotHavePermissionToViewThese2 =>
      l10n.errYouDoNotHavePermissionToViewThese2,
    AppMessageKey.errYouDoNotHavePermissionToViewThese3 =>
      l10n.errYouDoNotHavePermissionToViewThese3,
    AppMessageKey.errAttorneyNotFound => l10n.errAttorneyNotFound,
    AppMessageKey.errTheDirectoryIsTemporarilyUnavailableTryAgain =>
      l10n.errTheDirectoryIsTemporarilyUnavailableTryAgain,
    AppMessageKey.errTheProfileDetailsAreInvalidCheckThemAnd =>
      l10n.errTheProfileDetailsAreInvalidCheckThemAnd,
    AppMessageKey.errUnableToLoadTheDirectoryPleaseTryAgain =>
      l10n.errUnableToLoadTheDirectoryPleaseTryAgain,
    AppMessageKey.errYouDoNotHavePermissionToManageThe =>
      l10n.errYouDoNotHavePermissionToManageThe,
    AppMessageKey.errYouDoNotHavePermissionToViewThe =>
      l10n.errYouDoNotHavePermissionToViewThe,
    AppMessageKey.errNotificationsAreTemporarilyUnavailablePleaseTryAgain =>
      l10n.errNotificationsAreTemporarilyUnavailablePleaseTryAgain,
    AppMessageKey.errThisFileIsTooLarge => l10n.errThisFileIsTooLarge,
    AppMessageKey.errThisFileTypeIsNotSupported =>
      l10n.errThisFileTypeIsNotSupported,
    AppMessageKey.errUnableToCheckThePaymentStatusPleaseTry =>
      l10n.errUnableToCheckThePaymentStatusPleaseTry,
    AppMessageKey.errUnableToLoadDocumentsPleaseTryAgain =>
      l10n.errUnableToLoadDocumentsPleaseTryAgain,
    AppMessageKey.errUnableToLoadFilesPleaseTryAgain =>
      l10n.errUnableToLoadFilesPleaseTryAgain,
    AppMessageKey.errUnableToLoadInvoicesPleaseTryAgain =>
      l10n.errUnableToLoadInvoicesPleaseTryAgain,
    AppMessageKey.errUnableToLoadMattersPleaseTryAgain =>
      l10n.errUnableToLoadMattersPleaseTryAgain,
    AppMessageKey.errUnableToLoadNotificationsPleaseTryAgain =>
      l10n.errUnableToLoadNotificationsPleaseTryAgain,
    AppMessageKey.errUnableToOpenTheFilePleaseTryAgain =>
      l10n.errUnableToOpenTheFilePleaseTryAgain,
    AppMessageKey.errUnableToStartThePaymentPleaseTryAgain =>
      l10n.errUnableToStartThePaymentPleaseTryAgain,
    AppMessageKey.errUnableToUploadTheFilePleaseTryAgain =>
      l10n.errUnableToUploadTheFilePleaseTryAgain,
    AppMessageKey.errYouDoNotHavePermissionToUploadFiles =>
      l10n.errYouDoNotHavePermissionToUploadFiles,
    AppMessageKey.errAIResearchIsNotConfiguredForThisDeployment =>
      l10n.errAIResearchIsNotConfiguredForThisDeployment,
    AppMessageKey.errAnActionIsAlreadyInProgress =>
      l10n.errAnActionIsAlreadyInProgress,
    AppMessageKey.errEndingTheConsultationIsTemporarilyUnavailablePleaseTry =>
      l10n.errEndingTheConsultationIsTemporarilyUnavailablePleaseTry,
    AppMessageKey
        .errEnterAQuestionBetweenResearchRequestMinQuestionLengthAndResearchRequest =>
      switch ((args['minQuestionLength'], args['maxQuestionLength'])) {
        (final int minQuestionLength, final int maxQuestionLength) =>
          l10n.errEnterAQuestionBetweenResearchRequestMinQuestionLengthAndResearchRequest(
            minQuestionLength,
            maxQuestionLength,
          ),
        _ => l10n.stateError,
      },
    AppMessageKey.errOnlyAPartnerOrAttorneyCanScheduleA =>
      l10n.errOnlyAPartnerOrAttorneyCanScheduleA,
    AppMessageKey.errOnlyTheCreatorOrAPartnerCanEnd =>
      l10n.errOnlyTheCreatorOrAPartnerCanEnd,
    AppMessageKey.errOrganizationMembershipsCouldNotBeLoaded =>
      l10n.errOrganizationMembershipsCouldNotBeLoaded,
    AppMessageKey.errSchedulingAConsultationIsTemporarilyUnavailablePleaseTry =>
      l10n.errSchedulingAConsultationIsTemporarilyUnavailablePleaseTry,
    AppMessageKey.errSelectAResearchRunToViewItsFindings =>
      l10n.errSelectAResearchRunToViewItsFindings,
    AppMessageKey.errSelectAVideoConsultationToJoin =>
      l10n.errSelectAVideoConsultationToJoin,
    AppMessageKey.errSelectAnOrganizationToScheduleAConsultation =>
      l10n.errSelectAnOrganizationToScheduleAConsultation,
    AppMessageKey.errSelectAnOrganizationToViewResearchRuns =>
      l10n.errSelectAnOrganizationToViewResearchRuns,
    AppMessageKey.errSelectAnOrganizationToViewVideoConsultations =>
      l10n.errSelectAnOrganizationToViewVideoConsultations,
    AppMessageKey.errSignInAgainToUseVideoConsultations =>
      l10n.errSignInAgainToUseVideoConsultations,
    AppMessageKey.errStartingTheConsultationIsTemporarilyUnavailablePleaseTry =>
      l10n.errStartingTheConsultationIsTemporarilyUnavailablePleaseTry,
    AppMessageKey.errTheAIProviderReturnedAnUnexpectedResponsePlease =>
      l10n.errTheAIProviderReturnedAnUnexpectedResponsePlease,
    AppMessageKey.errTheConsultationCouldNotBeScheduledCheckThe =>
      l10n.errTheConsultationCouldNotBeScheduledCheckThe,
    AppMessageKey.errTheConsultationIsNotAvailableToJoinRight =>
      l10n.errTheConsultationIsNotAvailableToJoinRight,
    AppMessageKey.errTheSelectedContextIsTooLargeRemoveDocuments =>
      l10n.errTheSelectedContextIsTooLargeRemoveDocuments,
    AppMessageKey.errTheSelectedResearchRunWasNotFound =>
      l10n.errTheSelectedResearchRunWasNotFound,
    AppMessageKey.errThisConsultationCanNoLongerBeEnded =>
      l10n.errThisConsultationCanNoLongerBeEnded,
    AppMessageKey.errThisConsultationCanNoLongerBeStarted =>
      l10n.errThisConsultationCanNoLongerBeStarted,
    AppMessageKey.errThisVideoConsultationHasAlreadyEnded =>
      l10n.errThisVideoConsultationHasAlreadyEnded,
    AppMessageKey.errThisVideoConsultationWasNotFound =>
      l10n.errThisVideoConsultationWasNotFound,
    AppMessageKey.errUnableToEndTheConsultationPleaseTryAgain =>
      l10n.errUnableToEndTheConsultationPleaseTryAgain,
    AppMessageKey.errUnableToJoinTheConsultationPleaseTryAgain =>
      l10n.errUnableToJoinTheConsultationPleaseTryAgain,
    AppMessageKey.errUnableToLoadVideoConsultationsPleaseTryAgain =>
      l10n.errUnableToLoadVideoConsultationsPleaseTryAgain,
    AppMessageKey.errUnableToReadTheVideoConsultationPleaseTry =>
      l10n.errUnableToReadTheVideoConsultationPleaseTry,
    AppMessageKey.errUnableToRunAIResearchPleaseTryAgain =>
      l10n.errUnableToRunAIResearchPleaseTryAgain,
    AppMessageKey.errUnableToScheduleTheConsultationPleaseTryAgain =>
      l10n.errUnableToScheduleTheConsultationPleaseTryAgain,
    AppMessageKey.errUnableToStartTheConsultationPleaseTryAgain =>
      l10n.errUnableToStartTheConsultationPleaseTryAgain,
    AppMessageKey.errVideoCallsAreNotConfiguredForThisDeployment =>
      l10n.errVideoCallsAreNotConfiguredForThisDeployment,
    AppMessageKey.errVideoCallsAreTemporarilyUnavailablePleaseTryAgain =>
      l10n.errVideoCallsAreTemporarilyUnavailablePleaseTryAgain,
    AppMessageKey
        .errVideoConsultationsAreTemporarilyUnavailablePleaseTryAgain =>
      l10n.errVideoConsultationsAreTemporarilyUnavailablePleaseTryAgain,
    AppMessageKey.errWeCouldnTCompleteThatRequestPleaseTry =>
      l10n.errWeCouldnTCompleteThatRequestPleaseTry,
    AppMessageKey.errYouDoNotHavePermissionToJoinThis =>
      l10n.errYouDoNotHavePermissionToJoinThis,
    AppMessageKey.errYouDoNotHavePermissionToStartThis =>
      l10n.errYouDoNotHavePermissionToStartThis,
    AppMessageKey.errYouDoNotHavePermissionToViewVideo =>
      l10n.errYouDoNotHavePermissionToViewVideo,
  };
}
