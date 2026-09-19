import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/services/versements_service.dart';
import 'package:admin/ui/ui.dart';

/// Pièces partagées par « Retraits livreurs » et « Remboursements ».

/// Bandeau d'en-tête : ce que l'écran constate, et ce qu'il ne fait pas.
///
/// Dit une fois, en haut, parce que c'est la méprise à éviter : un opérateur
/// qui croirait que « Constater » déclenche le virement le cocherait avant de
/// l'avoir fait.
class AvertissementConstat extends StatelessWidget {
  const AvertissementConstat({required this.texte, super.key});

  final String texte;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.onSecondaryContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texte, style: TextStyle(color: scheme.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}

/// « À traiter » / « Tout l'historique », et le nombre de lignes du filtre.
class BarreDeFiltre extends StatelessWidget {
  const BarreDeFiltre({
    required this.filtre,
    required this.total,
    required this.onChanged,
    required this.onRecharger,
    this.resume,
    super.key,
  });

  final FiltreVersements filtre;
  final int total;
  final ValueChanged<FiltreVersements> onChanged;
  final VoidCallback onRecharger;

  /// Une ligne de synthèse — la somme à verser, par exemple.
  final String? resume;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final option in FiltreVersements.values)
            ChoiceChip(
              label: Text(option.libelle),
              selected: filtre == option,
              onSelected: (_) => onChanged(option),
            ),
          Text('$total ligne(s)'),
          if (resume != null)
            Text(resume!, style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            tooltip: 'Recharger',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: onRecharger,
          ),
        ],
      ),
    );
  }
}

/// Liste, chargement, erreur ou vide — les quatre états, chacun dit.
class EtatDeListe extends StatelessWidget {
  const EtatDeListe({
    required this.chargement,
    required this.erreur,
    required this.vide,
    required this.messageVide,
    required this.onReessayer,
    required this.liste,
    super.key,
  });

  final bool chargement;
  final String? erreur;
  final bool vide;
  final String messageVide;
  final VoidCallback onReessayer;
  final Widget liste;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (chargement && vide) return const Center(child: CircularProgressIndicator());
    if (erreur != null && vide) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(erreur!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onReessayer, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    if (vide) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(messageVide, textAlign: TextAlign.center, style: TextStyle(color: theme.hintColor)),
        ),
      );
    }
    return liste;
  }
}

/// Pastille de statut.
class PastilleStatut extends StatelessWidget {
  const PastilleStatut({required this.statut, super.key});

  final String statut;

  @override
  Widget build(BuildContext context) {
    final sem = AdminColorTokens.semantic(Theme.of(context).colorScheme);
    final couleur = switch (statut) {
      eccore.StatutVersement.verse => sem.success,
      eccore.StatutVersement.refuse => sem.danger,
      _ => sem.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        eccore.StatutVersement.libelle(statut),
        style: TextStyle(color: couleur, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

/// Un numéro qu'on recopie dans l'application du prestataire : un clic le
/// copie, plutôt que de le retaper chiffre à chiffre.
class NumeroCopiable extends StatelessWidget {
  const NumeroCopiable({required this.numero, super.key});

  final String numero;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: numero));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$numero copié')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(numero, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(width: 4),
            const Icon(Icons.copy_rounded, size: 14),
          ],
        ),
      ),
    );
  }
}

/// Demande un texte avant un geste — une référence, un motif.
///
/// Rend le texte saisi, ou `null` si l'on renonce. [obligatoire] refuse la
/// validation d'un champ vide *avant* l'envoi : le serveur le refuserait
/// aussi, mais après un aller-retour.
Future<String?> demanderTexte(
  BuildContext context, {
  required String titre,
  required String explication,
  required String libelle,
  required String action,
  bool obligatoire = true,
  bool destructif = false,
}) {
  final controleur = TextEditingController();
  final formulaire = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titre),
      content: SizedBox(
        width: 420,
        child: Form(
          key: formulaire,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(explication),
              const SizedBox(height: 12),
              TextFormField(
                controller: controleur,
                autofocus: true,
                decoration: InputDecoration(labelText: libelle, border: const OutlineInputBorder()),
                validator: (v) =>
                    obligatoire && (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          style: destructif
              ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error)
              : null,
          onPressed: () {
            if (formulaire.currentState?.validate() ?? false) {
              Navigator.of(context).pop(controleur.text.trim());
            }
          },
          child: Text(action),
        ),
      ],
    ),
  ).whenComplete(controleur.dispose);
}

String dateCourte(DateTime date) {
  final local = date.toLocal();
  String deux(int n) => n.toString().padLeft(2, '0');
  return '${deux(local.day)}/${deux(local.month)}/${local.year} ${deux(local.hour)}:${deux(local.minute)}';
}
