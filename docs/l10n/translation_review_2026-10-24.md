# Translation review — error copy (AppMessageKey)

Generated from `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, and
`lib/l10n/app_tr.arb` on 2026-10-24. Covers all 129 `err*` keys.

Arabic and Turkish values are machine-drafted and carry
`[REVIEW] machine-drafted; human review required before release`.
Tick a row's REVIEW box only after a human has reviewed that key's AR
and TR values.

## Glossary

- Brand and identity names stay Latin: `LegalHub`, attorney/client names.
- Reuse the existing ARB terminology: matter = قضية / dava; approval =
  موافقة / onay; booking = حجز / rezervasyon; compliance alert = تنبيه
  امتثال / uyum uyarısı; organization = مؤسسة / kuruluş; attorney =
  محامٍ / avukat; invoice = فاتورة / fatura; video consultation =
  استشارة بالفيديو / görüntülü görüşme.
- Keep the formal Turkish `siz` register and the MSA Arabic register used
  by the existing strings.

## Placeholder note

Two keys interpolate runtime values through `messageArgs`; their
placeholders must survive translation unchanged:

| Key | Placeholders |
|---|---|
| `errMessageIsTooLongMaxMaxMessageLengthCharacters` | `{maxMessageLength}` (int) |
| `errEnterAQuestionBetweenResearchRequestMinQuestionLengthAndResearchRequest` | `{minQuestionLength}` (int), `{maxQuestionLength}` (int) |

## Review table

| key | EN | AR | TR | REVIEW |
|---|---|---|---|---|
| `errYouDoNotHavePermissionToViewThese2` | You do not have permission to view these tasks. | ليس لديك إذن لعرض هذه المهام. | Bu görevleri görüntüleme izniniz yok. | [ ] |
| `errUnableToLoadTasksPleaseTryAgain` | Unable to load tasks. Please try again. | تعذر تحميل المهام. يرجى المحاولة مرة أخرى. | Görevler yüklenemedi. Lütfen tekrar deneyin. | [ ] |
| `errARejectionNoteIsRequired` | A rejection note is required. | ملاحظة الرفض مطلوبة. | Ret notu gerekli. | [ ] |
| `errAcknowledgingTheAlertIsTemporarilyUnavailablePleaseTry` | Acknowledging the alert is temporarily unavailable. Please try again. | الاطلاع على التنبيه غير متاح مؤقتًا. حاول مرة أخرى. | Uyarıyı görüldü olarak işaretlemek geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errApprovalRequestNotFound` | Approval request not found. | لم يتم العثور على طلب الموافقة. | Onay talebi bulunamadı. | [ ] |
| `errApprovalsAreTemporarilyUnavailablePleaseTryAgain` | Approvals are temporarily unavailable. Please try again. | الموافقات غير متاحة مؤقتًا. حاول مرة أخرى. | Onaylar geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errCancellingTheRequestIsTemporarilyUnavailablePleaseTry` | Cancelling the request is temporarily unavailable. Please try again. | إلغاء الطلب غير متاح مؤقتًا. حاول مرة أخرى. | Talebi iptal etmek geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errComplianceAlertNotFound` | Compliance alert not found. | لم يتم العثور على تنبيه الامتثال. | Uyum uyarısı bulunamadı. | [ ] |
| `errComplianceAlertsAreTemporarilyUnavailablePleaseTryAgain` | Compliance alerts are temporarily unavailable. Please try again. | تنبيهات الامتثال غير متاحة مؤقتًا. حاول مرة أخرى. | Uyum uyarıları geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errCreatingTheAlertIsTemporarilyUnavailablePleaseTry` | Creating the alert is temporarily unavailable. Please try again. | إنشاء التنبيه غير متاح مؤقتًا. حاول مرة أخرى. | Uyarı oluşturmak geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errCreatingTheRequestIsTemporarilyUnavailablePleaseTry` | Creating the request is temporarily unavailable. Please try again. | إنشاء الطلب غير متاح مؤقتًا. حاول مرة أخرى. | Talep oluşturmak geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errDecidingTheRequestIsTemporarilyUnavailablePleaseTry` | Deciding the request is temporarily unavailable. Please try again. | البت في الطلب غير متاح مؤقتًا. حاول مرة أخرى. | Talebe karar vermek geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errOnlyAPartnerCanDecideThisRequest` | Only a partner can decide this request. | يمكن للشريك فقط البت في هذا الطلب. | Bu talebe yalnızca bir ortak karar verebilir. | [ ] |
| `errOnlyAPartnerOrComplianceOfficerCanCreate` | Only a partner or compliance officer can create alerts. | يمكن للشريك أو مسؤول الامتثال فقط إنشاء التنبيهات. | Uyarıları yalnızca bir ortak veya uyum görevlisi oluşturabilir. | [ ] |
| `errOnlyAPartnerOrComplianceOfficerCanResolve` | Only a partner or compliance officer can resolve alerts. | يمكن للشريك أو مسؤول الامتثال فقط حل التنبيهات. | Uyarıları yalnızca bir ortak veya uyum görevlisi çözebilir. | [ ] |
| `errOnlyAnActiveOrganizationMemberCanAcknowledgeAlerts` | Only an active organization member can acknowledge alerts. | يمكن لعضو نشط في المؤسسة فقط الاطلاع على التنبيهات. | Uyarıları yalnızca etkin bir kuruluş üyesi görüldü olarak işaretleyebilir. | [ ] |
| `errOnlyTheRequesterOrAPartnerCanCancel` | Only the requester or a partner can cancel this request. | يمكن لمقدّم الطلب أو الشريك فقط إلغاء هذا الطلب. | Bu talebi yalnızca talebi oluşturan veya bir ortak iptal edebilir. | [ ] |
| `errResolvingTheAlertIsTemporarilyUnavailablePleaseTry` | Resolving the alert is temporarily unavailable. Please try again. | حل التنبيه غير متاح مؤقتًا. حاول مرة أخرى. | Uyarıyı çözmek geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errSelectAnOrganizationToViewApprovals` | Select an organization to view approvals. | اختر مؤسسة لعرض الموافقات. | Onayları görmek için bir kuruluş seçin. | [ ] |
| `errSelectAnOrganizationToViewComplianceAlerts` | Select an organization to view compliance alerts. | اختر مؤسسة لعرض تنبيهات الامتثال. | Uyum uyarılarını görmek için bir kuruluş seçin. | [ ] |
| `errTheAlertCanNoLongerBeAcknowledged` | The alert can no longer be acknowledged. | لم يعد بالإمكان الاطلاع على التنبيه. | Uyarı artık görüldü olarak işaretlenemiyor. | [ ] |
| `errTheAlertCanNoLongerBeResolved` | The alert can no longer be resolved. | لم يعد بالإمكان حل التنبيه. | Uyarı artık çözülemiyor. | [ ] |
| `errTheAlertCouldNotBeCreatedCheckThe` | The alert could not be created. Check the details and try again. | تعذّر إنشاء التنبيه. تحقق من التفاصيل وحاول مرة أخرى. | Uyarı oluşturulamadı. Ayrıntıları kontrol edip tekrar deneyin. | [ ] |
| `errTheRequestCanNoLongerBeCancelled` | The request can no longer be cancelled. | لم يعد بالإمكان إلغاء الطلب. | Talep artık iptal edilemiyor. | [ ] |
| `errTheRequestCouldNotBeCreatedCheckThe` | The request could not be created. Check the details and try again. | تعذّر إنشاء الطلب. تحقق من التفاصيل وحاول مرة أخرى. | Talep oluşturulamadı. Ayrıntıları kontrol edip tekrar deneyin. | [ ] |
| `errTheRequestCouldNotBeDecidedItMay` | The request could not be decided. It may no longer be pending, or the note is missing. | تعذّر البت في الطلب. قد لا يكون معلّقًا بعد الآن، أو أن الملاحظة مفقودة. | Talebe karar verilemedi. Talep artık beklemede olmayabilir veya not eksik olabilir. | [ ] |
| `errTheRequestIsNoLongerPending` | The request is no longer pending. | الطلب لم يعد معلّقًا. | Talep artık beklemede değil. | [ ] |
| `errUnableToAcknowledgeTheAlertPleaseTryAgain` | Unable to acknowledge the alert. Please try again. | تعذّر الاطلاع على التنبيه. حاول مرة أخرى. | Uyarı görüldü olarak işaretlenemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToCancelTheRequestPleaseTryAgain` | Unable to cancel the request. Please try again. | تعذّر إلغاء الطلب. حاول مرة أخرى. | Talep iptal edilemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToCreateTheAlertPleaseTryAgain` | Unable to create the alert. Please try again. | تعذّر إنشاء التنبيه. حاول مرة أخرى. | Uyarı oluşturulamadı. Lütfen tekrar deneyin. | [ ] |
| `errUnableToCreateTheRequestPleaseTryAgain` | Unable to create the request. Please try again. | تعذّر إنشاء الطلب. حاول مرة أخرى. | Talep oluşturulamadı. Lütfen tekrar deneyin. | [ ] |
| `errUnableToDecideTheRequestPleaseTryAgain` | Unable to decide the request. Please try again. | تعذّر البت في الطلب. حاول مرة أخرى. | Talebe karar verilemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToLoadApprovalsPleaseTryAgain` | Unable to load approvals. Please try again. | تعذّر تحميل الموافقات. حاول مرة أخرى. | Onaylar yüklenemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToLoadComplianceAlertsPleaseTryAgain` | Unable to load compliance alerts. Please try again. | تعذّر تحميل تنبيهات الامتثال. حاول مرة أخرى. | Uyum uyarıları yüklenemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToResolveTheAlertPleaseTryAgain` | Unable to resolve the alert. Please try again. | تعذّر حل التنبيه. حاول مرة أخرى. | Uyarı çözülemedi. Lütfen tekrar deneyin. | [ ] |
| `errYouDoNotHavePermissionToCreateApproval` | You do not have permission to create approval requests. | ليس لديك إذن لإنشاء طلبات الموافقة. | Onay talebi oluşturma izniniz yok. | [ ] |
| `errYouDoNotHavePermissionToViewApprovals` | You do not have permission to view approvals. | ليس لديك إذن لعرض الموافقات. | Onayları görüntüleme izniniz yok. | [ ] |
| `errYouDoNotHavePermissionToViewCompliance` | You do not have permission to view compliance alerts. | ليس لديك إذن لعرض تنبيهات الامتثال. | Uyum uyarılarını görüntüleme izniniz yok. | [ ] |
| `errAcknowledgingTheTaskIsTemporarilyUnavailablePleaseTry` | Acknowledging the task is temporarily unavailable. Please try again. | الإقرار بالمهمة غير متاح مؤقتًا. يرجى المحاولة مرة أخرى. | Görevi onaylama geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errAvailableTimesAreTemporarilyUnavailablePleaseTryAgain` | Available times are temporarily unavailable. Please try again. | الأوقات المتاحة غير متوفرة مؤقتًا. يرجى المحاولة مرة أخرى. | Uygun zamanlar geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errBookingIsTemporarilyUnavailablePleaseTryAgain` | Booking is temporarily unavailable. Please try again. | الحجز غير متاح مؤقتًا. يرجى المحاولة مرة أخرى. | Rezervasyon geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errCreatingTheTaskIsTemporarilyUnavailablePleaseTry` | Creating the task is temporarily unavailable. Please try again. | إنشاء المهمة غير متاح مؤقتًا. يرجى المحاولة مرة أخرى. | Görev oluşturma geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errMessageIsTooLongMaxMaxMessageLengthCharacters` | Message is too long (max {maxMessageLength} characters). | الرسالة طويلة جدًا (الحد الأقصى {maxMessageLength} حرفًا). | Mesaj çok uzun (en fazla {maxMessageLength} karakter). | [ ] |
| `errMessagesAreTemporarilyUnavailablePleaseTryAgain` | Messages are temporarily unavailable. Please try again. | الرسائل غير متاحة مؤقتًا. يرجى المحاولة مرة أخرى. | Mesajlar geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errOnlyTheAssignedPersonCanAcknowledgeThisTask` | Only the assigned person can acknowledge this task. | لا يمكن إلا للشخص المكلَّف الإقرار بهذه المهمة. | Bu görevi yalnızca atanan kişi onaylayabilir. | [ ] |
| `errReAssigningTheTaskIsTemporarilyUnavailablePlease` | Re-assigning the task is temporarily unavailable. Please try again. | إعادة إسناد المهمة غير متاحة مؤقتًا. يرجى المحاولة مرة أخرى. | Görevi yeniden atama geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errSendingIsTemporarilyUnavailablePleaseTryAgain` | Sending is temporarily unavailable. Please try again. | الإرسال غير متاح مؤقتًا. يرجى المحاولة مرة أخرى. | Gönderme geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errTasksAreTemporarilyUnavailablePleaseTryAgain` | Tasks are temporarily unavailable. Please try again. | المهام غير متاحة مؤقتًا. يرجى المحاولة مرة أخرى. | Görevler geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errThatPersonCannotBeAssignedThisTaskChoose` | That person cannot be assigned this task. Choose an active member of the organization. | لا يمكن إسناد هذه المهمة إلى هذا الشخص. اختر عضوًا نشطًا في المؤسسة. | Bu görev o kişiye atanamaz. Kuruluşun etkin bir üyesini seçin. | [ ] |
| `errThatTimeIsNoLongerAvailableChooseAnother` | That time is no longer available. Choose another time. | هذا الوقت لم يعد متاحًا. اختر وقتًا آخر. | Bu saat artık müsait değil. Başka bir saat seçin. | [ ] |
| `errTheBookingDetailsAreInvalidCheckThemAnd` | The booking details are invalid. Check them and try again. | تفاصيل الحجز غير صالحة. تحقق منها وحاول مرة أخرى. | Rezervasyon ayrıntıları geçersiz. Kontrol edip tekrar deneyin. | [ ] |
| `errTheTaskCannotMoveToThatStatusIt` | The task cannot move to that status. It may already be done. | لا يمكن نقل المهمة إلى تلك الحالة. ربما اكتملت بالفعل. | Görev bu duruma taşınamaz. Zaten tamamlanmış olabilir. | [ ] |
| `errTheTaskCouldNotBeCreatedCheckThe` | The task could not be created. Check the title and try again. | تعذّر إنشاء المهمة. تحقق من العنوان وحاول مرة أخرى. | Görev oluşturulamadı. Başlığı kontrol edip tekrar deneyin. | [ ] |
| `errThreadsAreTemporarilyUnavailablePleaseTryAgain` | Threads are temporarily unavailable. Please try again. | المحادثات غير متاحة مؤقتًا. يرجى المحاولة مرة أخرى. | Mesaj dizileri geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errUnableToAcknowledgeTheTaskPleaseTryAgain` | Unable to acknowledge the task. Please try again. | تعذّر الإقرار بالمهمة. يرجى المحاولة مرة أخرى. | Görev onaylanamadı. Lütfen tekrar deneyin. | [ ] |
| `errUnableToConfirmPleaseTryAgain` | Unable to confirm. Please try again. | تعذّر التأكيد. حاول مرة أخرى. | Onaylanamadı. Lütfen tekrar deneyin. | [ ] |
| `errUnableToCreateTheTaskPleaseTryAgain` | Unable to create the task. Please try again. | تعذّر إنشاء المهمة. يرجى المحاولة مرة أخرى. | Görev oluşturulamadı. Lütfen tekrar deneyin. | [ ] |
| `errUnableToLoadAvailableTimesPleaseTryAgain` | Unable to load available times. Please try again. | تعذّر تحميل الأوقات المتاحة. يرجى المحاولة مرة أخرى. | Uygun zamanlar yüklenemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToLoadMessagesPleaseTryAgain` | Unable to load messages. Please try again. | تعذّر تحميل الرسائل. يرجى المحاولة مرة أخرى. | Mesajlar yüklenemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToLoadThreadsPleaseTryAgain` | Unable to load threads. Please try again. | تعذّر تحميل المحادثات. يرجى المحاولة مرة أخرى. | Mesaj dizileri yüklenemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToReAssignTheTaskPleaseTry` | Unable to re-assign the task. Please try again. | تعذّرت إعادة إسناد المهمة. يرجى المحاولة مرة أخرى. | Görev yeniden atanamadı. Lütfen tekrar deneyin. | [ ] |
| `errUnableToSendTheMessagePleaseTryAgain` | Unable to send the message. Please try again. | تعذّر إرسال الرسالة. يرجى المحاولة مرة أخرى. | Mesaj gönderilemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToUpdateTheTaskPleaseTryAgain` | Unable to update the task. Please try again. | تعذّر تحديث المهمة. يرجى المحاولة مرة أخرى. | Görev güncellenemedi. Lütfen tekrar deneyin. | [ ] |
| `errUpdatingTheTaskIsTemporarilyUnavailablePleaseTry` | Updating the task is temporarily unavailable. Please try again. | تحديث المهمة غير متاح مؤقتًا. يرجى المحاولة مرة أخرى. | Görev güncelleme geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errYouDoNotHavePermissionToAdvanceThis` | You do not have permission to advance this task. | ليس لديك إذن بتقديم هذه المهمة. | Bu görevi ilerletme izniniz yok. | [ ] |
| `errYouDoNotHavePermissionToBookThis` | You do not have permission to book this consultation. | ليس لديك إذن بحجز هذه الاستشارة. | Bu danışmayı rezerve etme izniniz yok. | [ ] |
| `errYouDoNotHavePermissionToCreateTasks` | You do not have permission to create tasks on this matter. | ليس لديك إذن بإنشاء مهام على هذا الملف. | Bu dosyada görev oluşturma izniniz yok. | [ ] |
| `errYouDoNotHavePermissionToReAssign` | You do not have permission to re-assign this task. | ليس لديك إذن بإعادة إسناد هذه المهمة. | Bu görevi yeniden atama izniniz yok. | [ ] |
| `errYouDoNotHavePermissionToSendMessages` | You do not have permission to send messages on this thread. | ليس لديك إذن بإرسال رسائل في هذه المحادثة. | Bu mesaj dizisinde mesaj gönderme izniniz yok. | [ ] |
| `errYouDoNotHavePermissionToViewAvailable` | You do not have permission to view available times. | ليس لديك إذن لعرض الأوقات المتاحة. | Uygun zamanları görüntüleme izniniz yok. | [ ] |
| `errYouDoNotHavePermissionToViewThese` | You do not have permission to view these messages. | ليس لديك إذن لعرض هذه الرسائل. | Bu mesajları görüntüleme izniniz yok. | [ ] |
| `errYouDoNotHavePermissionToViewThese3` | You do not have permission to view these threads. | ليس لديك إذن لعرض هذه المحادثات. | Bu mesaj dizilerini görüntüleme izniniz yok. | [ ] |
| `errAttorneyNotFound` | Attorney not found. | المحامي غير موجود. | Avukat bulunamadı. | [ ] |
| `errTheDirectoryIsTemporarilyUnavailableTryAgain` | The directory is temporarily unavailable. Try again. | الدليل غير متاح مؤقتًا. حاول مرة أخرى. | Dizin geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errTheProfileDetailsAreInvalidCheckThemAnd` | The profile details are invalid. Check them and retry. | بيانات الملف الشخصي غير صالحة. تحقق منها وأعد المحاولة. | Profil bilgileri geçersiz. Kontrol edip tekrar deneyin. | [ ] |
| `errUnableToLoadTheDirectoryPleaseTryAgain` | Unable to load the directory. Please try again. | تعذّر تحميل الدليل. حاول مرة أخرى. | Dizin yüklenemedi. Lütfen tekrar deneyin. | [ ] |
| `errYouDoNotHavePermissionToManageThe` | You do not have permission to manage the directory. | ليس لديك إذن لإدارة الدليل. | Dizini yönetme izniniz yok. | [ ] |
| `errYouDoNotHavePermissionToViewThe` | You do not have permission to view the directory. | ليس لديك إذن لعرض الدليل. | Dizini görüntüleme izniniz yok. | [ ] |
| `errNotificationsAreTemporarilyUnavailablePleaseTryAgain` | Notifications are temporarily unavailable. Please try again. | الإشعارات غير متاحة مؤقتًا. يرجى المحاولة مرة أخرى. | Bildirimler geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errThisFileIsTooLarge` | This file is too large. | هذا الملف كبير جدًا. | Bu dosya çok büyük. | [ ] |
| `errThisFileTypeIsNotSupported` | This file type is not supported. | نوع هذا الملف غير مدعوم. | Bu dosya türü desteklenmiyor. | [ ] |
| `errUnableToCheckThePaymentStatusPleaseTry` | Unable to check the payment status. Please try again. | تعذّر التحقق من حالة الدفع. يرجى المحاولة مرة أخرى. | Ödeme durumu kontrol edilemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToLoadDocumentsPleaseTryAgain` | Unable to load documents. Please try again. | تعذّر تحميل المستندات. يرجى المحاولة مرة أخرى. | Belgeler yüklenemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToLoadFilesPleaseTryAgain` | Unable to load files. Please try again. | تعذّر تحميل الملفات. يرجى المحاولة مرة أخرى. | Dosyalar yüklenemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToLoadInvoicesPleaseTryAgain` | Unable to load invoices. Please try again. | تعذّر تحميل الفواتير. يرجى المحاولة مرة أخرى. | Faturalar yüklenemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToLoadMattersPleaseTryAgain` | Unable to load matters. Please try again. | تعذّر تحميل القضايا. يرجى المحاولة مرة أخرى. | Davalar yüklenemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToLoadNotificationsPleaseTryAgain` | Unable to load notifications. Please try again. | تعذّر تحميل الإشعارات. يرجى المحاولة مرة أخرى. | Bildirimler yüklenemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToOpenTheFilePleaseTryAgain` | Unable to open the file. Please try again. | تعذّر فتح الملف. يرجى المحاولة مرة أخرى. | Dosya açılamadı. Lütfen tekrar deneyin. | [ ] |
| `errUnableToStartThePaymentPleaseTryAgain` | Unable to start the payment. Please try again. | تعذّر بدء الدفع. يرجى المحاولة مرة أخرى. | Ödeme başlatılamadı. Lütfen tekrar deneyin. | [ ] |
| `errUnableToUploadTheFilePleaseTryAgain` | Unable to upload the file. Please try again. | تعذّر رفع الملف. يرجى المحاولة مرة أخرى. | Dosya yüklenemedi. Lütfen tekrar deneyin. | [ ] |
| `errYouDoNotHavePermissionToUploadFiles` | You do not have permission to upload files to this matter. | ليس لديك إذن لرفع ملفات إلى هذه القضية. | Bu davaya dosya yükleme izniniz yok. | [ ] |
| `errAIResearchIsNotConfiguredForThisDeployment` | AI research is not configured for this deployment. No analysis was run. | البحث بالذكاء الاصطناعي غير مُهيَّأ لهذا النشر. لم يتم تشغيل أي تحليل. | Yapay zekâ araştırması bu dağıtım için yapılandırılmamış. Hiçbir analiz çalıştırılmadı. | [ ] |
| `errAnActionIsAlreadyInProgress` | An action is already in progress. | هناك إجراء قيد التنفيذ بالفعل. | Zaten devam eden bir işlem var. | [ ] |
| `errEndingTheConsultationIsTemporarilyUnavailablePleaseTry` | Ending the consultation is temporarily unavailable. Please try again. | إنهاء الاستشارة غير متاح مؤقتًا. يرجى المحاولة مرة أخرى. | Görüşmeyi sonlandırma geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errEnterAQuestionBetweenResearchRequestMinQuestionLengthAndResearchRequest` | Enter a question between {minQuestionLength} and {maxQuestionLength} characters and select an organization. | أدخل سؤالاً يتراوح بين {minQuestionLength} و{maxQuestionLength} حرفًا واختر مؤسسة. | {minQuestionLength} ile {maxQuestionLength} karakter arasında bir soru girin ve bir kuruluş seçin. | [ ] |
| `errOnlyAPartnerOrAttorneyCanScheduleA` | Only a partner or attorney can schedule a video consultation. | يمكن لشريك أو محامٍ فقط جدولة استشارة بالفيديو. | Video görüşmesini yalnızca bir ortak veya avukat planlayabilir. | [ ] |
| `errOnlyTheCreatorOrAPartnerCanEnd` | Only the creator or a partner can end this consultation. | يمكن للمُنشئ أو الشريك فقط إنهاء هذه الاستشارة. | Bu görüşmeyi yalnızca oluşturan kişi veya bir ortak sonlandırabilir. | [ ] |
| `errOrganizationMembershipsCouldNotBeLoaded` | Organization memberships could not be loaded. | تعذّر تحميل عضويات المؤسسة. | Kuruluş üyelikleri yüklenemedi. | [ ] |
| `errSchedulingAConsultationIsTemporarilyUnavailablePleaseTry` | Scheduling a consultation is temporarily unavailable. Please try again. | جدولة الاستشارة غير متاحة مؤقتًا. يرجى المحاولة مرة أخرى. | Görüşme planlama geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errSelectAResearchRunToViewItsFindings` | Select a research run to view its findings. | اختر جولة بحث لعرض نتائجها. | Bulgularını görüntülemek için bir araştırma çalışması seçin. | [ ] |
| `errSelectAVideoConsultationToJoin` | Select a video consultation to join. | اختر استشارة فيديو للانضمام إليها. | Katılmak için bir video görüşmesi seçin. | [ ] |
| `errSelectAnOrganizationToScheduleAConsultation` | Select an organization to schedule a consultation. | اختر مؤسسة لجدولة استشارة. | Görüşme planlamak için bir kuruluş seçin. | [ ] |
| `errSelectAnOrganizationToViewResearchRuns` | Select an organization to view research runs. | اختر مؤسسة لعرض جولات البحث. | Araştırma çalışmalarını görüntülemek için bir kuruluş seçin. | [ ] |
| `errSelectAnOrganizationToViewVideoConsultations` | Select an organization to view video consultations. | اختر مؤسسة لعرض استشارات الفيديو. | Video görüşmelerini görüntülemek için bir kuruluş seçin. | [ ] |
| `errSignInAgainToUseVideoConsultations` | Sign in again to use video consultations. | سجّل الدخول مرة أخرى لاستخدام استشارات الفيديو. | Video görüşmelerini kullanmak için tekrar oturum açın. | [ ] |
| `errStartingTheConsultationIsTemporarilyUnavailablePleaseTry` | Starting the consultation is temporarily unavailable. Please try again. | بدء الاستشارة غير متاح مؤقتًا. يرجى المحاولة مرة أخرى. | Görüşmeyi başlatma geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errTheAIProviderReturnedAnUnexpectedResponsePlease` | The AI provider returned an unexpected response. Please try again. | أعاد مزوّد الذكاء الاصطناعي استجابة غير متوقعة. يرجى المحاولة مرة أخرى. | Yapay zekâ sağlayıcısı beklenmeyen bir yanıt döndürdü. Lütfen tekrar deneyin. | [ ] |
| `errTheConsultationCouldNotBeScheduledCheckThe` | The consultation could not be scheduled. Check the details and try again. | تعذّرت جدولة الاستشارة. تحقق من التفاصيل وحاول مرة أخرى. | Görüşme planlanamadı. Ayrıntıları kontrol edip tekrar deneyin. | [ ] |
| `errTheConsultationIsNotAvailableToJoinRight` | The consultation is not available to join right now. | الاستشارة غير متاحة للانضمام إليها الآن. | Görüşmeye şu anda katılmak mümkün değil. | [ ] |
| `errTheSelectedContextIsTooLargeRemoveDocuments` | The selected context is too large. Remove documents and try again. | السياق المحدد كبير جدًا. احذف بعض المستندات وحاول مرة أخرى. | Seçilen bağlam çok büyük. Bazı belgeleri kaldırıp tekrar deneyin. | [ ] |
| `errTheSelectedResearchRunWasNotFound` | The selected research run was not found. | لم يتم العثور على جولة البحث المحددة. | Seçilen araştırma çalışması bulunamadı. | [ ] |
| `errThisConsultationCanNoLongerBeEnded` | This consultation can no longer be ended. | لم يعد من الممكن إنهاء هذه الاستشارة. | Bu görüşme artık sonlandırılamaz. | [ ] |
| `errThisConsultationCanNoLongerBeStarted` | This consultation can no longer be started. | لم يعد من الممكن بدء هذه الاستشارة. | Bu görüşme artık başlatılamaz. | [ ] |
| `errThisVideoConsultationHasAlreadyEnded` | This video consultation has already ended. | انتهت استشارة الفيديو هذه بالفعل. | Bu video görüşmesi zaten sona erdi. | [ ] |
| `errThisVideoConsultationWasNotFound` | This video consultation was not found. | لم يتم العثور على استشارة الفيديو هذه. | Bu video görüşmesi bulunamadı. | [ ] |
| `errUnableToEndTheConsultationPleaseTryAgain` | Unable to end the consultation. Please try again. | تعذّر إنهاء الاستشارة. يرجى المحاولة مرة أخرى. | Görüşme sonlandırılamadı. Lütfen tekrar deneyin. | [ ] |
| `errUnableToJoinTheConsultationPleaseTryAgain` | Unable to join the consultation. Please try again. | تعذّر الانضمام إلى الاستشارة. يرجى المحاولة مرة أخرى. | Görüşmeye katılınamadı. Lütfen tekrar deneyin. | [ ] |
| `errUnableToLoadVideoConsultationsPleaseTryAgain` | Unable to load video consultations. Please try again. | تعذّر تحميل استشارات الفيديو. يرجى المحاولة مرة أخرى. | Video görüşmeleri yüklenemedi. Lütfen tekrar deneyin. | [ ] |
| `errUnableToReadTheVideoConsultationPleaseTry` | Unable to read the video consultation. Please try again. | تعذّرت قراءة استشارة الفيديو. يرجى المحاولة مرة أخرى. | Video görüşmesi okunamadı. Lütfen tekrar deneyin. | [ ] |
| `errUnableToRunAIResearchPleaseTryAgain` | Unable to run AI research. Please try again. | تعذّر تشغيل البحث بالذكاء الاصطناعي. يرجى المحاولة مرة أخرى. | Yapay zekâ araştırması çalıştırılamadı. Lütfen tekrar deneyin. | [ ] |
| `errUnableToScheduleTheConsultationPleaseTryAgain` | Unable to schedule the consultation. Please try again. | تعذّرت جدولة الاستشارة. يرجى المحاولة مرة أخرى. | Görüşme planlanamadı. Lütfen tekrar deneyin. | [ ] |
| `errUnableToStartTheConsultationPleaseTryAgain` | Unable to start the consultation. Please try again. | تعذّر بدء الاستشارة. يرجى المحاولة مرة أخرى. | Görüşme başlatılamadı. Lütfen tekrar deneyin. | [ ] |
| `errVideoCallsAreNotConfiguredForThisDeployment` | Video calls are not configured for this deployment. No call was started. | مكالمات الفيديو غير مُهيَّأة لهذا النشر. لم يتم بدء أي مكالمة. | Video aramaları bu dağıtım için yapılandırılmamış. Hiçbir arama başlatılmadı. | [ ] |
| `errVideoCallsAreTemporarilyUnavailablePleaseTryAgain` | Video calls are temporarily unavailable. Please try again. | مكالمات الفيديو غير متاحة مؤقتًا. يرجى المحاولة مرة أخرى. | Video aramaları geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errVideoConsultationsAreTemporarilyUnavailablePleaseTryAgain` | Video consultations are temporarily unavailable. Please try again. | استشارات الفيديو غير متاحة مؤقتًا. يرجى المحاولة مرة أخرى. | Video görüşmeleri geçici olarak kullanılamıyor. Lütfen tekrar deneyin. | [ ] |
| `errWeCouldnTCompleteThatRequestPleaseTry` | We couldn't complete that request. Please try again. | تعذّر إكمال هذا الطلب. يرجى المحاولة مرة أخرى. | Bu isteği tamamlayamadık. Lütfen tekrar deneyin. | [ ] |
| `errYouDoNotHavePermissionToJoinThis` | You do not have permission to join this consultation. | ليس لديك إذن للانضمام إلى هذه الاستشارة. | Bu görüşmeye katılma izniniz yok. | [ ] |
| `errYouDoNotHavePermissionToStartThis` | You do not have permission to start this consultation. | ليس لديك إذن لبدء هذه الاستشارة. | Bu görüşmeyi başlatma izniniz yok. | [ ] |
| `errYouDoNotHavePermissionToViewVideo` | You do not have permission to view video consultations. | ليس لديك إذن لعرض استشارات الفيديو. | Video görüşmelerini görüntüleme izniniz yok. | [ ] |
