import 'package:elcora_dely/services/realtime_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le suivi GPS suit la **course**, plus la session.
///
/// ## Ce que ces tests protègent
///
/// Le flux de position s'ouvrait à la connexion et se fermait à la déconnexion.
/// Un livreur qui ouvrait son application le matin et attendait sa première
/// course consommait donc autant de batterie qu'en pleine tournée — pour des
/// relevés que le serveur n'a nulle part où écrire : un relevé appartient à une
/// course (invariant L3), et sans course active `updateDeliveryLocation`
/// rendait la main sans rien envoyer.
///
/// Deux autres conséquences, moins visibles et plus graves :
///
/// * `Info.plist` annonce au livreur que sa position « n'est pas relevée entre
///   deux courses ». Le code relevait. Une déclaration de confidentialité qui
///   ne décrit pas le code est un motif de rejet App Store — et surtout, ce
///   n'est pas vrai.
/// * Le service de premier plan Android affichait « Course en cours » à un
///   livreur qui n'en avait aucune.
///
/// Ces tests ne montent pas de capteur : ils portent sur la **porte**, c'est-à-
/// dire sur la décision d'ouvrir ou non le flux. Le flux lui-même appartient à
/// `geolocator` et ne s'ouvre de toute façon jamais hors session — ce que le
/// premier test vérifie.
void main() {
  // Le service s'inscrit comme observateur du cycle de vie (`WidgetsBinding`)
  // pour relire l'obstacle au retour au premier plan : sans liaison de test,
  // `stopCourierSession` lève avant d'avoir rien fermé.
  TestWidgetsFlutterBinding.ensureInitialized();

  late RealtimeTrackingService suivi;

  setUp(() {
    // Singleton : chaque test repart de l'état fermé, sans quoi le précédent
    // laisserait sa porte ouverte à celui qui suit.
    suivi = RealtimeTrackingService();
  });

  tearDown(() async {
    await suivi.suivreLaCourse(enCours: false);
  });

  group('Porte du suivi', () {
    test('aucune course ouverte : rien ne suit', () {
      expect(suivi.isTrackingLocation, isFalse);
    });

    test('une course annoncée hors session n’ouvre pas le flux', () {
      // La garde de dernier recours dans `_startPositionEmission` : sans
      // session de livreur ouverte, il n'y a personne au nom de qui émettre.
      // C'est aussi ce qui rend ces tests exécutables sans capteur.
      expect(
        () => suivi.suivreLaCourse(enCours: true),
        returnsNormally,
      );
      expect(suivi.isTrackingLocation, isFalse);
    });

    test('fermer la porte oublie la dernière position', () async {
      // Elle est oubliée délibérément : la garder ferait repartir le battement
      // sur un relevé vieux d'une course, et `currentPosition` annoncerait
      // « ici » un endroit que le livreur a quitté.
      await suivi.suivreLaCourse(enCours: false);
      expect(suivi.currentPosition, isNull);
      expect(suivi.trackingUnavailableReason, isNull);
    });

    test('la porte est idempotente', () async {
      // Elle est appelée à chaque évolution de la liste des courses, donc
      // souvent. Rouvrir le flux à chaque appel redemanderait une fixation au
      // capteur, ce qui coûte plusieurs secondes et de la batterie.
      var notifications = 0;
      void compter() => notifications++;
      suivi.addListener(compter);

      await suivi.suivreLaCourse(enCours: false);
      await suivi.suivreLaCourse(enCours: false);
      await suivi.suivreLaCourse(enCours: false);

      suivi.removeListener(compter);
      expect(notifications, 0, reason: 'aucun changement d’état à annoncer');
    });
  });

  group('Pas de suivi fantôme', () {
    test('une course refermée pendant l’attente ne rouvre pas le flux', () async {
      // Le scénario que la garde d'entrée seule ne couvrait pas :
      //
      //   1. le livreur accepte      -> `_startPositionEmission` démarre ;
      //   2. il attend la demande de permission du système, qui suspend ;
      //   3. la course se termine    -> `_arreterEmission` ne trouve aucun
      //      abonnement à couper, puisqu'il n'y en a pas encore ;
      //   4. la continuation reprend -> le flux s'ouvrait pour une course qui
      //      n'existe plus, et le GPS tournait jusqu'à la déconnexion sous une
      //      notification « Course en cours » qui ne correspondait à rien.
      //
      // La condition est désormais relue **après** l'attente. Ici, sans session
      // ouverte, elle est fausse des deux côtés — ce que ce test constate.
      final ouverture = suivi.suivreLaCourse(enCours: true);
      await suivi.suivreLaCourse(enCours: false);
      await ouverture;

      expect(suivi.isTrackingLocation, isFalse);
      expect(suivi.currentPosition, isNull);
    });

    test('fermer la session coupe tout et se laisse rejouer', () async {
      // Appelée à la déconnexion, et rappelée si le compte change deux fois de
      // suite : elle doit être sans effet la seconde fois plutôt que de lever.
      await suivi.stopCourierSession();
      await suivi.stopCourierSession();

      expect(suivi.isConnected, isFalse);
      expect(suivi.isTrackingLocation, isFalse);
      expect(suivi.currentPosition, isNull);
    });
  });

  group('Réglages de cadence', () {
    test('sans .env chargé, les valeurs par défaut s’appliquent', () {
      // `dotenv` n'est pas monté ici : le service doit alors tourner à sa
      // cadence nominale plutôt que de lever. Un livreur ne perd pas son suivi
      // parce qu'un fichier de configuration manque.
      expect(suivi.reglages.emissionInterval, const Duration(seconds: 10));
      expect(suivi.reglages.distanceFilterMeters, 25);
      expect(suivi.reglages.avertissement, isNull);
    });
  });
}
