import 'package:admin/presentation/champ_client_commande.dart';
import 'package:admin/presentation/filtres_supervision.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Deux questions que la supervision ne savait pas poser, alors que le serveur
/// y répondait : « les commandes de la semaine dernière », et « celles de ce
/// client ».
///
/// `jusqua` rendait toujours `null`, si bien qu'une période n'avait jamais de
/// fin ; et `customer`, que `/orders/manage/` filtre depuis l'origine, n'était
/// jamais envoyé.
void main() {
  group('Une période choisie', () {
    final filtres = const FiltresCommandes().copyWith(
      fenetre: FenetreCommandes.periode,
      du: DateTime(2026, 9, 1, 15, 30),
      au: DateTime(2026, 9, 7, 8),
    );

    test('commence à minuit du premier jour', () {
      expect(filtres.depuis, DateTime(2026, 9));
    });

    test('finit à la dernière milliseconde du dernier jour', () {
      // Borner à minuit du 7 exclurait toute la journée du 7 — celle qu'on
      // vient pourtant de cocher au calendrier.
      expect(filtres.jusqua, DateTime(2026, 9, 7, 23, 59, 59, 999));
    });

    test('se nomme par ses dates', () {
      expect(filtres.libellePeriode, 'du 01/09/2026 au 07/09/2026');
    });

    test('une journée seule se dit « le … »', () {
      final jour = const FiltresCommandes().copyWith(
        fenetre: FenetreCommandes.periode,
        du: DateTime(2026, 9, 3),
        au: DateTime(2026, 9, 3),
      );

      expect(jour.libellePeriode, 'le 03/09/2026');
    });

    test('perd ses dates quand on revient à une fenêtre glissante', () {
      final glissante = filtres.copyWith(fenetre: FenetreCommandes.septJours);

      expect(glissante.du, isNull);
      expect(glissante.au, isNull);
      expect(glissante.jusqua, isNull);
    });

    test('changer de dates relance la requête', () {
      final autre = filtres.copyWith(au: DateTime(2026, 9, 8));

      expect(filtres.memeRequeteQue(autre), isFalse);
    });

    test('une fenêtre glissante n’a pas de borne haute', () {
      // « 7 derniers jours » va jusqu'à maintenant — et au-delà, pour une
      // commande qui arrive pendant qu'on regarde.
      expect(const FiltresCommandes(fenetre: FenetreCommandes.septJours).jusqua, isNull);
    });

    test('les bornes ignorées hors période ne comptent pas', () {
      // Des dates résiduelles construites à la main n'ont pas d'effet tant que
      // la fenêtre n'est pas une période.
      final residuelles = FiltresCommandes(du: DateTime(2020), au: DateTime(2020, 2));

      expect(residuelles.depuis, isNot(DateTime(2020)));
      expect(residuelles.jusqua, isNull);
    });
  });

  group('Un client retenu', () {
    const filtres = FiltresCommandes(clientId: 'client-1', clientNom: 'Ama K.');

    test('compte parmi les filtres posés', () {
      expect(filtres.actifs, isTrue);
      expect(filtres.nombreActifs, 1);
    });

    test('change la requête', () {
      expect(filtres.memeRequeteQue(const FiltresCommandes()), isFalse);
    });

    test('se retire, nom compris', () {
      final sans = filtres.copyWith(effacerClient: true);

      expect(sans.clientId, isNull);
      expect(sans.clientNom, isNull);
      expect(sans.actifs, isFalse);
    });

    test('survit à un changement de période', () {
      final maj = filtres.copyWith(fenetre: FenetreCommandes.aujourdHui);

      expect(maj.clientId, 'client-1');
    });
  });

  group('Trouver le client', () {
    eccore.Customer client(String id, String nom, String email, {String? telephone}) =>
        eccore.Customer(
          id: id,
          email: email,
          fullName: nom,
          phone: telephone,
          isActive: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    final clients = [
      client('1', 'Éloïse Mensah', 'eloise@example.com', telephone: '+228 90 11 22 33'),
      client('2', 'Kofi Agbo', 'kofi@example.com'),
    ];

    test('sans égard aux accents ni à la casse', () {
      expect(clientsCorrespondants(clients, 'eloise').single.id, '1');
      expect(clientsCorrespondants(clients, 'MENSAH').single.id, '1');
    });

    test('par téléphone, espaces ignorés', () {
      expect(clientsCorrespondants(clients, '90112233').single.id, '1');
    });

    test('par adresse électronique', () {
      expect(clientsCorrespondants(clients, 'kofi@').single.id, '2');
    });

    test('une saisie vide ne propose rien', () {
      // Proposer toute la clientèle sous un champ vide, c'est une liste
      // qu'on ne lit pas.
      expect(clientsCorrespondants(clients, '   '), isEmpty);
    });

    test('la liste proposée est plafonnée', () {
      final nombreux = [
        for (var i = 0; i < 30; i++) client('$i', 'Ama $i', 'ama$i@example.com'),
      ];

      expect(clientsCorrespondants(nombreux, 'ama'), hasLength(8));
    });
  });
}
