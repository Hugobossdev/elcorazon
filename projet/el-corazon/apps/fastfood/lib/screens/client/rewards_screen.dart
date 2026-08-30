import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/fidelite.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/services/gamification_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

/// Programme de fidélité — solde, palier, récompenses, relevé de points.
///
/// ## Ce que la maquette demande, et ce que le serveur sert
///
/// `rewards` montre une carte de palier avec la progression vers le suivant,
/// une liste de récompenses avec un bouton « Redeem » ou une mention
/// « Locked », et un relevé de points. **Tout cela existe réellement** :
///
/// * `GET /loyalty/account/` → solde ;
/// * `GET /loyalty/rewards/` → catalogue, avec son coût en points ;
/// * `POST /loyalty/rewards/{id}/redeem/` → échange ;
/// * `GET /loyalty/entries/` → le relevé, avec `delta`, `description`,
///   `orderId` et l'horodatage — c'est exactement le « +120 pts /
///   Order #ELC-492 » de la maquette.
///
/// Seuls les **paliers** sont calculés côté client (BR-006). Les noms de la
/// maquette — « Gold », « Platinum (3000 pts) » — ne sont pas repris : ils ne
/// correspondent à aucun seuil en place, et les inventer ferait une promesse
/// commerciale que le serveur ne connaît pas.
///
/// ## Ce qui est conservé de l'ancien écran
///
/// Les badges et le niveau ne figurent dans aucune maquette, mais ils existent
/// et viennent du serveur. Ils restent, rangés après ce que la maquette met en
/// avant.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    if (!mounted) return;
    try {
      final gamification =
          Provider.of<GamificationService>(context, listen: false);
      final appService = Provider.of<AppService>(context, listen: false);
      await gamification.initialize(
        userId: appService.currentUser?.id,
        forceRefresh: true,
      );
    } catch (e) {
      Journal.trace('Error initializing Gamification service: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: const GlassAppBar(title: 'Récompenses'),
      body: Consumer<GamificationService>(
        builder: (context, gamification, child) {
          return RefreshIndicator(
            onRefresh: _charger,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                DesignConstants.edgeMargin,
                DesignConstants.spacingM,
                DesignConstants.edgeMargin,
                DesignConstants.spacingXL,
              ),
              children: [
                Text(
                  'Votre fidélité, généreusement rendue.',
                  style: AppTypography.bodyLg(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DesignConstants.spacingM),
                _carteDePalier(theme, gamification),
                const SizedBox(height: DesignConstants.spacingL),
                _sectionRecompenses(theme, gamification),
                const SizedBox(height: DesignConstants.spacingL),
                _sectionReleve(theme, gamification),
                if (gamification.badges.isNotEmpty) ...[
                  const SizedBox(height: DesignConstants.spacingL),
                  _sectionBadges(theme, gamification),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------- le palier

  Widget _carteDePalier(ThemeData theme, GamificationService gamification) {
    final points = gamification.currentPoints;
    final avancement = avancementDeFidelite(points);

    // Le dégradé doré porte une encre sombre : `onSecondaryContainer` tient le
    // contraste dessus, du blanc non.
    final encre = theme.colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.all(DesignConstants.spacingL),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.secondaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DesignConstants.borderRadiusLarge,
        boxShadow: DesignConstants.shadowLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: encre),
              const SizedBox(width: DesignConstants.spacingS),
              Expanded(
                child: Text(
                  'Palier ${avancement.palier.libelle}',
                  style: AppTypography.titleLg(color: encre),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignConstants.spacingM),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  '$points',
                  style: AppTypography.displayLg(color: encre),
                ),
              ),
              const SizedBox(width: DesignConstants.spacingS),
              Text('pts', style: AppTypography.titleLg(color: encre)),
            ],
          ),
          const SizedBox(height: DesignConstants.spacingM),
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignConstants.radiusSmall),
            child: LinearProgressIndicator(
              value: avancement.progression,
              minHeight: 8,
              backgroundColor: encre.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(encre),
            ),
          ),
          const SizedBox(height: DesignConstants.spacingS),
          Text(
            avancement.suivant == null
                ? 'Vous êtes au palier le plus élevé.'
                : '${avancement.pointsManquants} points jusqu’au palier '
                    '${avancement.suivant!.libelle}',
            style: AppTypography.bodyMd(color: encre),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------- les récompenses

  Widget _sectionRecompenses(
    ThemeData theme,
    GamificationService gamification,
  ) {
    final recompenses = gamification.rewards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Récompenses'),
        const SizedBox(height: DesignConstants.spacingS),
        if (recompenses.isEmpty)
          SectionCard(
            child: Text(
              'Aucune récompense proposée pour le moment.',
              style: AppTypography.bodyMd(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final recompense in recompenses)
            Padding(
              padding: const EdgeInsets.only(bottom: DesignConstants.spacingM),
              child: _carteDeRecompense(theme, gamification, recompense),
            ),
      ],
    );
  }

  Widget _carteDeRecompense(
    ThemeData theme,
    GamificationService gamification,
    eccore.Reward recompense,
  ) {
    final accessible = recompense.estAccessibleAvec(gamification.currentPoints);
    final enCours = gamification.isRewardBeingProcessed(recompense.id);
    final manquants = recompense.pointsCost - gamification.currentPoints;

    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: DesignConstants.avatarSizeMedium,
            height: DesignConstants.avatarSizeMedium,
            decoration: BoxDecoration(
              color: accessible
                  ? theme.colorScheme.secondaryContainer
                  : theme.colorScheme.surfaceContainerHigh,
              borderRadius: DesignConstants.borderRadiusMedium,
            ),
            child: Icon(
              recompense.genre == GenreRecompense.livraisonOfferte
                  ? Icons.two_wheeler_rounded
                  : Icons.local_offer_rounded,
              color: accessible
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onSurfaceVariant,
              size: DesignConstants.iconSizeMedium,
            ),
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recompense.name,
                  style: AppTypography.titleLg(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (recompense.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    recompense.description,
                    style: AppTypography.bodyMd(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: DesignConstants.spacingS),
                Wrap(
                  spacing: DesignConstants.spacingS,
                  runSpacing: DesignConstants.spacingS,
                  children: [
                    StatusChip(
                      label: '${recompense.pointsCost} pts',
                      icon: Icons.stars_rounded,
                      background: theme.colorScheme.surfaceContainerHigh,
                      foreground: theme.colorScheme.onSurfaceVariant,
                    ),
                    if (recompense.remiseAffichee > 0)
                      StatusChip(
                        label: PriceFormatter.format(recompense.remiseAffichee),
                        icon: Icons.savings_outlined,
                        background: theme.colorScheme.surfaceContainerHigh,
                        foreground: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
                const SizedBox(height: DesignConstants.spacingM),
                // « Locked » de la maquette, mais en disant **ce qui manque** :
                // un cadenas seul laisse chercher combien il faut de points.
                if (accessible)
                  ActionButton(
                    label: 'Échanger',
                    height: 44,
                    isLoading: enCours,
                    onPressed: enCours
                        ? null
                        : () => _confirmerEchange(gamification, recompense),
                  )
                else
                  Text(
                    'Encore $manquants point${manquants > 1 ? 's' : ''} '
                    'pour y accéder',
                    style: AppTypography.labelLg(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmerEchange(
    GamificationService gamification,
    eccore.Reward recompense,
  ) {
    context.showEnhancedDialog(
      title: 'Échanger cette récompense ?',
      content: '« ${recompense.name} » vous coûtera '
          '${recompense.pointsCost} points. '
          'Il vous en restera '
          '${gamification.currentPoints - recompense.pointsCost}.',
      confirmText: 'Échanger',
      cancelText: 'Annuler',
      onConfirm: () async {
        final reussi = await gamification.redeemReward(recompense);
        if (!mounted) return;
        // Le message suit le **résultat du serveur**, jamais l'intention : un
        // solde devenu insuffisant entre l'affichage et l'appel, ou une
        // récompense retirée du catalogue, sortent en échec.
        if (reussi) {
          context.showSuccessMessage('« ${recompense.name} » vous est acquise');
        } else {
          context.showErrorMessage(
            'Échange refusé. Vérifiez votre solde et réessayez.',
          );
        }
      },
      onCancel: () {},
    );
  }

  // -------------------------------------------------------------- le relevé

  Widget _sectionReleve(ThemeData theme, GamificationService gamification) {
    final mouvements = gamification.transactions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Relevé de points'),
        const SizedBox(height: DesignConstants.spacingS),
        if (mouvements.isEmpty)
          SectionCard(
            child: Text(
              'Aucun mouvement pour l’instant. Vos points apparaîtront ici '
              'après votre première commande livrée.',
              style: AppTypography.bodyMd(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < mouvements.length; i++) ...[
                  _ligneDeMouvement(theme, mouvements[i]),
                  if (i < mouvements.length - 1)
                    Divider(
                      height: 1,
                      indent: DesignConstants.spacingXL +
                          DesignConstants.spacingL,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _ligneDeMouvement(ThemeData theme, eccore.PointsEntry mouvement) {
    final credite = mouvement.genre.crediteLeCompte;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DesignConstants.spacingM,
        vertical: DesignConstants.spacingXS,
      ),
      leading: Container(
        width: DesignConstants.avatarSizeSmall + 8,
        height: DesignConstants.avatarSizeSmall + 8,
        decoration: BoxDecoration(
          color: credite
              ? AppColors.successLight
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: DesignConstants.borderRadiusSmall,
        ),
        child: Icon(
          credite ? Icons.add_rounded : Icons.redeem_rounded,
          size: DesignConstants.iconSizeSmall + 4,
          color: credite ? AppColors.success : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        mouvement.description.isEmpty
            ? mouvement.genre.libelle
            : mouvement.description,
        style: AppTypography.titleLg(color: theme.colorScheme.onSurface),
      ),
      subtitle: Text(
        _dateCourte(mouvement.createdAt),
        style: AppTypography.bodyMd(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Text(
        mouvement.deltaAffiche,
        style: AppTypography.priceDisplay(
          color: credite ? AppColors.success : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  // -------------------------------------------------------------- les badges

  Widget _sectionBadges(ThemeData theme, GamificationService gamification) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Badges',
          subtitle: 'Débloqués par le serveur à la livraison de vos commandes',
        ),
        const SizedBox(height: DesignConstants.spacingS),
        SectionCard(
          child: Wrap(
            spacing: DesignConstants.spacingS,
            runSpacing: DesignConstants.spacingS,
            children: [
              for (final badge in gamification.badges)
                StatusChip(
                  label: badge['title']?.toString() ?? '',
                  icon: badge['isUnlocked'] == true
                      ? Icons.military_tech_rounded
                      : Icons.lock_outline_rounded,
                  background: badge['isUnlocked'] == true
                      ? theme.colorScheme.secondaryContainer
                      : theme.colorScheme.surfaceContainerHigh,
                  foreground: badge['isUnlocked'] == true
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// « 12/03 » ou « Aujourd'hui », selon l'ancienneté.
  String _dateCourte(DateTime date) {
    final maintenant = DateTime.now();
    final jour = DateTime(date.year, date.month, date.day);
    final aujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final ecart = aujourdhui.difference(jour).inDays;

    if (ecart == 0) return 'Aujourd’hui';
    if (ecart == 1) return 'Hier';

    final j = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return ecart < 365 ? '$j/$m' : '$j/$m/${date.year}';
  }
}
