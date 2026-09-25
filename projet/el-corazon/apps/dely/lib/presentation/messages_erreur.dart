import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Ce qu'on dit au livreur quand une action échoue.
///
/// Le fond de la règle vit désormais dans le socle
/// (`eccore.messageErreurApi`) : le `detail` du serveur est la phrase à
/// afficher quand il y en a une, et les pannes de transport se nomment une
/// fois pour les trois applications. Ce fichier ne garde que ce qui est propre
/// au métier du livreur.
/// Un refus décidé **ici**, avant tout appel, avec la phrase à montrer.
///
/// Distinct du `StateError`, que [messageErreur] lit comme une liste de
/// courses périmée : un solde illisible n'a rien à voir avec une course.
class RefusLocal implements Exception {
  const RefusLocal(this.message);

  final String message;

  @override
  String toString() => message;
}

String messageErreur(Object erreur) {
  if (erreur is RefusLocal) return erreur.message;

  // `AppService._requireCourse` lève ceci quand un écran travaille sur une
  // liste périmée — une course qu'un collègue a prise entre-temps, par
  // exemple. Le geste utile est de recharger, pas de réessayer.
  if (erreur is StateError) {
    return 'Cette course n\'est plus dans votre liste. Rafraîchissez l\'écran.';
  }

  return eccore.messageErreurApi(erreur, compteAttendu: 'livreur');
}
