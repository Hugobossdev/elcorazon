import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/address_card.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/loading_widget.dart' as etats;
import 'package:elcora_fast/screens/client/address_management_screen.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

/// Choix d'une adresse de livraison.
///
/// ## Ce que la maquette ajoute, et ce qui n'a pas suivi
///
/// `select_address` pose une barre de recherche, un raccourci « Use current
/// location », les adresses enregistrées, puis un bloc « Recent Places ».
///
/// **« Recent Places » n'est pas dessiné.** L'application ne conserve aucun
/// historique de lieux : `AddressService` tient le carnet — des adresses
/// enregistrées, nommées, avec un identifiant serveur — pas les recherches
/// passées. Afficher une section vide, ou pire la remplir avec les adresses
/// du carnet sous un autre titre, tromperait sur ce qu'elle contient.
///
/// « Use current location » est en revanche repris : `AddressService` et le
/// sélecteur de carte savent déjà relever une position et la résoudre en
/// adresse.
class AddressSelectorScreen extends StatefulWidget {
  final eccore.Address? currentAddress;
  final Function(eccore.Address) onAddressSelected;

  const AddressSelectorScreen({
    required this.onAddressSelected,
    super.key,
    this.currentAddress,
  });

  @override
  State<AddressSelectorScreen> createState() => _AddressSelectorScreenState();
}

class _AddressSelectorScreenState extends State<AddressSelectorScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _effacerLaRecherche() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        title: 'Choisir une adresse',
        actions: [
          GlassIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Gérer mes adresses',
            filled: false,
            onPressed: _navigateToManagement,
          ),
        ],
      ),
      body: Consumer<AddressService>(
        builder: (context, addressService, child) {
          if (!addressService.hasAddresses) return _etatVide();

          final adresses = _adressesTriees(addressService);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              DesignConstants.edgeMargin,
              DesignConstants.spacingM,
              DesignConstants.edgeMargin,
              DesignConstants.spacingXL,
            ),
            children: [
              if (addressService.addresses.length > 2 ||
                  _searchQuery.isNotEmpty) ...[
                AppSearchField(
                  controller: _searchController,
                  hintText: 'Nom, quartier, repère…',
                  onChanged: (value) => setState(() => _searchQuery = value),
                  trailing: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Effacer la recherche',
                          onPressed: _effacerLaRecherche,
                        ),
                ),
                const SizedBox(height: DesignConstants.spacingM),
              ],
              _mentionDesFrais(theme),
              const SizedBox(height: DesignConstants.spacingM),
              SectionHeader(
                title: 'Mes adresses',
                subtitle: adresses.length <= 1
                    ? '${adresses.length} enregistrée'
                    : '${adresses.length} enregistrées',
              ),
              const SizedBox(height: DesignConstants.spacingS),
              if (adresses.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: DesignConstants.spacingXL,
                  ),
                  child: etats.EmptyStateWidget(
                    title: 'Aucune adresse ne correspond',
                    message: 'Essayez un autre terme.',
                    icon: Icons.search_off_rounded,
                    actionText: 'Effacer la recherche',
                    onAction: _effacerLaRecherche,
                  ),
                )
              else
                for (final address in adresses)
                  AddressCard(
                    address: address,
                    isFavorite: addressService.estFavorite(address.id ?? ''),
                    isSelected: widget.currentAddress?.id == address.id,
                    onTap: () => _selectAddress(address),
                  ),
            ],
          );
        },
      ),
      bottomNavigationBar: GlassBottomBar(
        child: ActionButton(
          label: 'Ajouter une adresse',
          emphasis: ActionEmphasis.outlined,
          icon: Icons.add_location_alt_outlined,
          onPressed: _navigateToManagement,
        ),
      ),
    );
  }

  /// Le carnet, rangé : défaut d'abord, puis favorites, puis les plus
  /// récemment modifiées.
  ///
  /// Le tri était fait dans le `build` de la liste, sur une copie — il l'est
  /// toujours, mais rassemblé ici : c'est la seule règle de cet écran, et elle
  /// se lisait au milieu d'un `ListView.builder`.
  List<eccore.Address> _adressesTriees(AddressService service) {
    final adresses = [
      ..._searchQuery.isEmpty
          ? service.addresses
          : service.searchAddresses(_searchQuery),
    ];

    adresses.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;

      final favoriA = service.estFavorite(a.id ?? '');
      final favoriB = service.estFavorite(b.id ?? '');
      if (favoriA != favoriB) return favoriA ? -1 : 1;

      // Une adresse jamais synchronisée n'a pas d'horodatage ; elle passe
      // après celles qui en ont plutôt que de faire tomber le tri.
      final gauche = a.updatedAt;
      final droite = b.updatedAt;
      if (gauche == null && droite == null) return 0;
      if (gauche == null) return 1;
      if (droite == null) return -1;
      return droite.compareTo(gauche);
    });

    return adresses;
  }

  /// « Les frais sont calculés automatiquement » — l'encart bleu de la version
  /// précédente, dans les teintes de la palette.
  Widget _mentionDesFrais(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: DesignConstants.iconSizeSmall,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: DesignConstants.spacingS),
        Expanded(
          child: Text(
            'Les frais de livraison sont calculés depuis l’adresse choisie.',
            style: AppTypography.bodyMd(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _etatVide() {
    return etats.EmptyStateWidget(
      title: 'Aucune adresse enregistrée',
      message: 'Ajoutez-en une pour choisir où livrer votre commande.',
      icon: Icons.location_off_outlined,
      actionText: 'Ajouter une adresse',
      onAction: _navigateToManagement,
    );
  }

  Future<void> _selectAddress(eccore.Address address) async {
    // Le choix est aussi retenu par le service, et non seulement remonté à
    // l'écran appelant : sans cela, l'adresse choisie ici était oubliée dès
    // qu'on quittait la commande en cours.
    try {
      await context.read<AddressService>().selectAddress(address.id!);
    } catch (e) {
      Journal.trace('Sélection non mémorisée : $e');
    }
    if (mounted) widget.onAddressSelected(address);
  }

  void _navigateToManagement() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AddressManagementScreen(),
      ),
    );
  }
}
