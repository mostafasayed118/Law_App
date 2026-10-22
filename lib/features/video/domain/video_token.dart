import 'package:equatable/equatable.dart';

/// The `video-token` function's success payload: where to connect, the
/// short-lived room JWT, and the room it scopes.
///
/// The token is provider credentials material — never logged, never stored,
/// and only handed to `livekit_client` for the in-memory connection.
class VideoToken extends Equatable {
  const VideoToken({
    required this.url,
    required this.token,
    required this.room,
  });

  final String url;
  final String token;
  final String room;

  @override
  List<Object?> get props => <Object?>[url, token, room];
}
