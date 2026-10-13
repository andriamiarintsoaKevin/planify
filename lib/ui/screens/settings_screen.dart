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
              subtitle: const Text('Aucun compte connecté · données locales'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showMessage(
                'La création de compte sera configurée avec Firebase.',
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
}
