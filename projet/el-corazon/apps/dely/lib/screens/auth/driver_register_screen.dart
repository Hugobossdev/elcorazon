import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcora_dely/presentation/messages_erreur.dart';
import 'package:elcora_dely/presentation/vehicules.dart';
import 'package:elcora_dely/screens/auth/verification_screen.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/utils/validators.dart';
import 'package:elcora_dely/widgets/custom_button.dart';
import 'package:elcora_dely/widgets/custom_text_field.dart';

/// Candidature de livreur — `POST /delivery/apply/`.
///
/// ## Ce que ce formulaire crée réellement
///
/// Un compte de type livreur **et** un dossier **en attente d'instruction**.
/// Pas un livreur en service : `can_accept_orders` reste faux jusqu'à ce
/// qu'El Corazón ait lu les pièces (invariant L1, garanti côté serveur). Le
/// texte de l'écran le dit, parce qu'un candidat qui croirait pouvoir rouler
/// le soir même reviendrait sur un service client qui ne peut rien pour lui.
///
/// ## Pourquoi l'établissement est demandé
///
/// `CourierProfile.restaurant` est obligatoire en base : un livreur est
/// rattaché à un établissement, c'est de là qu'il part. La liste vient de
/// `GET /restaurants/`, publique, et ne contient que les établissements
/// ouverts — exactement ceux que le serveur acceptera.
///
/// ## Prénom et nom, mais un seul champ au serveur
///
/// Le contrat porte `full_name`, un champ unique. Le formulaire en demande deux
/// parce que c'est ainsi qu'on écrit son nom, et les recolle avant l'envoi.
/// L'inverse — un champ « nom complet » — donne des saisies où le prénom et le
/// nom sont inversés une fois sur trois, et rien ne permet ensuite de les
/// démêler.
class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _email = TextEditingController();
  /// Vide à la construction — l'indicatif suit l'établissement choisi.
  ///
  /// Il valait `+228` en dur : le Togo, quel que soit le pays du restaurant
  /// auquel le livreur postule. Un candidat d'Abidjan enregistrait donc un
  /// numéro togolais s'il ne pensait pas à effacer la proposition, et c'est ce
  /// numéro que la cuisine appelle pour lui confier une course.
  final _telephone = TextEditingController();
  final _motDePasse = TextEditingController();
  final _confirmation = TextEditingController();
  final _plaque = TextEditingController();

  List<eccore.Restaurant>? _etablissements;
  String? _etablissementChoisi;
  String _vehicule = Vehicule.values.first.code;

  bool _chargementEtablissements = true;
  String? _erreurEtablissements;
  bool _envoiEnCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    unawaited(_chargerEtablissements());
  }

  @override
  void dispose() {
    _prenom.dispose();
    _nom.dispose();
    _email.dispose();
    _telephone.dispose();
    _motDePasse.dispose();
    _confirmation.dispose();
    _plaque.dispose();
    super.dispose();
  }

  Future<void> _chargerEtablissements() async {
    setState(() {
      _chargementEtablissements = true;
      _erreurEtablissements = null;
    });
    try {
      final options = await context.read<AppService>().etablissementsOuverts();
      if (!mounted) return;
      setState(() {
        _etablissements = options;
        // Un seul établissement ouvert : le choisir d'office. Faire dérouler
        // une liste d'un élément est une étape sans décision.
        _etablissementChoisi = options.length == 1 ? options.first.slug : null;
      });
      _proposerLIndicatif();
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _erreurEtablissements = messageErreur(erreur));
    } finally {
      if (mounted) setState(() => _chargementEtablissements = false);
    }
  }

  /// Indicatif du pays de l'établissement retenu, ou `null` tant qu'on ne le
  /// connaît pas.
  ///
  /// Le premier de la liste sert de repli quand rien n'est encore choisi : à ce
  /// stade la liste est triée par le serveur, et proposer l'indicatif du
  /// premier vaut mieux que n'en proposer aucun.
  String? get _indicatifPropose {
    final etablissements = _etablissements;
    if (etablissements == null || etablissements.isEmpty) return null;

    final choisi = _etablissementChoisi;
    final etablissement = choisi == null
        ? etablissements.first
        : etablissements.firstWhere(
            (candidat) => candidat.slug == choisi,
            orElse: () => etablissements.first,
          );

    return etablissement.phonePrefix.isEmpty ? null : etablissement.phonePrefix;
  }

  /// Propose l'indicatif du pays de l'établissement choisi.
  ///
  /// **Une proposition, jamais une contrainte.** Le champ n'est réécrit que
  /// s'il est vide ou s'il ne contient encore qu'un indicatif : quelqu'un qui a
  /// déjà tapé son numéro ne doit pas le voir disparaître parce qu'il corrige
  /// son choix de restaurant.
  ///
  /// L'indicatif vient du serveur (`phone_prefix`, hérité du pays à travers la
  /// zone) et non d'une table locale : c'est la même valeur que celle sur
  /// laquelle le back-office et l'application cliente s'appuient, et elle suit
  /// l'ouverture d'un marché sans qu'on republie l'application.
  void _proposerLIndicatif() {
    final prefixe = _indicatifPropose;
    if (prefixe == null) return;

    final saisi = _telephone.text.trim();
    final estUnIndicatifSeul = RegExp(r'^\+\d{0,4}$').hasMatch(saisi);
    if (saisi.isNotEmpty && !estUnIndicatifSeul) return;
    if (saisi == prefixe) return;

    _telephone.text = prefixe;
    _telephone.selection = TextSelection.collapsed(offset: prefixe.length);
  }

  Future<void> _envoyer() async {
    if (_envoiEnCours) return;
    setState(() => _erreur = null);
    if (!_formKey.currentState!.validate()) return;
    if (_etablissementChoisi == null) {
      setState(() => _erreur = 'Choisissez l\'établissement auquel vous vous rattachez.');
      return;
    }

    setState(() => _envoiEnCours = true);
    final email = _email.text.trim().toLowerCase();

    try {
      final recu = await context.read<AppService>().deposerCandidature(
        eccore.CourierApplication(
          email: email,
          password: _motDePasse.text,
          fullName: '${_prenom.text.trim()} ${_nom.text.trim()}'.trim(),
          phone: _telephone.text.replaceAll(RegExp(r'[\s-]'), ''),
          restaurantSlug: _etablissementChoisi!,
          vehicleType: _vehicule,
          vehiclePlate: _plaque.text.trim(),
        ),
      );
      if (!mounted) return;

      // Le compte existe, mais aucune session n'est ouverte : le serveur ne
      // rend aucun jeton ici. `pushReplacement` plutôt que `push` — revenir en
      // arrière sur un formulaire dont l'adresse est désormais prise ne
      // mènerait qu'à un refus.
      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => VerificationScreen(
              email: recu.challenge.email,
              challenge: recu.challenge,
              // L'adresse se corrige en revenant au formulaire — mais le compte
              // est créé : c'est une nouvelle candidature qu'il faudrait
              // déposer. Le bouton renvoie donc à la connexion, d'où l'on peut
              // aussi bien se reconnecter que recommencer.
              onChangeEmail: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ),
        ),
      );
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _erreur = messageErreur(erreur));
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Devenir livreur')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Avertissement(
                  texte:
                      'Votre compte sera créé immédiatement, mais votre dossier '
                      'doit être validé par El Corazón — permis, pièce '
                      'd\'identité, véhicule — avant votre première course.',
                ),
                const SizedBox(height: 24),

                Text('Votre identité', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Prénom',
                  controller: _prenom,
                  prefixIcon: Icons.person_outline,
                  enabled: !_envoiEnCours,
                  validator: (value) => Validators.validateName(value),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Nom',
                  controller: _nom,
                  prefixIcon: Icons.badge_outlined,
                  enabled: !_envoiEnCours,
                  validator: (value) => Validators.validateName(value),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Téléphone',
                  // Le filigrane suit le pays de l'établissement, comme la
                  // valeur proposée : montrer un exemple togolais à un candidat
                  // d'Abidjan lui fait saisir un numéro que la cuisine ne
                  // pourra pas appeler.
                  hint: '${_indicatifPropose ?? '+'}90123456',
                  controller: _telephone,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  enabled: !_envoiEnCours,
                  validator: Validators.validatePhoneE164,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Adresse e-mail',
                  hint: 'vous@exemple.com',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  enabled: !_envoiEnCours,
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 8),
                Text(
                  'C\'est à cette adresse que sera envoyé votre code de '
                  'vérification, et c\'est avec elle que vous vous connecterez.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),

                const SizedBox(height: 24),
                Text('Votre mot de passe', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Mot de passe',
                  controller: _motDePasse,
                  isPassword: true,
                  prefixIcon: Icons.lock_outline,
                  enabled: !_envoiEnCours,
                  validator: Validators.validateStrongPassword,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Confirmez le mot de passe',
                  controller: _confirmation,
                  isPassword: true,
                  prefixIcon: Icons.lock_reset_outlined,
                  enabled: !_envoiEnCours,
                  validator: (value) =>
                      Validators.validatePasswordConfirmation(value, _motDePasse.text),
                ),

                const SizedBox(height: 24),
                Text('Votre rattachement', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _SelecteurEtablissement(
                  etablissements: _etablissements,
                  choisi: _etablissementChoisi,
                  enChargement: _chargementEtablissements,
                  erreur: _erreurEtablissements,
                  enabled: !_envoiEnCours,
                  onChanged: (slug) {
                    setState(() => _etablissementChoisi = slug);
                    _proposerLIndicatif();
                  },
                  onRetry: _chargerEtablissements,
                ),

                const SizedBox(height: 24),
                Text('Votre véhicule', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _vehicule,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.two_wheeler),
                  ),
                  items: [
                    for (final vehicule in Vehicule.values)
                      DropdownMenuItem(
                        value: vehicule.code,
                        child: Row(
                          children: [
                            Icon(vehicule.icone, size: 20),
                            const SizedBox(width: 8),
                            Text(vehicule.libelle),
                          ],
                        ),
                      ),
                  ],
                  onChanged: _envoiEnCours
                      ? null
                      : (valeur) => setState(() => _vehicule = valeur ?? _vehicule),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Plaque d\'immatriculation (facultatif)',
                  controller: _plaque,
                  prefixIcon: Icons.confirmation_number_outlined,
                  enabled: !_envoiEnCours,
                ),

                if (_erreur != null) ...[
                  const SizedBox(height: 20),
                  _Avertissement(texte: _erreur!, erreur: true),
                ],

                const SizedBox(height: 28),
                CustomButton(
                  text: 'Créer mon compte',
                  isLoading: _envoiEnCours,
                  icon: Icons.person_add_alt_1,
                  onPressed: _envoyer,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _envoiEnCours ? null : () => Navigator.of(context).pop(),
                  child: const Text('J\'ai déjà un compte'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sélecteur d'établissement, avec ses trois états.
///
/// Le chargement et l'échec ne sont pas des détails d'affichage : la liste
/// vient du réseau, et sans elle le formulaire ne peut pas être envoyé. Un
/// menu déroulant vide, sans explication ni moyen de réessayer, laisse le
/// candidat devant un bouton qui refuse de partir sans qu'il sache pourquoi.
class _SelecteurEtablissement extends StatelessWidget {
  const _SelecteurEtablissement({
    required this.etablissements,
    required this.choisi,
    required this.enChargement,
    required this.erreur,
    required this.enabled,
    required this.onChanged,
    required this.onRetry,
  });

  final List<eccore.Restaurant>? etablissements;
  final String? choisi;
  final bool enChargement;
  final String? erreur;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (enChargement) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Chargement des établissements…'),
          ],
        ),
      );
    }

    if (erreur != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avertissement(texte: erreur!, erreur: true),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      );
    }

    final options = etablissements ?? const <eccore.Restaurant>[];
    if (options.isEmpty) {
      return const _Avertissement(
        texte: 'Aucun établissement n\'accepte de candidature pour le moment. '
            'Réessayez plus tard.',
        erreur: true,
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: choisi,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.storefront_outlined),
        hintText: 'Choisissez un établissement',
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option.slug,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled ? onChanged : null,
      validator: (value) => value == null ? 'Choisissez un établissement' : null,
    );
  }
}

class _Avertissement extends StatelessWidget {
  const _Avertissement({required this.texte, this.erreur = false});

  final String texte;
  final bool erreur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couleur = erreur ? theme.colorScheme.error : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(erreur ? Icons.error_outline : Icons.info_outline, color: couleur, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texte, style: theme.textTheme.bodyMedium?.copyWith(color: couleur)),
          ),
        ],
      ),
    );
  }
}
