import 'dart:math';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/perimetre_personnel.dart';
import 'package:admin/services/network_service.dart';
import 'package:admin/services/role_management_service.dart';

/// Les comptes du personnel : les ouvrir, les rattacher, leur rendre l'accès.
///
/// ## Ce que ce fichier comble
///
/// Le serveur savait tout faire depuis l'origine (`StaffViewSet`) ; l'écran
/// des rôles ne savait qu'attribuer un rôle et désactiver un compte. Ouvrir un
/// compte d'opérateur passait par `django-admin`, et le poste de cuisine
/// renvoyait un compte sans rattachement vers « un responsable du siège » qui
/// n'avait aucun écran pour l'y rattacher.
///
/// ## Ce qu'il ne décide pas
///
/// Hors du siège, le serveur refuse (403) un rattachement ou un rôle que le
/// compte connecté ne détient pas lui-même. Les listes proposées ici sont
/// celles que ce compte voit ; le refus, s'il vient, est affiché tel que le
/// serveur l'a écrit.

/// Mot de passe provisoire, à transmettre de vive voix.
///
/// Sans caractères ambigus (`0`/`O`, `1`/`l`/`I`) : il sera dicté au
/// téléphone ou recopié d'un papier, et une confusion coûte un aller-retour.
String motDePasseProvisoire({Random? aleatoire, int longueur = 12}) {
  const alphabet = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final hasard = aleatoire ?? Random.secure();
  return List.generate(longueur, (_) => alphabet[hasard.nextInt(alphabet.length)]).join();
}

/// L'arbre marché → ville → établissement, une case par niveau.
///
/// Ce qu'une case supérieure couvre déjà s'affiche **coché et grisé**, avec ce
/// qui le couvre : cocher Lomé puis ses trois cuisines n'ajoute rien, et
/// laisse croire qu'en décochant la ville on garderait les cuisines — ce qui
/// est vrai, mais seulement parce qu'on les a cochées à part. L'écran le montre
/// au lieu de le laisser deviner.
class SelecteurDePerimetre extends StatelessWidget {
  const SelecteurDePerimetre({
    required this.perimetre,
    required this.onChanged,
    required this.pays,
    required this.villes,
    required this.etablissements,
    super.key,
  });

  final PerimetreDuCompte perimetre;
  final ValueChanged<PerimetreDuCompte> onChanged;
  final List<eccore.ManagedCountry> pays;
  final List<eccore.ManagedCity> villes;
  final List<eccore.ManagedRestaurant> etablissements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lignes = <Widget>[];

    final paysTries = [...pays]..sort((a, b) => a.name.compareTo(b.name));
    for (final marche in paysTries) {
      final iso = marche.isoCode.toUpperCase();
      lignes.add(
        _Case(
          niveau: 0,
          titre: 'Marché ${marche.name}',
          detail: 'Tout le pays, cuisines à venir comprises',
          coche: perimetre.pays.contains(iso),
          onChanged: () => onChanged(perimetre.basculerPays(iso)),
        ),
      );

      final villesDuPays = villes
          .where((ville) => ville.countryIsoCode.toUpperCase() == iso)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      for (final ville in villesDuPays) {
        final couverture = perimetre.couvertureDeVille(ville);
        lignes.add(
          _Case(
            niveau: 1,
            titre: ville.name,
            detail: couverture != null ? 'Couverte par le marché' : 'Toute la ville',
            coche: couverture != null || perimetre.villes.contains(ville.slug),
            onChanged: couverture != null
                ? null
                : () => onChanged(perimetre.basculerVille(ville.slug)),
          ),
        );

        final cuisines = etablissements
            .where((etablissement) => etablissement.citySlug == ville.slug)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        for (final cuisine in cuisines) {
          final couvertePar = perimetre.couvertureDEtablissement(cuisine);
          lignes.add(
            _Case(
              niveau: 2,
              titre: cuisine.name,
              detail: couvertePar != null ? 'Couvert par $couvertePar' : null,
              coche: couvertePar != null || perimetre.etablissements.contains(cuisine.slug),
              onChanged: couvertePar != null
                  ? null
                  : () => onChanged(perimetre.basculerEtablissement(cuisine.slug)),
            ),
          );
        }
      }
    }

    // Un compte peut être rattaché à ce que le lecteur ne voit pas — une
    // cuisine d'un autre marché, pour un directeur pays. Ces rattachements
    // ne s'affichent pas, mais ils sont **conservés** : l'enregistrement
    // renvoie l'ensemble, pas seulement ce qui était à l'écran.
    final invisibles = _horsDeVue();
    if (invisibles > 0) {
      lignes.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '$invisibles rattachement(s) hors de votre périmètre, conservé(s) tels quels.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
      );
    }

    if (lignes.isEmpty) {
      return Text(
        'Aucun établissement dans votre périmètre.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: lignes);
  }

  int _horsDeVue() {
    final isoVus = {for (final marche in pays) marche.isoCode.toUpperCase()};
    final villesVues = {for (final ville in villes) ville.slug};
    final cuisinesVues = {for (final cuisine in etablissements) cuisine.slug};
    return perimetre.pays.where((iso) => !isoVus.contains(iso)).length +
        perimetre.villes.where((slug) => !villesVues.contains(slug)).length +
        perimetre.etablissements.where((slug) => !cuisinesVues.contains(slug)).length;
  }
}

class _Case extends StatelessWidget {
  const _Case({
    required this.niveau,
    required this.titre,
    required this.coche,
    required this.onChanged,
    this.detail,
  });

  final int niveau;
  final String titre;
  final String? detail;
  final bool coche;

  /// `null` quand la case est couverte par un niveau supérieur.
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.only(left: 24.0 * niveau),
      title: Text(
        titre,
        style: niveau == 0 ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      subtitle: detail == null ? null : Text(detail!),
      value: coche,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
    );
  }
}

/// Le réseau que le sélecteur affiche, chargé une fois.
///
/// La panne se dit : une liste vide sous « Périmètre » laisserait croire que le
/// réseau n'a aucun établissement, et le compte serait créé rattaché à rien.
class _ReseauDuSelecteur extends StatefulWidget {
  const _ReseauDuSelecteur({required this.perimetre, required this.onChanged});

  final PerimetreDuCompte perimetre;
  final ValueChanged<PerimetreDuCompte> onChanged;

  @override
  State<_ReseauDuSelecteur> createState() => _ReseauDuSelecteurState();
}

class _ReseauDuSelecteurState extends State<_ReseauDuSelecteur> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NetworkService>().resolve();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reseau = context.watch<NetworkService>();
    final theme = Theme.of(context);

    if (reseau.isLoading && reseau.restaurants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (reseau.error != null && reseau.restaurants.isEmpty) {
      return Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text('Réseau illisible : ${reseau.error}')),
          TextButton(
            onPressed: () => reseau.resolve(force: true),
            child: const Text('Réessayer'),
          ),
        ],
      );
    }

    return SelecteurDePerimetre(
      perimetre: widget.perimetre,
      onChanged: widget.onChanged,
      pays: reseau.countries,
      villes: reseau.cities,
      etablissements: reseau.restaurants,
    );
  }
}

/// Ouvre un compte du personnel. Rend le compte créé, ou `null` si l'on a
/// renoncé.
class DialogueNouveauCompte extends StatefulWidget {
  const DialogueNouveauCompte({super.key});

  @override
  State<DialogueNouveauCompte> createState() => _DialogueNouveauCompteState();
}

class _DialogueNouveauCompteState extends State<DialogueNouveauCompte> {
  final _formulaire = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _telephone = TextEditingController();
  final _motDePasse = TextEditingController(text: motDePasseProvisoire());
  final Set<String> _roles = {};
  PerimetreDuCompte _perimetre = const PerimetreDuCompte();
  bool _envoi = false;
  String? _refus;

  @override
  void dispose() {
    _nom.dispose();
    _email.dispose();
    _telephone.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _creer() async {
    if (!(_formulaire.currentState?.validate() ?? false)) return;
    setState(() {
      _envoi = true;
      _refus = null;
    });

    final service = context.read<RoleManagementService>();
    final cree = await service.createStaff(
      email: _email.text.trim(),
      fullName: _nom.text.trim(),
      password: _motDePasse.text,
      phone: _telephone.text.trim(),
      roleIds: _roles.toList(),
      restaurantSlugs: _perimetre.etablissements.toList()..sort(),
      countryCodes: _perimetre.pays.toList()..sort(),
      citySlugs: _perimetre.villes.toList()..sort(),
    );

    if (!mounted) return;
    if (cree != null) {
      Navigator.of(context).pop(cree);
    } else {
      // Le formulaire reste ouvert : tout ressaisir parce que l'adresse était
      // déjà prise serait la pire façon d'apprendre la règle.
      setState(() {
        _envoi = false;
        _refus = service.error ?? 'Création refusée.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = context.watch<RoleManagementService>().roles;
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Nouveau compte du personnel'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formulaire,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nom,
                  decoration: const InputDecoration(labelText: 'Nom complet *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Le nom est requis' : null,
                ),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'Adresse électronique *',
                    helperText: 'C’est l’identifiant de connexion ; elle ne se modifie plus ensuite.',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Adresse électronique invalide' : null,
                ),
                TextFormField(
                  controller: _telephone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                  keyboardType: TextInputType.phone,
                ),
                _ChampMotDePasse(controleur: _motDePasse),
                const SizedBox(height: 16),
                Text('Rôles', style: theme.textTheme.titleSmall),
                if (roles.isEmpty)
                  Text(
                    'Aucun rôle lisible : le compte sera créé sans droit.',
                    style: theme.textTheme.bodySmall,
                  ),
                for (final role in roles)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(role.name),
                    subtitle: Text('${role.permissions.length} permissions'),
                    value: _roles.contains(role.id),
                    onChanged: (coche) => setState(() {
                      if (coche ?? false) {
                        _roles.add(role.id);
                      } else {
                        _roles.remove(role.id);
                      }
                    }),
                  ),
                const SizedBox(height: 16),
                Text('Périmètre', style: theme.textTheme.titleSmall),
                Text(
                  'Sans rattachement, le compte ne verra aucun établissement.',
                  style: theme.textTheme.bodySmall,
                ),
                _ReseauDuSelecteur(
                  perimetre: _perimetre,
                  onChanged: (p) => setState(() => _perimetre = p),
                ),
                if (_refus != null) _Refus(_refus!),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi ? null : _creer,
          child: Text(_envoi ? 'Création…' : 'Créer le compte'),
        ),
      ],
    );
  }
}

/// Remplace le périmètre d'un compte existant.
class DialoguePerimetre extends StatefulWidget {
  const DialoguePerimetre({required this.membre, super.key});

  final eccore.StaffMember membre;

  @override
  State<DialoguePerimetre> createState() => _DialoguePerimetreState();
}

class _DialoguePerimetreState extends State<DialoguePerimetre> {
  late PerimetreDuCompte _perimetre = PerimetreDuCompte.du(widget.membre);
  bool _envoi = false;
  String? _refus;

  Future<void> _enregistrer() async {
    setState(() {
      _envoi = true;
      _refus = null;
    });
    final service = context.read<RoleManagementService>();
    final ok = await service.updateStaffScope(
      staffId: widget.membre.id,
      restaurantSlugs: _perimetre.etablissements,
      countryCodes: _perimetre.pays,
      citySlugs: _perimetre.villes,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _envoi = false;
        _refus = service.error ?? 'Rattachement refusé.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devientAveugle = _perimetre.estVide && !widget.membre.isSuperuser;

    return AlertDialog(
      title: Text('Périmètre de ${widget.membre.fullName}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.membre.isSuperuser)
                Text(
                  'Compte du siège : il voit tout le réseau, quels que soient ses '
                  'rattachements.',
                  style: theme.textTheme.bodySmall,
                ),
              _ReseauDuSelecteur(
                perimetre: _perimetre,
                onChanged: (p) => setState(() => _perimetre = p),
              ),
              if (devientAveugle)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Ainsi enregistré, ce compte ne verra plus aucun établissement.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (_refus != null) _Refus(_refus!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi ? null : _enregistrer,
          child: Text(_envoi ? 'Enregistrement…' : 'Enregistrer'),
        ),
      ],
    );
  }
}

/// Pose un nouveau mot de passe — pour qui a perdu le sien au poste.
class DialogueMotDePasse extends StatefulWidget {
  const DialogueMotDePasse({required this.membre, super.key});

  final eccore.StaffMember membre;

  @override
  State<DialogueMotDePasse> createState() => _DialogueMotDePasseState();
}

class _DialogueMotDePasseState extends State<DialogueMotDePasse> {
  final _motDePasse = TextEditingController(text: motDePasseProvisoire());
  final _formulaire = GlobalKey<FormState>();
  bool _envoi = false;
  String? _refus;

  @override
  void dispose() {
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_formulaire.currentState?.validate() ?? false)) return;
    setState(() {
      _envoi = true;
      _refus = null;
    });
    final service = context.read<RoleManagementService>();
    final ok = await service.setStaffPassword(
      staffId: widget.membre.id,
      password: _motDePasse.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _envoi = false;
        _refus = service.error ?? 'Mot de passe refusé.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nouveau mot de passe — ${widget.membre.fullName}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formulaire,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'À transmettre à la personne, qui pourra le changer depuis son '
                'poste. L’ancien cesse de fonctionner dès l’enregistrement.',
              ),
              _ChampMotDePasse(controleur: _motDePasse),
              if (_refus != null) _Refus(_refus!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi ? null : _enregistrer,
          child: Text(_envoi ? 'Enregistrement…' : 'Enregistrer'),
        ),
      ],
    );
  }
}

/// Le mot de passe est **visible** : il est provisoire, et il faut le
/// transmettre. Le masquer obligerait à le deviner pour le dicter.
class _ChampMotDePasse extends StatelessWidget {
  const _ChampMotDePasse({required this.controleur});

  final TextEditingController controleur;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controleur,
      decoration: InputDecoration(
        labelText: 'Mot de passe provisoire *',
        helperText: 'Huit caractères au moins ; le serveur refuse les mots de passe courants.',
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Copier',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () => Clipboard.setData(ClipboardData(text: controleur.text)),
            ),
            IconButton(
              tooltip: 'En générer un autre',
              icon: const Icon(Icons.casino_outlined),
              onPressed: () => controleur.text = motDePasseProvisoire(),
            ),
          ],
        ),
      ),
      validator: (v) => (v == null || v.length < 8) ? 'Huit caractères au moins' : null,
    );
  }
}

class _Refus extends StatelessWidget {
  const _Refus(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
    );
  }
}
