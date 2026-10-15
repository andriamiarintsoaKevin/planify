part of '../../main.dart';

class _ProductGuideScreen extends StatelessWidget {
  const _ProductGuideScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comprendre Planify')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _GuideNotice(
            icon: Icons.science_outlined,
            title: 'Version locale de test',
            body: 'Planify fonctionne sans compte ni serveur. Les tâches et réglages sont enregistrés dans une base SQLite sur cet appareil et restent disponibles après la fermeture de l’application.',
          ),
          const SizedBox(height: 18),
          _GuideSection(
            title: 'Que signifie « Inbox » ?',
            body: 'C’est la boîte des tâches à planifier. Ajoutez-y une tâche dès qu’elle vous vient à l’esprit. Elle y reste tant que vous ne lancez pas le planificateur et ne validez pas un créneau.',
            icon: Icons.inbox_outlined,
          ),
          _GuideSection(
            title: 'Ce que Planify sait faire ici',
            body: 'Créer et modifier des tâches d’une durée de 15 minutes à 4 heures, ajouter un projet, une priorité et des notes, puis organiser les tâches de l’Inbox qui n’ont pas encore d’horaire. L’échéance d’une tâche planifiée est calculée automatiquement à partir de son début et de sa durée. Les tâches non verrouillées peuvent être déplacées à la main sur le calendrier sans changer leur durée. Vous pouvez prévisualiser, modifier, valider ou annuler le plan.',
            icon: Icons.check_circle_outline,
          ),
          _GuideSection(
            title: 'Ce qui n’est pas encore connecté',
            body: 'Pas de compte ni de synchronisation cloud. Les calendriers du téléphone, y compris Google lorsqu’il y est synchronisé, sont consultés en lecture seule. Des rappels locaux sont disponibles pour les tâches planifiées si l’autorisation système est accordée.',
            icon: Icons.cloud_off_outlined,
          ),
          _GuideSection(
            title: 'Pour en faire un SaaS',
            body: 'Il faudra ajouter un backend sécurisé pour les comptes et les données, synchroniser les tâches par utilisateur, puis intégrer les abonnements et le suivi des quotas. La planification doit rester déterministe côté produit.',
            icon: Icons.cloud_outlined,
          ),
          const SizedBox(height: 12),
          Text(
            'Les tâches restent sur cet appareil. La lecture du calendrier se fait via le système mobile.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideNotice extends StatelessWidget {
  const _GuideNotice({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(body, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
