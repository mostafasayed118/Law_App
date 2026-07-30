/// Barrel file for shared, reusable presentation widgets.
///
/// Importing this single file gives access to the cross-feature form fields,
/// layout helpers, and the LegalHub app bar. Per the architecture rules
/// (INSTRUCTIONS §4.1), only widgets with a real cross-feature reuse live
/// here; single-consumer widgets belong to their owning feature. See ADR-0004
/// for the relocation record.
library;

export 'form_fields/labelled_field.dart';
export 'form_fields/legalhub_text_field.dart';
export 'form_fields/password_field.dart';
export 'layout/auth_scaffold.dart';
export 'layout/icon_hero_badge.dart';
export 'legalhub_components.dart';
