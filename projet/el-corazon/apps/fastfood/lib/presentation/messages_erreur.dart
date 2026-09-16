import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/presentation/situation_cuisine.dart';
import 'package:elcora_fast/services/address_service.dart' show AddressSessionRequired;
import 'package:elcora_fast/services/kitchen_context_service.dart'
    show CuisineIndisponible, SituationCuisine;

/// Ce qu'on dit au client quand une action échoue.
///
/// Le fond de la règle vit dans le socle (`eccore.messageErreurApi`) : le
/// `detail` du serveur est la phrase à afficher quand il y en a une. Ce fichier
/// ne garde que ce qui est propre au parcours client.
///
/// Il existe parce que quatre écrans mettaient encore l'exception brute sous
/// les yeux de quelqu'un qui cherchait un plat : « Erreur lors de la
/// recherche: DioException [connection error] … ». Une phrase pareille ne dit
/// pas quoi faire, et donne à l'application l'air d'être cassée là où le
/// serveur était simplement injoignable.
String messageErreur(Object erreur) {
  // Levée quand un geste demande un compte et que la session est absente —
  // enregistrer une adresse, par exemple. Le message porte déjà l'invitation à
  // se connecter ; le reformuler ici la dédoublerait.
  if (erreur is AddressSessionRequired) return erreur.toString();

  // Aucune cuisine ne peut servir la demande : la phrase dépend de **pourquoi**
  // — une panne ne se dit pas « aucune cuisine ne vous livre ».
  if (erreur is CuisineIndisponible) {
    return PresentationSituation.de(
      erreur.situation,
      // Seul un refus argumenté porte une phrase destinée au client. Le détail
      // d'une panne de transport est technique, et reste au journal.
      motifServeur: erreur.situation == SituationCuisine.erreurApi ? erreur.detail : null,
    ).message;
  }

  return eccore.messageErreurApi(erreur, compteAttendu: 'client');
}
