import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Ce qu'on dit au livreur quand une action échoue.
///
/// Le fond de la règle vit désormais dans le socle
/// (`eccore.messageErreurApi`) : le `detail` du serveur est la phrase à
/// afficher quand il y en a une, et les pannes de transport se nomment une
/// fois pour les trois applications. Ce fichier ne garde que ce qui est propre
/// au métier du livreur.
String messageErreur(Object erreur) {
  // `AppService._requireCourse` lève ceci quand un écran travaille sur une
  // liste périmée — une course qu'un collègue a prise entre-temps, par
  // exemple. Le geste utile est de recharger, pas de réessayer.
  if (erreur is StateError) {
    return 'Cette course n\'est plus dans votre liste. Rafraîchissez l\'écran.';
  }

  return eccore.messageErreurApi(erreur, compteAttendu: 'livreur');
}
