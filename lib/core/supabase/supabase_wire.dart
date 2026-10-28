/// Runtime table and bucket names. One source; do not duplicate literals.
abstract final class SupabaseTables {
  static const String matters = 'matters';
  static const String documents = 'documents';
  static const String files = 'files';
  static const String billingInvoices = 'billing_invoices';
  static const String messageThreads = 'message_threads';
  static const String messages = 'messages';
  static const String notifications = 'notifications';
  static const String tasks = 'tasks';
  static const String consultationSlots = 'consultation_slots';
  static const String memberships = 'memberships';
}

abstract final class SupabaseBuckets {
  static const String matterFiles = 'matter-files';
}

abstract final class SupabaseRpcs {
  // approvals
  static const String listApprovalRequests = 'list_approval_requests';
  static const String createApprovalRequest = 'create_approval_request';
  static const String decideApprovalRequest = 'decide_approval_request';
  static const String cancelApprovalRequest = 'cancel_approval_request';
  // attorney directory
  static const String listAttorneyProfiles = 'list_attorney_profiles';
  static const String getAttorneyProfile = 'get_attorney_profile';
  static const String createAttorneyProfile = 'create_attorney_profile';
  static const String updateAttorneyProfile = 'update_attorney_profile';
  static const String deactivateAttorneyProfile = 'deactivate_attorney_profile';
  // compliance
  static const String listComplianceAlerts = 'list_compliance_alerts';
  static const String createComplianceAlert = 'create_compliance_alert';
  static const String acknowledgeComplianceAlert =
      'acknowledge_compliance_alert';
  static const String resolveComplianceAlert = 'resolve_compliance_alert';
  // video
  static const String listVideoSessions = 'list_video_sessions';
  static const String createVideoSession = 'create_video_session';
  static const String markVideoSessionLive = 'mark_video_session_live';
  static const String endVideoSession = 'end_video_session';
  // billing
  static const String getInvoicePaymentStatus = 'get_invoice_payment_status';
  // admin
  static const String listOrganizationsMetadata = 'list_organizations_metadata';
  static const String listMembersMetadata = 'list_members_metadata';
  static const String suspendMembershipPlatform = 'suspend_membership_platform';
  static const String reactivateMembershipPlatform =
      'reactivate_membership_platform';
  static const String deleteDemoAccount = 'delete_demo_account';
  static const String readPlatformAudit = 'read_platform_audit';
  // organizations
  static const String createOrganization = 'create_organization';
  static const String listOrgMembersMetadata = 'list_org_members_metadata';
  static const String listMatterAssignableMembers =
      'list_matter_assignable_members';
  static const String inviteMember = 'invite_member';
  static const String changeMemberRole = 'change_member_role';
  static const String suspendMembership = 'suspend_membership';
  static const String reactivateMembership = 'reactivate_membership';
  static const String removeMembership = 'remove_membership';
  static const String resendInvitation = 'resend_invitation';
  static const String revokeInvitation = 'revoke_invitation';
  static const String deleteMyAccount = 'delete_my_account';
  static const String acceptInvitation = 'accept_invitation';
  static const String readOrgAudit = 'read_org_audit';
  // matters, messaging, notifications, storage, booking
  static const String createMatter = 'create_matter';
  static const String sendMessage = 'send_message';
  static const String markNotificationsRead = 'mark_notifications_read';
  static const String registerMatterFile = 'register_matter_file';
  static const String bookConsultation = 'book_consultation';
  // research
  static const String listResearchRuns = 'list_research_runs';
  static const String listResearchFindings = 'list_research_findings';
  // tasks
  static const String createTask = 'create_task';
  static const String advanceTaskStatus = 'advance_task_status';
  static const String assignTask = 'assign_task';
  static const String acknowledgeTask = 'acknowledge_task';
}

abstract final class SupabaseEdgeFunctions {
  static const String paymobInitiate = 'paymob-initiate';
  static const String videoToken = 'video-token';
  static const String researchAnalyze = 'research-analyze';
}
