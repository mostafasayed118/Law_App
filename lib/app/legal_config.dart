/// Owner-supplied legal metadata for the in-app Privacy Policy and Terms
/// (ADR-0011).
///
/// These are the ONLY places the operator name, contact address, last-updated
/// date and governing law are set. The values are deliberately obvious
/// placeholders: nothing here invents a legal entity or a jurisdiction. Until
/// the owner replaces them, the screens render an honest "not configured"
/// notice instead of a fabricated contact address.
abstract final class LegalConfig {
  static const String operatorName = 'AL-3TAR';
  static const String contactEmail = 'al3rar401@gmail.com';
  static const String lastUpdated = '2026-11-17';
  static const String governingLaw = 'Laws of Egypt';

  static bool get isConfigured =>
      !operatorName.startsWith('REPLACE_') &&
      !contactEmail.startsWith('REPLACE_') &&
      !lastUpdated.startsWith('REPLACE_') &&
      !governingLaw.startsWith('REPLACE_');
}
