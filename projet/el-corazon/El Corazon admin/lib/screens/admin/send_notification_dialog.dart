import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/marketing_service.dart';

/// Envoi d'une notification de masse — une **campagne**, côté serveur.
///
/// L'ancienne version affichait « Notification envoyée » après avoir inséré une
/// ligne dans une liste en mémoire du navigateur. Personne ne recevait rien :
/// le service tenait trois notifications codées en dur et ajoutait la nouvelle
/// en tête. Le message était donc un mensonge d'interface, et rien à l'écran ne
/// permettait de s'en apercevoir.
///
/// Une campagne, elle, part vraiment : le serveur écrit une notification par
/// destinataire du segment — hors comptes ayant refusé le marketing — compte ce
/// qui a été écrit, et garde la trace de qui l'a envoyée. Elle ne part qu'une
/// fois, et son texte devient immuable.
class SendNotificationDialog extends StatefulWidget {
  const SendNotificationDialog({super.key});

  @override
  State<SendNotificationDialog> createState() => _SendNotificationDialogState();
}

class _SendNotificationDialogState extends State<SendNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String _segment = eccore.CampaignAudience.allCustomers;
  bool _envoiEnCours = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 600.0);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: dialogWidth,
          maxWidth: dialogWidth,
          maxHeight: screenSize.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Envoyer une notification',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Titre',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Le titre est requis'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Le message est requis'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _segment,
                        decoration: const InputDecoration(
                          labelText: 'Destinataires',
                          border: OutlineInputBorder(),
                        ),
                        // Liste fermée, celle du serveur : un ciblage libre
                        // serait une requête que personne n'a relue avant
                        // qu'elle ne parte à des milliers de gens.
                        items: [
                          for (final valeur in eccore.CampaignAudience.values)
                            DropdownMenuItem(
                              value: valeur,
                              child: Text(_libelle(valeur)),
                            ),
                        ],
                        onChanged: (valeur) => setState(() {
                          if (valeur != null) _segment = valeur;
                        }),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "L'envoi est définitif : le message ne pourra plus être "
                        "corrigé, et la campagne ne part qu'une fois. Les "
                        'comptes ayant refusé le marketing ne la recevront pas.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _envoiEnCours
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _envoiEnCours ? null : _send,
                    child: _envoiEnCours
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Envoyer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _envoiEnCours = true);
    final service = context.read<MarketingService>();
    final messager = ScaffoldMessenger.of(context);
    final navigateur = Navigator.of(context);

    // Deux temps, comme côté serveur : on rédige, puis on envoie. Si l'envoi
    // échoue, le brouillon reste — et c'est le comportement voulu : le texte
    // est conservé, l'envoi se relance depuis l'écran des campagnes.
    final brouillon = await service.createCampaign(
      title: _titleController.text.trim(),
      body: _messageController.text.trim(),
      audience: _segment,
    );

    final envoyee =
        brouillon != null && await service.sendCampaign(brouillon.id);

    if (!mounted) return;
    setState(() => _envoiEnCours = false);

    if (envoyee) navigateur.pop();
    messager.showSnackBar(
      SnackBar(
        content: Text(
          envoyee
              ? 'Campagne envoyée'
              : brouillon == null
              ? service.error ?? 'Rédaction refusée'
              : 'Brouillon conservé, envoi refusé : '
                    '${service.error ?? "raison inconnue"}',
        ),
      ),
    );
  }

  String _libelle(String valeur) {
    switch (valeur) {
      case eccore.CampaignAudience.allCustomers:
        return 'Tous les clients';
      case eccore.CampaignAudience.couriers:
        return 'Tous les livreurs';
      case eccore.CampaignAudience.activeCustomers:
        return 'Clients ayant commandé récemment';
      case eccore.CampaignAudience.lapsedCustomers:
        return 'Clients sans commande récente';
      default:
        return valeur;
    }
  }
}
