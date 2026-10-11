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
              leading: const CircleAvatar(
                backgroundColor: _primarySoft,
                child: Icon(Icons.person_outline, color: _primary),
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
          const _SettingsHeader('Planification'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Heures de travail'),
                  subtitle: Text(
                    '${_timeOfDayLabel(_workStart)} – ${_timeOfDayLabel(_workEnd)}, du lundi au vendredi',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _editWorkHours,
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Apparence sombre'),
                  value: _darkMode,
                  activeThumbColor: _primary,
                  onChanged: _setDarkMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _SettingsHeader('Calendriers'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Calendrier de l’iPhone'),
              subtitle: const Text('Lecture seule · non connecté'),
              trailing: TextButton(
                onPressed: () => _showMessage(
                  'La connexion réelle au calendrier nécessite la configuration native iOS.',
                ),
                child: const Text('Connecter'),
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
              title: Text('MVP local · version 1.0.0'),
              subtitle: Text('Données enregistrées sur cet appareil'),
            ),
          ),
        ],
      ),
    );
  }
}
