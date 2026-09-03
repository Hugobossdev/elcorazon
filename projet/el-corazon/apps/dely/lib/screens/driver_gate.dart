import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcora_dely/presentation/etat_compte.dart';
import 'package:elcora_dely/screens/auth/account_status_screen.dart';
import 'package:elcora_dely/screens/auth/driver_auth_screen.dart';
import 'package:elcora_dely/screens/auth/verification_screen.dart';
import 'package:elcora_dely/screens/delivery/delivery_navigation_screen.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/widgets/incoming_call_handler.dart';
import 'package:elcora_dely/widgets/notification_router.dart';

/// La porte de l'application — **le seul endroit** qui décide ce qu'un livreur
/// peut atteindre.
///
/// ## Pourquoi une porte plutôt que des redirections
///
/// Le contrôle était jusqu'ici réparti : l'écran de démarrage regardait la
/// session pour choisir sa destination, et l'écran de connexion poussait
/// `/delivery-home` après un succès. Deux endroits, donc deux occasions
/// d'oublier un cas — et surtout, une fois la route poussée, plus rien ne
/// surveillait : un compte désactivé pendant la tournée gardait son écran
/// d'accueil jusqu'à la première requête refusée.
///
/// Ici la décision est **continue**. [AppService] est un `ChangeNotifier` que
/// la session alimente ; toute variation — connexion, déconnexion,
/// vérification, dossier suspendu relu — reconstruit cette porte et remplace
/// l'écran. Il n'existe aucune route qui contourne : `/delivery-home` mène ici,
/// et l'écran d'accueil n'est jamais poussé directement.
///
/// ## Ce que la porte ne remplace pas
///
/// Rien de tout cela n'est une garantie de sécurité — un client mobile ne
/// s'auto-protège pas. Les vraies gardes sont côté serveur : `IsCourier` sur
/// chaque route, et `can_accept_orders` (L1) qui refuse une course à un dossier
/// non validé. Cette porte évite d'afficher au livreur un écran qui ne peut que
/// lui répondre par un refus.
class DriverGate extends StatelessWidget {
  const DriverGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppService>();
    final compte = app.currentUser;

    if (compte == null) {
      return const DriverAuthScreen();
    }

    final etat = app.etatCompte ?? EtatCompte.actif;

    // Le sonneur enveloppe **tout ce qui suit une session ouverte**, y compris
    // les murs. Un livreur qu'on vient de suspendre peut recevoir l'appel du
    // client dont il tient encore la commande, et le laisser sonner dans le
    // vide serait pire que la suspension elle-même. Il n'enveloppe pas l'écran
    // de connexion : sans session, il n'y a pas de file personnelle à écouter.
    // Deux guets, même raison d'être et même emplacement : ils doivent voir
    // arriver un appel ou une notification quel que soit l'écran ouvert, et
    // ils n'existent que sous une session — sans elle, il n'y a ni file
    // personnelle à écouter ni course à ouvrir.
    return IncomingCallHandler(
      child: NotificationRouter(child: _pourLEtat(etat, compte.email)),
    );
  }

  Widget _pourLEtat(EtatCompte etat, String email) {
    return switch (etat) {
      // L'adresse n'est pas prouvée : la seule chose à faire est de saisir le
      // code. Pas de bouton « modifier l'adresse » — le compte existe, et la
      // changer est une opération que le serveur n'expose pas sans session
      // valide.
      EtatCompte.verificationRequise => VerificationScreen(email: email),

      EtatCompte.suspendu ||
      EtatCompte.refuse ||
      EtatCompte.bloque => AccountStatusScreen(etat: etat),

      // Dossier en attente : on entre. Le bandeau de
      // `DeliveryNavigationScreen` rappelle où en est l'instruction, et le
      // serveur refuse les courses de son côté.
      EtatCompte.enAttente || EtatCompte.actif => const DeliveryNavigationScreen(),
    };
  }
}
