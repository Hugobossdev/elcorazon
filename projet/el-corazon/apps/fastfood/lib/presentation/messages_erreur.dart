import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/services/address_service.dart' show AddressSessionRequired;

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

  return eccore.messageErreurApi(erreur, compteAttendu: 'client');
}
