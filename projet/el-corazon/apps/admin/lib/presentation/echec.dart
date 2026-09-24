import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/messages_erreur.dart';

/// Ce qui a fait échouer un appel, **classé** — pas seulement raconté.
///
/// ## Pourquoi une classification
///
/// Le back-office disait tous ses échecs de la même façon : une chaîne dans
/// `_error`, souvent jamais affichée. Trois conséquences relevées le
/// 21 septembre 2026 :
///
/// * un 403 sur la liste des établissements devenait « Aucun établissement
///   rattaché » — un refus d'autorisation lu comme une absence de données ;
/// * un bouton « Réessayer » s'offrait devant un refus que réessayer ne
///   changera jamais ;
/// * une session expirée se lisait comme une panne.
///
/// La nature décide du geste attendu : corriger la saisie, demander un droit,
/// réessayer, se reconnecter. Le message reste celui du serveur
/// ([messageErreur]), qui nomme précisément ce qui bloque.
enum NatureEchec {
  /// 400 — la saisie est refusée ; le détail est champ par champ.
  validation,

  /// 403 — le compte n'a pas le droit ; réessayer n'y changera rien.
  autorisation,

  /// 404 — l'élément n'existe pas, ou pas dans le périmètre du compte.
  introuvable,

  /// 409 — une règle métier s'y oppose (transition impossible, doublon…).
  conflit,

  /// 401 ou rafraîchissement impossible — il faut se reconnecter.
  session,

  /// Aucun octet reçu du serveur.
  reseau,

  /// 5xx — le serveur a échoué ; réessayer a du sens.
  serveur,

  /// Tout le reste (429, réponse illisible, exception inattendue).
  inconnue;

  static NatureEchec de(Object erreur) {
    if (erreur is eccore.SessionExpiredException) return session;
    if (erreur is! eccore.ApiException) return inconnue;
    if (erreur.isNetworkError) return reseau;
    if (erreur.isUnauthorized) return session;
    if (erreur.isForbidden) return autorisation;
    if (erreur.status == 404) return introuvable;
    if (erreur.status == 409) return conflit;
    if (erreur.status == 400 || erreur.status == 422) return validation;
    if (erreur.isServerError) return serveur;
    return inconnue;
  }

  /// Réessayer le même geste peut-il aboutir ?
  bool get reessayable => this == reseau || this == serveur || this == inconnue;

  String get titre => switch (this) {
        validation => 'Saisie refusée',
        autorisation => 'Accès refusé',
        introuvable => 'Introuvable',
        conflit => 'Action impossible',
        session => 'Session expirée',
        reseau => 'Pas de connexion',
        serveur => 'Erreur du serveur',
        inconnue => 'Échec',
      };

  IconData get icone => switch (this) {
        validation => Icons.edit_note_rounded,
        autorisation => Icons.lock_outline_rounded,
        introuvable => Icons.search_off_rounded,
        conflit => Icons.block_rounded,
        session => Icons.logout_rounded,
        reseau => Icons.cloud_off_rounded,
        serveur => Icons.dns_rounded,
        inconnue => Icons.error_outline_rounded,
      };
}

/// Un échec prêt à afficher : sa nature, la phrase du serveur, et les erreurs
/// de champ quand il y en a (400).
@immutable
class Echec {
  const Echec({required this.nature, required this.message, this.champs = const {}});

  factory Echec.de(Object erreur) => Echec(
        nature: NatureEchec.de(erreur),
        message: messageErreur(erreur),
        champs: erreur is eccore.ApiException ? erreur.errors : const {},
      );

  final NatureEchec nature;
  final String message;

  /// Erreurs par champ, clés du serveur (`points_cost`, `starts_at`…).
  final Map<String, List<String>> champs;

  /// La première erreur du serveur pour ce champ, à poser sous le champ du
  /// formulaire (`InputDecoration.errorText`).
  String? pourLeChamp(String champ) {
    final messages = champs[champ];
    return messages == null || messages.isEmpty ? null : messages.join(' ');
  }

  @override
  String toString() => 'Echec(${nature.name}, $message)';
}

/// Bandeau d'échec réutilisable : titre selon la nature, phrase du serveur,
/// et « Réessayer » **seulement** quand réessayer peut aboutir.
class BandeauEchec extends StatelessWidget {
  const BandeauEchec({required this.echec, this.onReessayer, super.key});

  final Echec echec;
  final VoidCallback? onReessayer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(echec.nature.icone, color: scheme.onErrorContainer, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${echec.nature.titre} — ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: echec.message),
                  ],
                ),
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            if (onReessayer != null && echec.nature.reessayable)
              TextButton(onPressed: onReessayer, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
