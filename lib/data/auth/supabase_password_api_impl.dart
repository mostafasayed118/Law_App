import 'package:legalhub/data/auth/supabase_password_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [PasswordApi] backed by the Supabase client.
///
/// This is a data-layer file: the only place the provider import lives for this
/// action. Failure kinds are DTO-free and token-free when they cross the seam.
class SupabasePasswordApiImpl implements PasswordApi {
  SupabasePasswordApiImpl([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<void> changePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (error) {
      final String message = error.message.toLowerCase();
      throw PasswordChangeException(
        message.contains('reauthentication') ||
                message.contains('relogin') ||
                message.contains('recent login') ||
                message.contains('confirm password')
            ? PasswordChangeFailureKind.reauthRequired
            : PasswordChangeFailureKind.unavailable,
        message: error.message,
      );
    }
  }
}
