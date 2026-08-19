import 'dart:convert';

import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/services/places_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Places API (New) — traduction des réponses `places.googleapis.com/v1` vers
/// les modèles de l'application.
///
/// L'ancienne API (`maps.googleapis.com/maps/api/place/*`) n'est plus activable
/// sur les projets qui ne l'utilisaient pas : elle répond `REQUEST_DENIED`, et
/// l'écran n'affichait plus aucune suggestion. La forme des réponses change
/// entièrement — `predictions` devient `suggestions`, `geometry.location.lat`
/// devient `location.latitude` —, et c'est cette traduction que ces tests
/// tiennent.
void main() {
  group('Autocomplétion', () {
    test('une prédiction de lieu devient une suggestion', () {
      final data = json.decode('''
        {
          "suggestions": [
            {
              "placePrediction": {
                "place": "places/ChIJVQIrqQ4nCA8RJvNvY0Bs5Xw",
                "placeId": "ChIJVQIrqQ4nCA8RJvNvY0Bs5Xw",
                "text": {
                  "text": "Boulevard du 13 Janvier, Lomé, Togo",
                  "languageCode": "fr"
                },
                "structuredFormat": {
                  "mainText": {"text": "Boulevard du 13 Janvier"},
                  "secondaryText": {"text": "Lomé, Togo"}
                },
                "types": ["route"]
              }
            }
          ]
        }
      ''') as Map<String, dynamic>;

      final suggestions = PlacesService.suggestionsFromResponse(data);

      expect(suggestions, hasLength(1));
      expect(suggestions.single.placeId, 'ChIJVQIrqQ4nCA8RJvNvY0Bs5Xw');
      expect(suggestions.single.description, 'Boulevard du 13 Janvier, Lomé, Togo');
    });

    test('une prédiction de requête est écartée', () {
      // `queryPrediction` ne porte aucun `placeId` : demander son détail
      // échouerait, et la ligne serait intouchable dans la liste.
      final data = json.decode('''
        {
          "suggestions": [
            {"queryPrediction": {"text": {"text": "pizza à Lomé"}}},
            {
              "placePrediction": {
                "placeId": "ChIJ123",
                "text": {"text": "Rue du Commerce, Lomé, Togo"}
              }
            }
          ]
        }
      ''') as Map<String, dynamic>;

      final suggestions = PlacesService.suggestionsFromResponse(data);

      expect(suggestions.map((s) => s.placeId), ['ChIJ123']);
    });

    test('une réponse vide ne rend aucune suggestion', () {
      expect(PlacesService.suggestionsFromResponse(const {}), isEmpty);
      expect(
        PlacesService.suggestionsFromResponse(const {'suggestions': <dynamic>[]}),
        isEmpty,
      );
    });
  });

  group('Détail d’un lieu', () {
    Map<String, dynamic> reponseLome() => json.decode('''
      {
        "id": "ChIJVQIrqQ4nCA8RJvNvY0Bs5Xw",
        "formattedAddress": "Boulevard du 13 Janvier, Lomé, Togo",
        "location": {"latitude": 6.1319, "longitude": 1.2255},
        "addressComponents": [
          {"longText": "Boulevard du 13 Janvier", "shortText": "Bd du 13 Janvier", "types": ["route"]},
          {"longText": "Bè-Kpota", "shortText": "Bè-Kpota", "types": ["neighborhood", "political"]},
          {"longText": "Lomé", "shortText": "Lomé", "types": ["locality", "political"]},
          {"longText": "Maritime", "shortText": "Maritime", "types": ["administrative_area_level_1", "political"]},
          {"longText": "Togo", "shortText": "TG", "types": ["country", "political"]}
        ]
      }
    ''') as Map<String, dynamic>;

    test('rend le point, l’adresse formatée et les composants classés', () {
      final details = PlacesService.detailsFromResponse(
        reponseLome(),
        requestedPlaceId: 'ChIJVQIrqQ4nCA8RJvNvY0Bs5Xw',
      );

      expect(details, isNotNull);
      expect(details!.location.latitude, 6.1319);
      expect(details.location.longitude, 1.2255);
      expect(details.formattedAddress, 'Boulevard du 13 Janvier, Lomé, Togo');
      expect(details.placeId, 'ChIJVQIrqQ4nCA8RJvNvY0Bs5Xw');
      expect(details.neighborhood, 'Bè-Kpota');
    });

    test('la ville et le pays viennent du classement de Google, pas du texte', () {
      // La ville était auparavant devinée en cherchant son nom dans l'adresse
      // formatée. Ici elle est lue dans le composant `locality`, et le pays
      // dans `country` — sans qu'aucun nom de ville ni de pays ne figure dans
      // le code.
      final details = PlacesService.detailsFromResponse(
        reponseLome(),
        requestedPlaceId: 'ChIJVQIrqQ4nCA8RJvNvY0Bs5Xw',
      );

      expect(details!.city, AppConstants.defaultCityName);
      expect(details.country, 'Togo');
      expect(details.countryCode?.toLowerCase(), AppConstants.countryCode);
    });

    test('sans `locality`, le niveau administratif tient lieu de ville', () {
      final data = json.decode('''
        {
          "formattedAddress": "Route de Kpalimé, Togo",
          "location": {"latitude": 6.2, "longitude": 1.1},
          "addressComponents": [
            {"longText": "Maritime", "shortText": "Maritime", "types": ["administrative_area_level_1", "political"]},
            {"longText": "Togo", "shortText": "TG", "types": ["country", "political"]}
          ]
        }
      ''') as Map<String, dynamic>;

      final details = PlacesService.detailsFromResponse(data, requestedPlaceId: 'ChIJ456');

      expect(details!.city, 'Maritime');
      // `id` absent de la réponse : celui demandé fait foi, sinon l'écran
      // perdrait la référence du lieu qu'il vient d'afficher.
      expect(details.placeId, 'ChIJ456');
    });

    test('une réponse sans point n’est pas exploitable', () {
      // Mieux vaut « ce lieu n'a pas pu être localisé » qu'une adresse
      // enregistrée sans coordonnées : la livraison en dépend.
      final sansPoint = json.decode('''
        {"id": "ChIJ789", "formattedAddress": "Quelque part"}
      ''') as Map<String, dynamic>;
      final sansAdresse = json.decode('''
        {"id": "ChIJ789", "location": {"latitude": 6.13, "longitude": 1.22}}
      ''') as Map<String, dynamic>;

      expect(
        PlacesService.detailsFromResponse(sansPoint, requestedPlaceId: 'ChIJ789'),
        isNull,
      );
      expect(
        PlacesService.detailsFromResponse(sansAdresse, requestedPlaceId: 'ChIJ789'),
        isNull,
      );
    });
  });
}
