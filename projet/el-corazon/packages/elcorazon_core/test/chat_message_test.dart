import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// La charge utile d'un message de conversation.
///
/// Trois champs seulement voyagent sur `ws/orders/{id}/chat/`. Le modèle local
/// que ceci remplace en déclarait dix, plus deux classes — `ChatUser`,
/// `ChatRoom` — qu'aucun fichier n'utilisait.
void main() {
  final recuLe = DateTime(2026, 8, 8, 12, 30);

  group('Une charge utile complète', () {
    final message = ChatMessage.fromPayload({
      'sender': 'courier',
      'text': 'Je suis en bas',
      'sent_at': '2026-08-08T12:29:00Z',
    });

    test('porte le rôle de l’émetteur, pas son identité', () {
      // Le serveur le prend sur la connexion authentifiée : personne ne peut
      // écrire au nom d'un autre.
      expect(message.sender, 'courier');
    });

    test('porte le texte et l’heure du serveur', () {
      expect(message.text, 'Je suis en bas');
      expect(message.sentAt, DateTime.parse('2026-08-08T12:29:00Z'));
    });
  });

  group('Une charge utile incomplète', () {
    test('sans horodatage, l’heure de réception fait foi', () {
      final message = ChatMessage.fromPayload(
        {'sender': 'client', 'text': 'Merci'},
        recuLe: recuLe,
      );

      expect(message.sentAt, recuLe);
    });

    test('un horodatage illisible ne fait pas tomber la conversation', () {
      final message = ChatMessage.fromPayload(
        {'sender': 'client', 'text': 'Merci', 'sent_at': 'tout de suite'},
        recuLe: recuLe,
      );

      expect(message.sentAt, recuLe);
    });

    test('un message vide reste un message', () {
      // Une bulle vide se voit ; une exception dans un flux se perd.
      final message = ChatMessage.fromPayload(const {}, recuLe: recuLe);

      expect(message.sender, isEmpty);
      expect(message.text, isEmpty);
      expect(message.sentAt, recuLe);
    });
  });
}
