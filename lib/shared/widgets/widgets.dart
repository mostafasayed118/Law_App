/// Barrel file for shared, reusable presentation widgets.
///
/// Importing this single file gives access to the cross-feature form fields,
/// layout helpers, the LegalHub app bar, and the canonical [ViewStateView]
/// renderer. Per the architecture rules (INSTRUCTIONS §4.1), only widgets with
/// a real cross-feature reuse live here; single-consumer widgets belong to
/// their owning feature. See ADR-0004 for the relocation record and the
/// ViewStateView retention rationale. ViewStateView was added to this barrel
/// once it gained its first feature consumer (the password-recovery flow),
/// converting "retained by contract" into "retained by use."
library;

export 'app_centered_message.dart';
export 'app_centered_retry.dart';
export 'app_entry_card.dart';
export 'app_filter_chips.dart';
export 'app_tile.dart';
export 'confirm_dialog.dart';
export 'directional_icon.dart';
export 'form_fields/labelled_field.dart';
export 'form_fields/legalhub_text_field.dart';
export 'form_fields/password_field.dart';
export 'form_fields/password_strength_indicator.dart';
export 'label_chip.dart';
export 'layout/auth_scaffold.dart';
export 'layout/icon_hero_badge.dart';
export 'legalhub_components.dart';
export 'practice_area_label.dart';
export 'role_label.dart';
export 'view_state_list.dart';
export 'view_state_switch.dart';
export 'view_state_view.dart';
export 'workspace_section.dart';
