import 'package:elcorazon_core/elcorazon_core.dart'
    show LocationAvailability, LocationRemede;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:elcora_dely/config/api_config.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/services/location_service.dart';
import 'package:elcora_dely/services/notification_service.dart';
import 'package:elcora_dely/services/realtime_tracking_service.dart';
import 'package:elcora_dely/screens/delivery/driver_profile_screen.dart';

/// Réglages du livreur.
///
/// ## Ce que cet écran n'est plus
///
/// Il portait sept réglages — notifications, son, vibration, suivi GPS,
/// acceptation automatique, langue, thème — écrits dans `SharedPreferences`
/// par un bouton « Sauvegarder les paramètres », et **relus par personne**.
/// Aucun n'avait le moindre effet : couper « Suivi GPS » n'arrêtait pas le
/// suivi, activer « Accepter automatiquement » n'acceptait rien, changer la
/// langue ne changeait pas la langue, et « Sombre » ne donnait pas de thème
/// sombre — l'application n'en déclare pas.
///
/// Un interrupteur qui ne fait rien est pire qu'un interrupteur absent : le
/// livreur qui coupe « Suivi GPS » croit avoir cessé d'être suivi. Ils ont
/// donc été retirés plutôt que déguisés.
///
/// ## Ce qu'il montre à la place
///
/// L'état réel de ce dont dépend son travail — position et notifications —
/// et le chemin pour le corriger quand il est mauvais. Ces deux
/// autorisations-là appartiennent au système d'exploitation ; l'application
/// ne peut que les demander et dire où elles en sont.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Ce qui empêche de relever la position, ou [LocationAvailability.disponible].
  ///
  /// Cet écran lisait `Geolocator` directement — activation d'un côté,
  /// permission de l'autre — et recomposait lui-même les quatre cas, avec ses
  /// propres libellés. Ce sont les mêmes quatre cas que l'application cliente
  /// affiche, et ils divergeaient déjà : la cause et la phrase viennent
  /// maintenant du socle (`LocationAvailability`), le geste qui débloque aussi.
  LocationAvailability? _localisation;

  final LocationService _position = LocationService();

  @override
  void initState() {
    super.initState();
    _relireEtatLocalisation();
  }

  Future<void> _relireEtatLocalisation() async {
    final etat = await _position.disponibilite();
    if (!mounted) return;
    setState(() => _localisation = etat);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _relireEtatLocalisation,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProfileSection(),
            const SizedBox(height: 24),
            _buildLocationSection(),
            const SizedBox(height: 24),
            _buildNotificationsSection(),
            const SizedBox(height: 24),
            _buildAboutSection(),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- profil

  Widget _buildProfileSection() {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        final user = appService.currentUser;
        final nom = user?.fullName ?? 'Livreur';
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                nom.length >= 2 ? nom.substring(0, 2).toUpperCase() : 'LI',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              nom,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            // Plus de `driver@fasteat.ci` en repli : une adresse inventée,
            // d'une marque qui n'est pas la nôtre, affichée comme si c'était
            // celle du livreur.
            subtitle: Text(user?.email ?? 'Session non chargée'),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editProfile,
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------- localisation

  Widget _buildLocationSection() {
    return Consumer<RealtimeTrackingService>(
      builder: (context, tracking, child) {
        final obstacle = tracking.trackingUnavailableReason;
        final suit = tracking.isTrackingLocation && obstacle == null;
        final etat = _localisation;

        return _section(
          'Position',
          [
            _statutTuile(
              actif: suit,
              titre: suit ? 'Votre position est partagée' : 'Suivi en veille',
              detail: suit
                  ? 'Pendant vos courses, pour que le client suive sa '
                      "livraison. Rien n'est relevé entre deux courses."
                  : obstacle ??
                      // Le libellé disait « le suivi démarre à la connexion » :
                      // c'était vrai, et c'était le défaut. Le GPS tournait de
                      // la connexion à la déconnexion, y compris pendant les
                      // heures d'attente. Il s'allume désormais avec la course.
                      "Il démarre quand vous acceptez une course, et s'arrête "
                      'à la livraison.',
            ),
            if (etat != null && !etat.estDisponible)
              ListTile(
                leading: Icon(_iconeDe(etat), color: _couleurDe(etat)),
                title: Text(etat.titre),
                subtitle: Text(etat.consigne),
                trailing: etat.remede.libelle.isEmpty
                    ? null
                    : const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: etat.remede.libelle.isEmpty
                    ? null
                    : () async {
                        await _position.appliquerRemede(etat.remede);
                        // Relit au retour : le livreur revient peut-être des
                        // réglages avec le GPS rallumé, et cette tuile doit
                        // disparaître sans qu'il ait à rouvrir l'écran.
                        await _relireEtatLocalisation();
                      },
              ),
          ],
        );
      },
    );
  }

  static IconData _iconeDe(LocationAvailability etat) => switch (etat) {
        LocationAvailability.serviceDesactive => Icons.location_disabled,
        LocationAvailability.permissionRefuseeDefinitivement => Icons.block,
        LocationAvailability.permissionRefusee => Icons.location_searching,
        _ => Icons.gps_not_fixed,
      };

  static Color _couleurDe(LocationAvailability etat) => switch (etat) {
        LocationAvailability.serviceDesactive ||
        LocationAvailability.permissionRefuseeDefinitivement =>
          Colors.red,
        _ => Colors.orange,
      };

  // ---------------------------------------------------------- notifications

  Widget _buildNotificationsSection() {
    return Consumer<NotificationService>(
      builder: (context, notifications, child) {
        final autorisees = notifications.isAuthorized;

        return _section(
          'Notifications',
          [
            _statutTuile(
              actif: autorisees,
              titre: autorisees
                  ? 'Les courses proposées vous sont notifiées'
                  : 'Notifications refusées',
              detail: autorisees
                  // Le son et la vibration se règlent par canal, dans les
                  // réglages du système : deux interrupteurs les proposaient
                  // ici sans qu'aucun code ne les lise.
                  ? 'Son et vibration se règlent dans les réglages du '
                      'téléphone, canal « Courses proposées ».'
                  : 'Sans elles, une course proposée ne vous parviendra que '
                      'si l\'application est ouverte.',
            ),
            if (!autorisees)
              ListTile(
                leading:
                    const Icon(Icons.notifications_off, color: Colors.orange),
                title: const Text('Activer les notifications'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                // Ouvre la fiche de l'application : c'est là que se
                // rouvrent des notifications refusées définitivement, comme
                // pour la position. Le geste passe par le service plutôt
                // que par un appel direct au greffon de géolocalisation,
                // dont ce n'était le rôle que par coïncidence d'API.
                onTap: () => _position.appliquerRemede(
                  LocationRemede.ouvrirLaFicheDeLApplication,
                ),
              ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------- à propos

  Widget _buildAboutSection() {
    return _section(
      'À propos',
      [
        const ListTile(
          title: Text('Version'),
          subtitle: Text('1.0.0'),
        ),
        ListTile(
          title: const Text('Politique de confidentialité'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _showPrivacyPolicy,
        ),
        ListTile(
          title: const Text('Conditions d\'utilisation'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _showTermsOfService,
        ),
        // N'apparaît que si une adresse est configurée : une entrée de
        // contact qui n'ouvre rien vaut moins que pas d'entrée du tout.
        if (ApiConfig.supportEmail.isNotEmpty)
          ListTile(
            title: const Text('Contacter El Corazón'),
            subtitle: Text(ApiConfig.supportEmail),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _contactSupport,
          ),
      ],
    );
  }

  // ------------------------------------------------------------- fabriques

  Widget _section(String titre, List<Widget> enfants) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              titre,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ...enfants,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Un état, pas un interrupteur : ce que l'application constate, et non ce
  /// qu'elle prétend commander.
  Widget _statutTuile({
    required bool actif,
    required String titre,
    required String detail,
  }) {
    final couleur = actif ? Colors.green : Colors.orange;
    return ListTile(
      leading: Icon(
        actif ? Icons.check_circle : Icons.warning_amber_rounded,
        color: couleur,
      ),
      title: Text(titre, style: TextStyle(color: couleur)),
      subtitle: Text(detail),
      isThreeLine: true,
    );
  }

  // ---------------------------------------------------------------- gestes

  void _editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DriverProfileScreen()),
    );
  }

  /// Ouvre le courrier vers l'adresse de support **configurée**.
  ///
  /// ## Ce qui a remplacé quoi
  ///
  /// Trois entrées occupaient cette place : « Appeler le support », sous un
  /// numéro ivoirien inventé (`+225 01 02 03 04 05`) dans une application dont
  /// toute la géographie est togolaise ; « Envoyer un email », vers
  /// `support@elcorazon.ci` ; et « Chat en direct — disponible 8 h - 22 h ».
  /// Aucune des trois n'ouvrait quoi que ce soit : elles affichaient « Appel
  /// en cours… », « Ouverture de l'application mail… », « Chat de support
  /// indisponible », et c'était tout.
  ///
  /// L'adresse n'est pas écrite ici mais lue dans `.env` : il n'existe aucune
  /// coordonnée de support réelle dans ce dépôt, et en inventer une serait
  /// recommencer le défaut qu'on corrige. Tant qu'elle n'est pas renseignée,
  /// l'entrée ne s'affiche pas.
  Future<void> _contactSupport() async {
    final adresse = ApiConfig.supportEmail;
    if (adresse.isEmpty) return;

    final uri = Uri(
      scheme: 'mailto',
      path: adresse,
      queryParameters: {
        'subject': 'Application livreur — demande d\'assistance',
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Aucune application de messagerie : écrivez à $adresse'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showPrivacyPolicy() {
    _showTexte(
      'Politique de confidentialité',
      '''
Dernière mise à jour : 06 décembre 2025

1. Données collectées
Dans le cadre de vos livraisons, l'application collecte :
- votre identité et vos coordonnées (nom, adresse e-mail, téléphone) ;
- les pièces justificatives de votre dossier (identité, permis, véhicule) ;
- votre position, pendant vos courses uniquement.

2. Suivi de position
Votre position est relevée et transmise tant qu'une course vous est
attribuée, afin que le client suive sa livraison. Elle n'est pas relevée
entre deux courses. Une notification visible sur votre téléphone signale
chaque période de suivi.

3. Partage
Le client dont vous portez la commande voit votre prénom, votre type de
véhicule, votre note et votre position pendant sa livraison — rien après.
Vos pièces justificatives ne sont accessibles qu'au personnel chargé de la
validation des dossiers.

4. Vos droits
Vous pouvez consulter et corriger votre nom et votre téléphone depuis votre
profil, et demander l'accès, la rectification ou l'effacement de vos données
auprès d'El Corazón.
      ''',
    );
  }

  void _showTermsOfService() {
    _showTexte(
      'Conditions d\'utilisation',
      '''
Dernière mise à jour : 06 décembre 2025

1. Objet
Cette application est réservée aux livreurs d'El Corazón. Elle vous permet de
recevoir les courses qui vous sont proposées, de les faire avancer, et de
suivre vos gains.

2. Courses
Une course vous est proposée nommément ; vous êtes libre de l'accepter ou de
la refuser. Une course acceptée par un autre livreur ne vous est plus
proposée.

3. Encaissement
Sur une commande réglée en espèces, vous encaissez le montant indiqué à la
remise. Vous ne manipulez aucune donnée bancaire : les autres règlements sont
faits par le client depuis son application.

4. Gains
Votre rémunération est arrêtée par El Corazón à l'acceptation de chaque
course, et ne change pas ensuite. Une demande de retrait débite votre solde
et ouvre une intention de versement, exécutée par El Corazón.

5. Position
L'exercice de vos courses suppose que le partage de position soit actif. Sans
lui, le client ne peut pas suivre sa livraison.
      ''',
    );
  }

  void _showTexte(String titre, String corps) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titre),
        content: SingleChildScrollView(child: Text(corps)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
