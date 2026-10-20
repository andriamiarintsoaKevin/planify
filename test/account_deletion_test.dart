import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planify/data/auth_repository.dart';
import 'package:planify/data/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'appelle la fonction sans transmettre un identifiant utilisateur',
    () async {
      late http.Request functionRequest;
      final client = await _authenticatedClient((request) async {
        if (request.url.path == '/functions/v1/delete-account') {
          functionRequest = request;
          return _jsonResponse(200, {'success': true});
        }
        return _jsonResponse(200, const {});
      });
      addTearDown(client.dispose);

      await SupabaseAuthRepository(client).deleteAccount();

      expect(functionRequest.url.path, '/functions/v1/delete-account');
      expect(functionRequest.headers.containsKey('authorization'), isTrue);
      expect(jsonDecode(functionRequest.body), isEmpty);
      expect(client.auth.currentSession, isNull);
    },
  );

  test('refuse une suppression sans session', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((_) async => _jsonResponse(500, const {})),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseAuthRepository(client).deleteAccount(),
      throwsA(isA<AccountDeletionFailure>()),
    );
  });

  test('traduit une réponse HTTP 401 en erreur de session', () async {
    final client = await _authenticatedClient((_) async {
      return _jsonResponse(401, {'error': 'unauthorized'});
    });
    addTearDown(client.dispose);

    await expectLater(
      SupabaseAuthRepository(client).deleteAccount(),
      throwsA(
        isA<AccountDeletionFailure>().having(
          (error) => error.message,
          'message',
          contains('session a expiré'),
        ),
      ),
    );
    expect(client.auth.currentSession, isNotNull);
  });
}

Future<SupabaseClient> _authenticatedClient(
  Future<http.Response> Function(http.Request request) handler,
) async {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-publishable-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(handler),
  );
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token': 'test-token',
      'refresh_token': 'test-refresh-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': '00000000-0000-4000-8000-000000000001',
        'aud': 'authenticated',
        'created_at': DateTime.utc(2026).toIso8601String(),
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      },
    }),
  );
  return client;
}

http.Response _jsonResponse(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: const {'content-type': 'application/json'},
);
