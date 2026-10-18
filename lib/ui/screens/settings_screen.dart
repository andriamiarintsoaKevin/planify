part of '../../main.dart';

extension _PlanoSettingsScreen on _PlanoAppState {
  Widget _settingsPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Réglages',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.person_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: const Text(
                'Mon espace',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _authRepository?.currentUser?.email ??
                    'Aucun compte connecté · données locales',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showAccountDialog,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(_syncIcon),
              title: const Text(
                'Synchronisation',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(_syncStatusLabel),
              trailing: _syncStatus == SyncStatus.error
                  ? TextButton(
                      onPressed: _retrySync,
                      child: const Text('Réessayer'),
                    )
                  : TextButton(
                      onPressed: _requestSync,
                      child: const Text('Actualiser'),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          const _SettingsHeader('Préférences'),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Apparence sombre'),
              value: _darkMode,
              activeThumbColor: _primary,
              onChanged: _setDarkMode,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Assistant IA'),
              subtitle: Text(
                _aiConsentGranted
                    ? 'Consentement Google (Gemini) accordé sur cet appareil'
                    : 'Le consentement sera demandé avant le premier envoi',
              ),
              trailing: _aiConsentGranted
                  ? TextButton(
                      onPressed: _revokeAiConsent,
                      child: const Text('Révoquer'),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _aiConsentGranted ? null : _openAiTaskScreen,
            ),
          ),
          if (_aiConsentGranted)
            Card(
              child: ListTile(
                leading: const Icon(Icons.edit_note_outlined),
                title: const Text('Créer des tâches avec l’IA'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openAiTaskScreen,
              ),
            ),
          const SizedBox(height: 14),
          const _SettingsHeader('Calendriers'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Calendrier Google / appareil'),
              subtitle: Text(
                _calendarId == null
                    ? 'Non connecté · lecture seule'
                    : 'Connecté · événements importés en lecture seule',
              ),
              trailing: _calendarId == null
                  ? TextButton(
                      onPressed: _connectCalendar,
                      child: const Text('Connecter'),
                    )
                  : TextButton(
                      onPressed: _disconnectCalendar,
                      child: const Text('Déconnecter'),
                    ),
              onTap: _calendarId == null ? _connectCalendar : null,
            ),
          ),
          if (_calendarId == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                'Ajoutez votre compte Google dans les réglages système avant de connecter un calendrier. Planify ne crée ni ne modifie aucun événement.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 14),
          const _SettingsHeader('Données'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Exporter mes données'),
              subtitle: const Text('Copier les tâches et réglages en JSON'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _exportData,
            ),
          ),
          const SizedBox(height: 14),
          const _SettingsHeader('À propos'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Comprendre Planify'),
              subtitle: const Text(
                'Fonctions présentes, limites et prochaines étapes',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openProductGuide,
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.layers_outlined),
              title: Text('MVP local · version 1.0.1'),
              subtitle: Text('Données enregistrées sur cet appareil'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      final tasks = await _taskRepository.loadTasks();
      final export = {
        'formatVersion': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'tasks': [
          for (final task in tasks)
            {
              'id': task.id,
              'title': task.title,
              'notes': task.notes,
              'durationMinutes': task.durationMinutes,
              'priority': task.priority.name,
              'dueDate': task.dueDate?.toIso8601String(),
              'plannedEnd': task.plannedEnd?.toIso8601String(),
              'status': task.status.name,
              'scheduledStart': task.scheduledStart?.toIso8601String(),
              'project': task.project,
              'isLocked': task.isLocked,
              'isAiProposed': task.isAiProposed,
              'isDurationEstimated': task.isDurationEstimated,
              'reminderEnabled': task.reminderEnabled,
              'createdAt': task.createdAt?.toIso8601String(),
              'updatedAt': task.updatedAt?.toIso8601String(),
            },
        ],
        'settings': {
          'darkMode': _darkMode,
          'calendarId': _calendarId,
          'aiGeminiConsentGranted': _aiConsentGranted,
        },
      };
      final json = const JsonEncoder.withIndent('  ').convert(export);
      if (!mounted) return;
      await showDialog<void>(
        context: _appContext!,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Exporter mes données'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(child: SelectableText(json)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer'),
            ),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await Clipboard.setData(ClipboardData(text: json));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _showMessage('JSON copié dans le presse-papiers');
                } on Object catch (error) {
                  _showMessage('Impossible de copier le JSON : $error');
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copier le JSON'),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      _showMessage('Impossible de préparer l’export JSON : $error');
    }
  }

  IconData get _syncIcon => switch (_syncStatus) {
    SyncStatus.upToDate => Icons.cloud_done_outlined,
    SyncStatus.pending => Icons.cloud_upload_outlined,
    SyncStatus.error => Icons.cloud_off_outlined,
    SyncStatus.offline => Icons.cloud_off_outlined,
  };

  String get _syncStatusLabel {
    if (!AppConfig.isConfigured) {
      return 'Local uniquement · configuration absente';
    }
    return switch (_syncStatus) {
      SyncStatus.upToDate => 'À jour',
      SyncStatus.pending => 'Synchronisation en attente',
      SyncStatus.error => 'Erreur de synchronisation · réessayer',
      SyncStatus.offline => 'Hors ligne · connexion facultative',
    };
  }
}

class _AiTaskScreen extends StatefulWidget {
  const _AiTaskScreen({
    required this.consentGranted,
    required this.onConsentAccepted,
    required this.onAnalyze,
    required this.onAddToInbox,
    required this.onConnect,
  });

  final bool consentGranted;
  final Future<void> Function() onConsentAccepted;
  final Future<List<PlanoTask>> Function(String text) onAnalyze;
  final Future<bool> Function(List<PlanoTask> tasks) onAddToInbox;
  final Future<void> Function() onConnect;

  @override
  State<_AiTaskScreen> createState() => _AiTaskScreenState();
}

class _AiTaskScreenState extends State<_AiTaskScreen> {
  final _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _tasks = <PlanoTask>[];
  late bool _consentGranted = widget.consentGranted;
  var _busy = false;
  String? _errorMessage;
  bool _showConnectAction = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = _textController.text.trim();
    if (text.isEmpty || text.length > 4000 || _busy) return;

    if (!_consentGranted) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Consentement requis'),
          content: const Text(
            'Votre texte est envoyé à Google (Gemini) pour être analysé',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Pas maintenant'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accepter et analyser'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      try {
        await widget.onConsentAccepted();
        if (mounted) setState(() => _consentGranted = true);
      } on AiTaskFailure catch (error) {
        setState(() => _errorMessage = error.message);
        return;
      }
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
      _showConnectAction = false;
    });
    try {
      final tasks = await widget.onAnalyze(text);
      if (!mounted) return;
      setState(() {
        _tasks
          ..clear()
          ..addAll(tasks);
      });
    } on AiTaskFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _showConnectAction = error.kind == AiTaskFailureKind.notConnected;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addToInbox() async {
    if (_busy || _tasks.isEmpty || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final saved = await widget.onAddToInbox(List.unmodifiable(_tasks));
      if (saved && mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _updateTask(String taskId, PlanoTask Function(PlanoTask) update) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) return;
    setState(() => _tasks[index] = update(_tasks[index]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer avec l’IA')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Décrivez les tâches à créer. Aucun horaire ne sera fixé.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLength: 4000,
              maxLines: 5,
              minLines: 3,
              enabled: !_busy,
              decoration: const InputDecoration(
                hintText: 'Ex. appeler Marie demain 15 min, finir le devis 2h avant vendredi',
                border: OutlineInputBorder(),
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _analyze,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('Analyser'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              if (_showConnectAction)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _busy ? null : widget.onConnect,
                    child: const Text('Se connecter'),
                  ),
                ),
            ],
            if (_tasks.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Vérifiez et modifiez les tâches',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final task in _tasks)
                Card(
                  key: ValueKey(task.id),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: task.title,
                                decoration: const InputDecoration(
                                  labelText: 'Titre',
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Saisissez un titre'
                                    : null,
                                onChanged: (value) => _updateTask(
                                  task.id,
                                  (current) =>
                                      current.copyWith(title: value.trim()),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Supprimer cette tâche',
                              onPressed: _busy
                                  ? null
                                  : () => setState(
                                      () => _tasks.removeWhere(
                                        (item) => item.id == task.id,
                                      ),
                                    ),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        TextFormField(
                          initialValue: '${task.durationMinutes}',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Durée en minutes',
                          ),
                          validator: (value) {
                            final duration = int.tryParse(value ?? '');
                            return duration == null ||
                                    duration < 1 ||
                                    duration > 1440
                                ? 'Indiquez une durée de 1 à 1440 minutes'
                                : null;
                          },
                          onChanged: (value) {
                            final duration = int.tryParse(value);
                            if (duration == null ||
                                duration < 1 ||
                                duration > 1440) {
                              return;
                            }
                            _updateTask(
                              task.id,
                              (current) =>
                                  current.copyWith(durationMinutes: duration),
                            );
                          },
                        ),
                        DropdownButtonFormField<TaskPriority>(
                          initialValue: task.priority,
                          decoration: const InputDecoration(
                            labelText: 'Priorité',
                          ),
                          items: [
                            for (final priority in TaskPriority.values)
                              DropdownMenuItem(
                                value: priority,
                                child: Text(_priorityLabel(priority)),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (priority) {
                                  if (priority != null) {
                                    _updateTask(
                                      task.id,
                                      (current) =>
                                          current.copyWith(priority: priority),
                                    );
                                  }
                                },
                        ),
                        if (task.dueDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Date limite : ${_formatDate(task.dueDate!)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _addToInbox,
                child: const Text('Ajouter à l’Inbox'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
