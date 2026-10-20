import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planify/data/ai_task_service.dart';
import 'package:planify/domain/planner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const timezoneChannel = MethodChannel('flutter_timezone');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezoneChannel, (call) async {
          expect(call.method, 'getLocalTimezone');
          return 'Pacific/Auckland';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezoneChannel, null);
  });

  test(
    'convertit la réponse en tâches Inbox avec deadline distincte',
    () async {
      late http.Request receivedRequest;
      final client = await _authenticatedClient((request) async {
        receivedRequest = request;
        return _jsonResponse(200, {
          'tasks': [
            {
              'titre': 'Préparer le devis',
              'duree_minutes': 45,
              'priorite': 'high',
              'date_limite': '2026-10-21',
              'notes': 'Demander les tarifs',
            },
            {
              'titre': 'Envoyer le compte rendu',
              'duree_minutes': 20,
              'priorite': 'low',
              'notes': '',
            },
          ],
        });
      });
      addTearDown(client.dispose);

      final tasks = await AiTaskService(client).analyze('  Deux tâches  ');

      expect(tasks, hasLength(2));
      expect(tasks.first.title, 'Préparer le devis');
      expect(tasks.first.durationMinutes, 45);
      expect(tasks.first.priority, TaskPriority.high);
      expect(tasks.first.dueDate, DateTime(2026, 10, 21));
      expect(tasks.first.plannedEnd, isNull);
      expect(tasks.first.scheduledStart, isNull);
      expect(tasks.first.status, TaskStatus.inbox);
      expect(tasks.last.priority, TaskPriority.low);
      expect(tasks.last.dueDate, isNull);
      expect(tasks.last.plannedEnd, isNull);

      expect(receivedRequest.url.path, '/functions/v1/dynamic-action');
      expect(receivedRequest.headers['authorization'], 'Bearer test-token');
      final body = jsonDecode(receivedRequest.body) as Map<String, dynamic>;
      expect(body['text'], 'Deux tâches');
      expect(body['timezone'], 'Pacific/Auckland');
      expect(body['today'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    },
  );

  test(
    'traduit 401, 429 quotidien et 429 Gemini en erreurs explicites',
    () async {
      for (final scenario in [
        (
          status: 401,
          code: 'unauthorized',
          kind: AiTaskFailureKind.notConnected,
        ),
        (
          status: 429,
          code: 'daily_limit_reached',
          kind: AiTaskFailureKind.dailyLimit,
        ),
        (
          status: 429,
          code: 'provider_quota_reached',
          kind: AiTaskFailureKind.providerBusy,
        ),
      ]) {
        final client = await _authenticatedClient((_) async {
          return _jsonResponse(scenario.status, {'error': scenario.code});
        });
        addTearDown(client.dispose);

        await expectLater(
          AiTaskService(client).analyze('Texte de test'),
          throwsA(
            isA<AiTaskFailure>().having(
              (failure) => failure.kind,
              'kind',
              scenario.kind,
            ),
          ),
        );
      }
    },
  );

  test('traduit les erreurs 502, 503 et 504 en indisponibilité', () async {
    for (final status in [502, 503, 504]) {
      final client = await _authenticatedClient((_) async {
        return _jsonResponse(status, {'error': 'unavailable'});
      });
      addTearDown(client.dispose);

      await expectLater(
        AiTaskService(client).analyze('Texte de test'),
        throwsA(
          isA<AiTaskFailure>().having(
            (failure) => failure.kind,
            'kind',
            AiTaskFailureKind.unavailable,
          ),
        ),
      );
    }
  });

  test('traduit une absence de réseau en message hors ligne', () async {
    final client = await _authenticatedClient((_) async {
      throw const SocketException('offline');
    });
    addTearDown(client.dispose);

    await expectLater(
      AiTaskService(client).analyze('Texte de test'),
      throwsA(
        isA<AiTaskFailure>().having(
          (failure) => failure.kind,
          'kind',
          AiTaskFailureKind.offline,
        ),
      ),
    );
  });

  test('refuse une réponse IA invalide', () async {
    final client = await _authenticatedClient((_) async {
      return _jsonResponse(200, {
        'tasks': [
          {'titre': 'Sans durée'},
        ],
      });
    });
    addTearDown(client.dispose);

    await expectLater(
      AiTaskService(client).analyze('Texte de test'),
      throwsA(
        isA<AiTaskFailure>().having(
          (failure) => failure.kind,
          'kind',
          AiTaskFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('refuse une requête sans session utilisateur', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((_) async => _jsonResponse(500, const {})),
    );
    addTearDown(client.dispose);

    await expectLater(
      AiTaskService(client).analyze('Texte de test'),
      throwsA(
        isA<AiTaskFailure>().having(
          (failure) => failure.kind,
          'kind',
          AiTaskFailureKind.notConnected,
        ),
      ),
    );
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
