import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/planner.dart';
import 'task_id.dart';

const String aiTaskFunctionName = 'dynamic-action';

enum AiTaskFailureKind {
  notConnected,
  offline,
  dailyLimit,
  providerBusy,
  invalidResponse,
  unavailable,
}

class AiTaskFailure implements Exception {
  const AiTaskFailure(this.kind, this.message);

  final AiTaskFailureKind kind;
  final String message;
}

class AiTaskService {
  const AiTaskService(this.client);

  final SupabaseClient client;

  Future<List<PlanoTask>> analyze(String rawText) async {
    final session = client.auth.currentSession;
    if (session == null) {
      throw const AiTaskFailure(
        AiTaskFailureKind.notConnected,
        'Connectez-vous pour utiliser l’analyse IA.',
      );
    }

    final text = rawText.trim();
    if (text.isEmpty || text.length > 4000) {
      throw const AiTaskFailure(
        AiTaskFailureKind.invalidResponse,
        'Saisissez un texte de 1 à 4000 caractères.',
      );
    }

    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      final now = DateTime.now();
      final response = await client.functions.invoke(
        aiTaskFunctionName,
        body: {
          'text': text,
          'timezone': timezone.identifier,
          'today':
              '${now.year.toString().padLeft(4, '0')}-'
              '${now.month.toString().padLeft(2, '0')}-'
              '${now.day.toString().padLeft(2, '0')}',
        },
      );
      return _tasksFromResponse(response.data);
    } on AiTaskFailure {
      rethrow;
    } on FunctionException catch (error) {
      final details = error.details;
      final errorCode = details is Map ? details['error'] : null;
      if (error.status == 0) {
        throw const AiTaskFailure(
          AiTaskFailureKind.offline,
          'Connexion impossible. Vérifiez votre réseau puis réessayez.',
        );
      }
      if (error.status == 401) {
        throw const AiTaskFailure(
          AiTaskFailureKind.notConnected,
          'Connectez-vous pour utiliser l’analyse IA.',
        );
      }
      if (error.status == 429) {
        if (errorCode == 'provider_quota_reached') {
          throw const AiTaskFailure(
            AiTaskFailureKind.providerBusy,
            'Le service IA est saturé. Réessayez plus tard.',
          );
        }
        throw const AiTaskFailure(
          AiTaskFailureKind.dailyLimit,
          'La limite quotidienne d’utilisation de l’IA est atteinte.',
        );
      }
      if (error.status == 502 || error.status == 503 || error.status == 504) {
        throw const AiTaskFailure(
          AiTaskFailureKind.unavailable,
          'Le service IA est temporairement indisponible. Réessayez plus tard.',
        );
      }
      throw const AiTaskFailure(
        AiTaskFailureKind.unavailable,
        'Impossible d’analyser le texte. Réessayez plus tard.',
      );
    } on PlatformException {
      throw const AiTaskFailure(
        AiTaskFailureKind.unavailable,
        'Impossible de déterminer le fuseau horaire de cet appareil.',
      );
    } on FormatException {
      throw const AiTaskFailure(
        AiTaskFailureKind.invalidResponse,
        'La réponse de l’IA est invalide. Réessayez plus tard.',
      );
    }
  }

  List<PlanoTask> _tasksFromResponse(Object? response) {
    if (response is! Map || response['tasks'] is! List) {
      throw const AiTaskFailure(
        AiTaskFailureKind.invalidResponse,
        'La réponse de l’IA est invalide. Réessayez plus tard.',
      );
    }

    final tasks = response['tasks'] as List;
    final parsed = <PlanoTask>[];
    for (final value in tasks) {
      if (value is! Map) {
        throw const AiTaskFailure(
          AiTaskFailureKind.invalidResponse,
          'La réponse de l’IA est invalide. Réessayez plus tard.',
        );
      }

      final title = value['titre'];
      final duration = value['duree_minutes'];
      final priority = value['priorite'];
      final notes = value['notes'];
      final dueDate = value['date_limite'];

      if (title is! String ||
          title.trim().isEmpty ||
          duration is! int ||
          duration < 1 ||
          duration > 1440 ||
          priority is! String ||
          !const ['low', 'medium', 'high'].contains(priority) ||
          notes is! String ||
          (dueDate != null && dueDate is! String)) {
        throw const AiTaskFailure(
          AiTaskFailureKind.invalidResponse,
          'La réponse de l’IA est invalide. Réessayez plus tard.',
        );
      }

      DateTime? parsedDueDate;
      if (dueDate is String) {
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dueDate)) {
          throw const AiTaskFailure(
            AiTaskFailureKind.invalidResponse,
            'La réponse de l’IA est invalide. Réessayez plus tard.',
          );
        }
        final utcDate = DateTime.tryParse('${dueDate}T00:00:00.000Z');
        if (utcDate == null ||
            utcDate.toIso8601String().substring(0, 10) != dueDate) {
          throw const AiTaskFailure(
            AiTaskFailureKind.invalidResponse,
            'La réponse de l’IA est invalide. Réessayez plus tard.',
          );
        }
        parsedDueDate = DateTime(utcDate.year, utcDate.month, utcDate.day);
      }

      parsed.add(
        PlanoTask(
          id: generateTaskId(),
          title: title.trim(),
          notes: notes,
          durationMinutes: duration,
          priority: TaskPriority.values.byName(priority),
          dueDate: parsedDueDate,
          status: TaskStatus.inbox,
        ),
      );
    }

    return parsed;
  }
}
