import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:legalhub/app/deep_link/app_link_listener.dart';
import 'package:legalhub/app/deep_link/app_link_parser.dart';
import 'package:legalhub/app/deep_link/app_link_source.dart';
import 'package:legalhub/app/deep_link/pending_accept_invite_store.dart';

/// Stub [AppLinkSource] with a controllable initial link and a broadcast
/// stream, so the listener is tested without the app_links plugin.
class _StubAppLinkSource implements AppLinkSource {
  Uri? initialLink;
  final StreamController<Uri> _uris = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async => initialLink;

  @override
  Stream<Uri> get onUri => _uris.stream;

  void emit(Uri uri) => _uris.add(uri);

  Future<void> close() => _uris.close();
}

void main() {
  late _StubAppLinkSource source;
  late PendingAcceptInviteStore store;
  late AppLinkListener listener;
  int navigationCalls = 0;

  setUp(() {
    source = _StubAppLinkSource();
    store = PendingAcceptInviteStore();
    navigationCalls = 0;
    listener = AppLinkListener(
      source,
      const AppLinkParser(),
      store,
      () => navigationCalls += 1,
    );
  });

  tearDown(() async {
    await listener.dispose();
    await source.close();
  });

  test('a cold-start accept link buffers the token and opens the accept '
      'surface', () async {
    source.initialLink = Uri.parse(
      'com.legalhub.app://accept-invite?token=one-time-token',
    );

    await listener.start();

    expect(store.takePendingToken(), 'one-time-token');
    expect(navigationCalls, 1);
  });

  test('a warm-start accept link is handled too', () async {
    await listener.start();

    source.emit(Uri.parse('com.legalhub.app://accept-invite?token=warm-token'));
    // The broadcast stream delivers asynchronously.
    await Future<void>.delayed(Duration.zero);

    expect(store.takePendingToken(), 'warm-token');
    expect(navigationCalls, 1);
  });

  test('a recovery callback URI is untouched (supabase owns it)', () async {
    source.initialLink = Uri.parse(
      'com.legalhub.app://auth/v1/callback?code=pkce-code',
    );

    await listener.start();
    source.emit(Uri.parse('com.legalhub.app://auth/v1/callback?code=abc'));
    await Future<void>.delayed(Duration.zero);

    expect(store.hasPendingToken, isFalse);
    expect(store.takePendingToken(), isNull);
    expect(navigationCalls, 0);
  });

  test('a foreign URI is ignored', () async {
    source.initialLink = Uri.parse('https://example.com/accept-invite');

    await listener.start();

    expect(store.hasPendingToken, isFalse);
    expect(navigationCalls, 0);
  });

  test('an accept link without a token is not buffered', () async {
    source.initialLink = Uri.parse('com.legalhub.app://accept-invite');

    await listener.start();

    expect(store.hasPendingToken, isFalse);
    expect(navigationCalls, 0);
  });

  test('a null initial link is a no-op', () async {
    await listener.start();

    expect(store.hasPendingToken, isFalse);
    expect(navigationCalls, 0);
  });
}
