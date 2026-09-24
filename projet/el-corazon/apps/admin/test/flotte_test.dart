import 'package:admin/presentation/flotte.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Les listes de l'écran des livreurs.
///
/// ## Les défauts que cette suite ferme
///
/// * La recherche, le filtre et le tri écrivaient dans une liste que rien ne
///   lisait : taper un nom ne changeait rien.
/// * Les onglets ne gardaient que les dossiers validés : un livreur suspendu
///   n'apparaissait nulle part, et sa suspension ne pouvait plus être levée.
/// * Le classement triait sur la seule moyenne : un livreur jamais noté
///   (moyenne 0) et un dossier suspendu y figuraient.
eccore.CourierProfile _livreur(
  String nom, {
  String statut = 'approved',
  bool enLigne = false,
  bool peutRecevoir = false,
  String telephone = '+22890000000',
  String plaque = '',
  double note = 0,
  int avis = 0,
  int courses = 0,
}) =>
    eccore.CourierProfile.fromJson({
      'id': nom.toLowerCase().replaceAll(' ', '-'),
      'full_name': nom,
      'email': '${nom.toLowerCase().replaceAll(' ', '.')}@elcorazon.test',
      'phone': telephone,
      'restaurant': 'el-corazon-lome',
      'verification_status': statut,
      'id_document': null,
      'licence_document': null,
      'vehicle_document': null,
      'verification_notes': '',
      'verified_at': null,
      'vehicle_type': 'motorcycle',
      'vehicle_plate': plaque,
      'is_online': enLigne,
      'can_accept_orders': peutRecevoir,
      'last_location': null,
      'last_location_at': null,
      'deliveries_completed': courses,
      'deliveries_cancelled': 0,
      'rating_average': note.toString(),
      'rating_count': avis,
      'total_earnings': null,
      'created_at': '2026-09-01T10:00:00Z',
      'updated_at': '2026-09-20T10:00:00Z',
    });

List<String> _noms(List<eccore.CourierProfile> livreurs) =>
    [for (final l in livreurs) l.fullName];

void main() {
  final disponible = _livreur('Ama Disponible', enLigne: true, peutRecevoir: true);
  final horsLigne = _livreur('Kofi Hors Ligne', plaque: 'TG-4521-AB');
  final suspendu = _livreur('Yao Suspendu', statut: 'suspended', note: 4.9, avis: 40);
  final refuse = _livreur('Esi Refuse', statut: 'rejected');
  final compteInactif = _livreur('Kwame Inactif', enLigne: true);
  final enAttente = _livreur('Afi Attente', statut: 'pending');
  final flotte = [disponible, horsLigne, suspendu, refuse, compteInactif, enAttente];

  group('onglets', () {
    test('chaque livreur hors attente apparaît dans un onglet de service', () {
      final vus = {
        for (final onglet in [
          OngletFlotte.disponibles,
          OngletFlotte.horsLigne,
          OngletFlotte.horsService,
        ])
          ...livreursDeLOnglet(flotte, onglet),
      };
      expect(vus, containsAll([disponible, horsLigne, suspendu, refuse, compteInactif]));
    });

    test('suspendus, refusés et comptes inactifs sont « hors service »', () {
      expect(
        _noms(livreursDeLOnglet(flotte, OngletFlotte.horsService)),
        ['Esi Refuse', 'Kwame Inactif', 'Yao Suspendu'],
      );
      expect(suspendu.motifHorsService, 'Suspendu');
      expect(refuse.motifHorsService, 'Dossier refusé');
      expect(compteInactif.motifHorsService, 'Compte inactif');
    });

    test('un dossier en attente reste au centre de validation', () {
      for (final onglet in OngletFlotte.values) {
        expect(livreursDeLOnglet(flotte, onglet), isNot(contains(enAttente)));
      }
    });

    test('un suspendu n’est ni « hors ligne » ni au classement', () {
      expect(livreursDeLOnglet(flotte, OngletFlotte.horsLigne), [horsLigne]);
      expect(livreursDeLOnglet(flotte, OngletFlotte.classement), isNot(contains(suspendu)));
    });
  });

  group('recherche', () {
    test('filtre la liste de l’onglet', () {
      expect(
        livreursDeLOnglet(flotte, OngletFlotte.horsService, recherche: 'yao'),
        [suspendu],
      );
    });

    test('trouve par plaque et par téléphone, espaces ignorés', () {
      final autre = _livreur('Sena Autre', telephone: '+228 91 11 22 33');
      final liste = [horsLigne, autre];
      expect(livreursDeLOnglet(liste, OngletFlotte.horsLigne, recherche: 'tg-4521'), [horsLigne]);
      expect(livreursDeLOnglet(liste, OngletFlotte.horsLigne, recherche: '91112233'), [autre]);
    });

    test('une recherche vide ou blanche ne filtre rien', () {
      expect(livreursDeLOnglet(flotte, OngletFlotte.horsService, recherche: '   '), hasLength(3));
    });
  });

  group('tri', () {
    final liste = [
      _livreur('Bruno', courses: 5, note: 4.0, avis: 3),
      _livreur('adjo', courses: 50, note: 4.5, avis: 10),
      _livreur('Célia', courses: 20),
    ];

    test('par nom, sans tenir compte de la casse', () {
      expect(
        _noms(livreursDeLOnglet(liste, OngletFlotte.horsLigne)),
        ['adjo', 'Bruno', 'Célia'],
      );
      expect(
        _noms(livreursDeLOnglet(liste, OngletFlotte.horsLigne, tri: TriFlotte.nomDecroissant)),
        ['Célia', 'Bruno', 'adjo'],
      );
    });

    test('par livraisons', () {
      expect(
        _noms(livreursDeLOnglet(liste, OngletFlotte.horsLigne, tri: TriFlotte.livraisons)),
        ['adjo', 'Célia', 'Bruno'],
      );
    });

    test('ne réordonne pas la flotte passée', () {
      final avant = _noms(liste);
      livreursDeLOnglet(liste, OngletFlotte.horsLigne, tri: TriFlotte.livraisons);
      expect(_noms(liste), avant);
    });
  });

  group('classement', () {
    test('les notés d’abord, puis la note, puis l’expérience', () {
      final liste = [
        _livreur('Jamais Noté', courses: 300),
        _livreur('Moyen', note: 3.5, avis: 12, courses: 40),
        _livreur('Excellent Ancien', note: 4.8, avis: 90, courses: 400),
        _livreur('Excellent Nouveau', note: 4.8, avis: 4, courses: 10),
      ];
      expect(
        _noms(livreursDeLOnglet(liste, OngletFlotte.classement)),
        ['Excellent Ancien', 'Excellent Nouveau', 'Moyen', 'Jamais Noté'],
      );
    });

    test('garde son ordre quel que soit le tri choisi', () {
      final liste = [
        _livreur('Zoé', note: 5, avis: 2),
        _livreur('Abla', note: 3, avis: 2),
      ];
      expect(
        _noms(livreursDeLOnglet(liste, OngletFlotte.classement, tri: TriFlotte.livraisons)),
        ['Zoé', 'Abla'],
      );
    });
  });
}
