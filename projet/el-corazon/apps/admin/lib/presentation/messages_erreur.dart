import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Ce qu'on dit au personnel quand une action échoue.
///
/// Le fond de la règle vit dans le socle (`eccore.messageErreurApi`) : le
/// `detail` du serveur est la phrase à afficher quand il y en a une.
///
/// Le back-office en a un besoin particulier. Ses refus les plus fréquents sont
/// des **403 de permission** et des **409 de règle métier** — « ce livreur
/// n'est pas rattaché à l'établissement de la commande », « la mise en service
/// est refusée : il manque des horaires ». Le serveur nomme précisément ce qui
/// bloque et ce qui manque ; l'affichage `'Erreur: $e'` remplaçait cette phrase
/// par un nom de classe Dart, si bien qu'un opérateur devant un dossier qu'il
/// n'a pas le droit d'instruire lisait la même chose que devant une panne
/// réseau, et appelait le support dans les deux cas.
String messageErreur(Object erreur) {
  return eccore.messageErreurApi(erreur, compteAttendu: 'administrateur');
}
