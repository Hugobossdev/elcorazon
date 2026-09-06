import 'package:flutter/material.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/presentation/messages_erreur.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/loading_widget.dart' as etats;

/// Réglages de communication du client — `/api/v1/profiles/preferences/`.
///
/// ## Pourquoi cet écran existe
///
/// Le serveur honore un consentement au marketing depuis l'origine :
/// `apps/notifications/services.py` relit `marketing_push_enabled` avant chaque
/// campagne, et une campagne n'atteint pas un client qui l'a coupé. **Aucune
/// application ne le montrait.** Le commentaire du serveur en tirait la
/// conséquence sans la corriger — il justifiait le défaut « accepté » par le
/// fait que l'utilisateur ne visiterait jamais « un écran de réglages » : il
/// n'y en avait pas.
///
/// Un consentement qu'on ne peut pas retirer n'en est pas un. C'est ce que cet
/// écran répare, et rien de plus : il n'expose que ce que le serveur applique
/// ou enregistre réellement.
///
/// ## Ce qu'il ne propose pas, et pourquoi
///
/// * **Les notifications de commande.** « Votre livreur arrive » n'est pas du
///   marketing et ne se coupe pas — le serveur ne le permet pas davantage. Un
///   interrupteur qui prétendrait les taire mentirait, et laisserait un client
///   derrière sa porte pendant que son repas refroidit.
/// * **Les allergènes et les régimes.** Le serveur les stocke, mais aucun
///   chemin ne les porte jusqu'à la cuisine. Les demander ici laisserait un
///   client allergique croire qu'il a prévenu le restaurant. Tant que la
///   commande ne les transporte pas, ne pas les demander est la seule réponse
///   honnête.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late final eccore.PreferencesRepository _depot = eccore.PreferencesRepository(
    apiClient: apiClient,
  );

  eccore.CustomerPreferences? _preferences;
  String? _erreur;
  bool _chargement = true;

  /// Une écriture est en vol. Les interrupteurs sont alors inertes : deux
  /// bascules rapides sur le même champ partiraient dans un ordre que rien ne
  /// garantit, et la dernière réponse reçue — pas la dernière demandée —
  /// deviendrait l'état affiché.
  bool _enregistrement = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final lues = await _depot.read();
      if (!mounted) return;
      setState(() {
        _preferences = lues;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = messageErreur(e);
        _chargement = false;
      });
    }
  }

  /// Écrit un consentement, et **revient en arrière si le serveur refuse**.
  ///
  /// L'interrupteur bouge d'abord, parce qu'un réglage qui attend l'aller-retour
  /// réseau avant de réagir donne l'impression de ne pas fonctionner. Mais il
  /// revient à sa place si l'écriture échoue : laisser un interrupteur sur
  /// « coupé » alors que le serveur a gardé « accepté » ferait croire à un
  /// client qu'il ne recevra plus rien, et les campagnes continueraient
  /// d'arriver.
  Future<void> _ecrire(eccore.CustomerPreferences voulues) async {
    final avant = _preferences;
    setState(() {
      _preferences = voulues;
      _enregistrement = true;
    });

    try {
      final retenues = await _depot.update(voulues);
      if (!mounted) return;
      setState(() {
        _preferences = retenues;
        _enregistrement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preferences = avant;
        _enregistrement = false;
      });
      context.showErrorMessage(messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: const GlassAppBar(title: 'Préférences'),
      body: _corps(context),
    );
  }

  Widget _corps(BuildContext context) {
    if (_chargement) {
      return const etats.LoadingWidget(message: 'Chargement de vos préférences…');
    }

    final erreur = _erreur;
    if (erreur != null) {
      return etats.ErrorWidget(message: erreur, onRetry: _charger);
    }

    final preferences = _preferences!;
    final theme = Theme.of(context);

    return ListView(
      padding: DesignConstants.paddingL,
      children: [
        const SectionHeader(title: 'Offres et nouveautés'),
        const SizedBox(height: DesignConstants.spacingS),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _interrupteur(
                titre: 'Notifications promotionnelles',
                sousTitre: 'Bons plans et nouveautés sur votre téléphone',
                icone: Icons.campaign_outlined,
                valeur: preferences.marketingPushEnabled,
                onChanged: (valeur) => _ecrire(
                  preferences.copyWith(marketingPushEnabled: valeur),
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),
              _interrupteur(
                titre: 'Courriels promotionnels',
                sousTitre: 'Les mêmes offres, dans votre boîte mail',
                icone: Icons.mail_outline_rounded,
                valeur: preferences.marketingEmailEnabled,
                onChanged: (valeur) => _ecrire(
                  preferences.copyWith(marketingEmailEnabled: valeur),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignConstants.spacingL),
        // Dit ce qui ne se coupe pas, et pourquoi. Sans cette phrase, un client
        // qui coupe tout s'attend au silence et s'inquiète de recevoir encore
        // « votre livreur arrive » — ou pire, coupe en croyant se débarrasser
        // des notifications de commande.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: DesignConstants.spacingS),
            Expanded(
              child: Text(
                'Le suivi de vos commandes — confirmation, préparation, arrivée '
                'du livreur — continue d’arriver quoi qu’il arrive. Ces réglages '
                'ne concernent que les offres.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _interrupteur({
    required String titre,
    required String sousTitre,
    required IconData icone,
    required bool valeur,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DesignConstants.spacingM,
        vertical: DesignConstants.spacingXS,
      ),
      secondary: Icon(icone, color: theme.colorScheme.primary),
      title: Text(titre, style: theme.textTheme.titleMedium),
      subtitle: Text(
        sousTitre,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      value: valeur,
      onChanged: _enregistrement ? null : onChanged,
    );
  }
}
