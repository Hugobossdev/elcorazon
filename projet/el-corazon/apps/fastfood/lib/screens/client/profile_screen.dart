import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/theme_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/profil_utilisateur.dart';
import 'package:elcora_fast/services/gamification_service.dart';
import 'package:elcora_fast/navigation/app_router.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/loading_widget.dart' as etats;
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/theme.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

/// Onglet « Profil » de la barre inférieure.
///
/// ## Ce que la reprise Stitch change
///
/// L'écran gardait une barre supérieure en aplat rouge, six `Card` d'élévation
/// 2 ou 4, et des gris de Material (`Colors.grey[600]`, `grey[700]`) là où le
/// design system porte `onSurfaceVariant`. Il passe aux briques communes —
/// barre translucide, [SectionCard], [SectionHeader], [StatusChip],
/// [ActionButton] — et la carte de fidélité prend le dégradé doré que
/// `DESIGN.md` réserve précisément à ce genre de bloc.
///
/// La maquette Stitch ne couvre pas cet écran, mais elle couvre la **barre
/// inférieure** qui l'atteint : le laisser à l'ancienne charte faisait changer
/// d'application au quatrième onglet.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: const GlassAppBar(title: 'Mon profil', showBack: false),
      body: Consumer2<AppService, GamificationService>(
        builder: (context, appService, gamification, child) {
          if (!appService.isLoggedIn || appService.currentUser == null) {
            return _profilInvite(context);
          }

          final user = appService.currentUser!;
          final ordersCount = appService.orders.length;
          // `user.loyaltyPoints` valait toujours zéro : le compte ne porte pas
          // le solde, `GamificationService` le tient depuis le socle.
          final points = gamification.currentPoints;
          final badges = gamification.badges;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              DesignConstants.edgeMargin,
              DesignConstants.spacingM,
              DesignConstants.edgeMargin,
              DesignConstants.spacingXL,
            ),
            children: [
              _enTete(context, user, ordersCount: ordersCount, points: points),
              const SizedBox(height: DesignConstants.spacingM),
              _raccourcis(context),
              if (user.estClient) ...[
                const SizedBox(height: DesignConstants.spacingL),
                _carteDeFidelite(context, points, badges),
              ],
              const SizedBox(height: DesignConstants.spacingL),
              _apparence(context),
              const SizedBox(height: DesignConstants.spacingL),
              _section(context, 'Paramètres', _entreesDesReglages(context)),
              const SizedBox(height: DesignConstants.spacingL),
              _section(context, 'Plus', _entreesComplementaires(context)),
              const SizedBox(height: DesignConstants.spacingL),
              ActionButton(
                label: 'Se déconnecter',
                emphasis: ActionEmphasis.outlined,
                icon: Icons.logout_rounded,
                foregroundColor: theme.colorScheme.error,
                onPressed: () => _confirmerDeconnexion(context),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------ invité

  Widget _profilInvite(BuildContext context) {
    return etats.EmptyStateWidget(
      title: 'Connectez-vous',
      message: 'Votre profil, vos commandes et vos favoris vous attendent.',
      icon: Icons.account_circle_outlined,
      actionText: 'Se connecter ou s’inscrire',
      onAction: () => NavigationService.navigateToAuth(context),
    );
  }

  // ------------------------------------------------------------------ entête

  Widget _enTete(
    BuildContext context,
    eccore.User user, {
    required int ordersCount,
    required int points,
  }) {
    final theme = Theme.of(context);
    final palier = palierDeFidelite(points);

    return SectionCard(
      onTap: () => _ouvrirLaModification(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(context, user),
              const SizedBox(width: DesignConstants.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: AppTypography.titleLg(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: AppTypography.bodyMd(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${user.pastilleDuType} ${user.libelleDuType}',
                      style: AppTypography.labelLg(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_outlined,
                color: theme.colorScheme.primary,
                size: DesignConstants.iconSizeMedium,
              ),
            ],
          ),
          const SizedBox(height: DesignConstants.spacingM),
          Wrap(
            spacing: DesignConstants.spacingS,
            runSpacing: DesignConstants.spacingS,
            children: [
              StatusChip(
                label: palier,
                icon: Icons.workspace_premium_rounded,
                background: _fondDuPalier(theme, palier),
                foreground: _encreDuPalier(theme, palier),
              ),
              if (user.estClient)
                StatusChip(
                  label: '$points pts',
                  icon: Icons.loyalty_rounded,
                  background: theme.colorScheme.secondaryContainer,
                  foreground: theme.colorScheme.onSecondaryContainer,
                ),
              StatusChip(
                label: ordersCount <= 1
                    ? '$ordersCount commande'
                    : '$ordersCount commandes',
                icon: Icons.receipt_long_rounded,
                background: theme.colorScheme.surfaceContainerHigh,
                foreground: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, eccore.User user) {
    final theme = Theme.of(context);
    const cote = DesignConstants.avatarSizeLarge;

    return ClipOval(
      child: SizedBox(
        width: cote,
        height: cote,
        child: user.avatar == null
            ? ColoredBox(
                color: theme.colorScheme.primary,
                child: Center(
                  child: Text(
                    user.initiales,
                    style: AppTypography.headlineSm(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              )
            : FoodImage(
                url: user.avatar,
                icon: Icons.person_rounded,
                iconSize: 32,
              ),
      ),
    );
  }

  /// Le palier ne prend pas une couleur inventée : le VIP porte le doré de la
  /// secondaire, « Fidèle » l'orange de la tertiaire, « Standard » la surface.
  /// L'ambre `#FFB300` qu'il portait n'appartenait à aucun jeton.
  Color _fondDuPalier(ThemeData theme, String palier) {
    switch (palier) {
      case 'VIP':
        return theme.colorScheme.secondaryContainer;
      case 'Fidèle':
        return theme.colorScheme.tertiaryContainer;
      default:
        return theme.colorScheme.surfaceContainerHigh;
    }
  }

  Color _encreDuPalier(ThemeData theme, String palier) {
    switch (palier) {
      case 'VIP':
        return theme.colorScheme.onSecondaryContainer;
      case 'Fidèle':
        return theme.colorScheme.onTertiaryContainer;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  // -------------------------------------------------------------- raccourcis

  Widget _raccourcis(BuildContext context) {
    final theme = Theme.of(context);

    Widget tuile({
      required IconData icone,
      required String libelle,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: SectionCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(
            vertical: DesignConstants.spacingM,
            horizontal: DesignConstants.spacingS,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, color: theme.colorScheme.primary),
              const SizedBox(height: DesignConstants.spacingXS + 2),
              Text(
                libelle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelLg(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tuile(
          icone: Icons.receipt_long_rounded,
          libelle: 'Commandes',
          onTap: () => Navigator.of(context).pushNamed(AppRouter.enhancedOrders),
        ),
        const SizedBox(width: DesignConstants.gutter),
        tuile(
          icone: Icons.location_on_outlined,
          libelle: 'Adresses',
          onTap: () =>
              Navigator.of(context).pushNamed(AppRouter.addressManagement),
        ),
        const SizedBox(width: DesignConstants.gutter),
        tuile(
          icone: Icons.notifications_none_rounded,
          libelle: 'Alertes',
          onTap: () => context.navigateToNotifications(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- fidélité

  Widget _carteDeFidelite(
    BuildContext context,
    int points,
    List<Map<String, dynamic>> badges,
  ) {
    final theme = Theme.of(context);
    final versLaProchaine = 100 - (points % 100);
    final progression = (points % 100) / 100;

    // Le dégradé doré, sur lequel l'encre sombre de `onSecondaryContainer`
    // tient le contraste — du blanc sur ce fond ne le tenait pas.
    const degrade = LinearGradient(
      colors: AppColors.secondaryGradient,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final encre = theme.colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.all(DesignConstants.spacingL),
      decoration: BoxDecoration(
        gradient: degrade,
        borderRadius: DesignConstants.borderRadiusLarge,
        boxShadow: DesignConstants.shadowLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.loyalty_rounded, color: encre),
              const SizedBox(width: DesignConstants.spacingS),
              Expanded(
                child: Text(
                  'Programme de fidélité',
                  style: AppTypography.titleLg(color: encre),
                ),
              ),
              TextButton(
                onPressed: () => context.navigateToRewards(),
                style: TextButton.styleFrom(
                  foregroundColor: encre,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Voir', style: AppTypography.labelLg(color: encre)),
              ),
            ],
          ),
          const SizedBox(height: DesignConstants.spacingM),
          Text('$points points', style: AppTypography.displayLg(color: encre)),
          const SizedBox(height: DesignConstants.spacingS),
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignConstants.radiusSmall),
            child: LinearProgressIndicator(
              value: progression,
              minHeight: 8,
              backgroundColor: encre.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(encre),
            ),
          ),
          const SizedBox(height: DesignConstants.spacingS),
          Text(
            '$versLaProchaine points jusqu’à votre prochaine récompense',
            style: AppTypography.bodyMd(color: encre),
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: DesignConstants.spacingM),
            Wrap(
              spacing: DesignConstants.spacingS,
              runSpacing: DesignConstants.spacingS,
              children: [
                for (final badge in badges)
                  StatusChip(
                    label: badge['title']?.toString() ?? '',
                    icon: Icons.military_tech_rounded,
                    background: theme.colorScheme.surfaceContainerLowest
                        .withValues(alpha: 0.7),
                    foreground: encre,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- sections

  Widget _apparence(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Apparence'),
            const SizedBox(height: DesignConstants.spacingS),
            SectionCard(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DesignConstants.spacingM,
                  vertical: DesignConstants.spacingXS,
                ),
                secondary: _pastilleDIcone(
                  context,
                  themeService.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                ),
                title: Text(
                  'Mode sombre',
                  style: AppTypography.titleLg(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  themeService.isDarkMode ? 'Activé' : 'Désactivé',
                  style: AppTypography.bodyMd(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                value: themeService.isDarkMode,
                onChanged: (value) => themeService.toggleTheme(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _section(BuildContext context, String titre, List<_Entree> entrees) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: titre),
        const SizedBox(height: DesignConstants.spacingS),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < entrees.length; i++) ...[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: DesignConstants.spacingM,
                    vertical: DesignConstants.spacingXS,
                  ),
                  leading: _pastilleDIcone(context, entrees[i].icone),
                  title: Text(
                    entrees[i].titre,
                    style: AppTypography.titleLg(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: entrees[i].sousTitre == null
                      ? null
                      : Text(
                          entrees[i].sousTitre!,
                          style: AppTypography.bodyMd(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onTap: entrees[i].onTap,
                ),
                if (i < entrees.length - 1)
                  Divider(
                    height: 1,
                    indent: DesignConstants.spacingXL + DesignConstants.spacingL,
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _pastilleDIcone(BuildContext context, IconData icone) {
    final theme = Theme.of(context);
    return Container(
      width: DesignConstants.avatarSizeSmall + 8,
      height: DesignConstants.avatarSizeSmall + 8,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: DesignConstants.borderRadiusSmall,
      ),
      child: Icon(
        icone,
        color: theme.colorScheme.primary,
        size: DesignConstants.iconSizeSmall + 4,
      ),
    );
  }

  List<_Entree> _entreesDesReglages(BuildContext context) => [
        _Entree(
          icone: Icons.person_outline_rounded,
          titre: 'Informations personnelles',
          sousTitre: 'Nom et téléphone',
          onTap: () => _ouvrirLaModification(context),
        ),
        _Entree(
          icone: Icons.location_on_outlined,
          titre: 'Adresses',
          sousTitre: 'Gérer mes adresses de livraison',
          onTap: () =>
              Navigator.of(context).pushNamed(AppRouter.addressManagement),
        ),
        _Entree(
          icone: Icons.receipt_long_outlined,
          titre: 'Mes commandes',
          sousTitre: 'Historique et détails',
          onTap: () => Navigator.of(context).pushNamed(AppRouter.enhancedOrders),
        ),
        _Entree(
          icone: Icons.notifications_none_rounded,
          titre: 'Notifications',
          sousTitre: 'Alertes de commande et promotions',
          onTap: () => context.navigateToNotifications(),
        ),
      ];

  List<_Entree> _entreesComplementaires(BuildContext context) => [
        _Entree(
          icone: Icons.groups_outlined,
          titre: 'Commandes groupées',
          sousTitre: 'Commander avec des amis',
          onTap: () => Navigator.of(context).pushNamed(AppRouter.groupOrder),
        ),
        _Entree(
          icone: Icons.people_outline_rounded,
          titre: 'Mes groupes',
          sousTitre: 'Partager avec vos proches',
          onTap: () => Navigator.of(context).pushNamed(AppRouter.socialGroups),
        ),
        _Entree(
          icone: Icons.help_outline_rounded,
          titre: 'Aide et support',
          sousTitre: 'FAQ, guides et contact',
          onTap: () => Navigator.of(context).pushNamed(AppRouter.support),
        ),
        _Entree(
          icone: Icons.info_outline_rounded,
          titre: 'À propos d’El Corazón',
          sousTitre: 'Version 1.0.0',
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'El Corazón',
            applicationVersion: '1.0.0',
            applicationLegalese: '© El Corazón',
          ),
        ),
      ];

  // ------------------------------------------------------------------ actions

  void _ouvrirLaModification(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const EditProfileDialog(),
    );
  }

  void _confirmerDeconnexion(BuildContext context) {
    context.showEnhancedDialog(
      title: 'Se déconnecter',
      content: 'Votre panier et vos adresses resteront liés à votre compte.',
      confirmText: 'Se déconnecter',
      cancelText: 'Annuler',
      isDestructive: true,
      onConfirm: () async {
        final appService = Provider.of<AppService>(context, listen: false);
        await appService.logout();
        if (context.mounted) {
          NavigationService.navigateToAuth(context);
        }
      },
      onCancel: () {},
    );
  }
}

/// Une ligne d'une section de réglages.
class _Entree {
  const _Entree({
    required this.icone,
    required this.titre,
    required this.onTap,
    this.sousTitre,
  });

  final IconData icone;
  final String titre;
  final String? sousTitre;
  final VoidCallback onTap;
}

/// Modification du nom et du téléphone.
///
/// ## Ce que cette boîte faisait avant
///
/// Elle se fermait sur « Profil mis à jour avec succès ! » **sans rien
/// envoyer** : un commentaire « In a real app, would update the user profile »
/// tenait lieu d'appel. Le champ retrouvait son ancienne valeur à la
/// réouverture, et l'utilisateur n'avait aucun moyen de comprendre pourquoi.
///
/// `AuthRepository.updateProfile` existait pourtant depuis le début. La boîte
/// l'appelle désormais par `AppService.updateProfile`, montre l'attente, et ne
/// se ferme qu'en cas de succès — un échec reste affiché, avec son motif.
class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppService>(context, listen: false).currentUser!;
    _nameController.text = user.fullName;
    _phoneController.text = user.phone ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final nom = _nameController.text.trim();
    if (nom.isEmpty) {
      setState(() => _erreur = 'Le nom ne peut pas être vide.');
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await Provider.of<AppService>(context, listen: false).updateProfile(
        fullName: nom,
        phone: _phoneController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showSuccessMessage('Profil mis à jour');
    } on eccore.ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _erreur = e.detail;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _erreur = 'Mise à jour impossible pour le moment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Modifier le profil'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            enabled: !_enCours,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom complet'),
          ),
          const SizedBox(height: DesignConstants.spacingM),
          if (kIsWeb)
            TextField(
              controller: _phoneController,
              enabled: !_enCours,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                hintText: AppConstants.phoneHint,
              ),
            )
          else
            IntlPhoneField(
              controller: _phoneController,
              enabled: !_enCours,
              decoration: const InputDecoration(labelText: 'Téléphone'),
              initialCountryCode: AppConstants.phoneCountryCode,
              languageCode: 'fr',
            ),
          if (_erreur != null) ...[
            const SizedBox(height: DesignConstants.spacingM),
            Text(
              _erreur!,
              style: AppTypography.bodyMd(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _enCours ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ActionButton(
          label: 'Enregistrer',
          expand: false,
          height: 44,
          isLoading: _enCours,
          onPressed: _enCours ? null : _enregistrer,
        ),
      ],
    );
  }
}
