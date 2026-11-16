/// Owner-supplied legal metadata for the in-app Privacy Policy and Terms
/// (ADR-0011).
///
/// These are the ONLY places the operator name, contact address, last-updated
/// date and governing law are set. The values are deliberately obvious
/// placeholders: nothing here invents a legal entity or a jurisdiction. Until
/// the owner replaces them, the screens render an honest "not configured"
/// notice instead of a fabricated contact address.
abstract final class LegalConfig {
  static const String operatorName = 'REPLACE_WITH_LEGAL_ENTITY_NAME';
  static const String contactEmail = 'REPLACE_WITH_CONTACT_EMAIL';
  static const String lastUpdated = 'REPLACE_WITH_YYYY-MM-DD';
  static const String governingLaw = 'REPLACE_WITH_GOVERNING_LAW';

  static bool get isConfigured =>
      !operatorName.startsWith('REPLACE_') &&
      !contactEmail.startsWith('REPLACE_') &&
      !lastUpdated.startsWith('REPLACE_') &&
      !governingLaw.startsWith('REPLACE_');
}
