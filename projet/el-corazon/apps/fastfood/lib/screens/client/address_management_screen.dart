import 'dart:math';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/services/location_service.dart';
import 'package:elcora_fast/utils/address_sorting.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/address_card.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/loading_widget.dart' as etats;
import 'package:elcora_fast/screens/client/address_detail_bottom_sheet.dart';

// `AddressSortType` et l'ordre d'affichage vivent désormais dans
// `utils/address_sorting.dart` — une fonction pure, donc testable, ce que le
// tri ne pouvait pas être tant qu'il était enfermé dans l'état de cet écran.
export 'package:elcora_fast/utils/address_sorting.dart' show AddressSortType;

class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  State<AddressManagementScreen> createState() =>
      _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  final AddressService _addressService = AddressService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  AddressSortType _sortType = AddressSortType.recent;

  /// Un relevé de position est en cours pour le tri par distance.
  bool _releveDePositionEnCours = false;
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Efface la recherche — champ **et** filtre.
  ///
  /// Le `TextField` n'avait pas de contrôleur : la croix et la puce de filtre
  /// remettaient `_searchQuery` à vide, mais le texte restait affiché. Le
  /// client voyait sa recherche à l'écran et la liste complète en dessous.
  void _clearSearch() {
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
      appBar: _barre(theme),
      body: Consumer<AddressService>(
        builder: (context, addressService, child) {
          // Le carnet vit côté serveur : sans session il n'y en a pas, et le
          // formulaire d'ajout mènerait à un refus. Le dire ici évite de faire
          // saisir une adresse pour rien.
          if (!addressService.canEdit) return _etatDeconnecte(theme);

          if (!addressService.hasAddresses) return _etatVide();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: _contenu(theme, addressService),
          );
        },
      ),
      bottomNavigationBar: Consumer<AddressService>(
        builder: (context, addressService, child) {
          if (!addressService.canEdit || !addressService.hasAddresses) {
            return const SizedBox.shrink();
          }
          // La maquette place « Add New Address » en bas de la liste. Une
          // barre ancrée plutôt qu'un bouton flottant : le bouton flottant
          // masquait la dernière carte, celle qu'on vient justement d'ajouter.
          return GlassBottomBar(
            child: ActionButton(
              label: 'Ajouter une adresse',
              emphasis: ActionEmphasis.gradient,
              icon: Icons.add_location_alt_outlined,
              onPressed: _showAddAddressSheet,
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _barre(ThemeData theme) {
    return GlassAppBar(
      title: 'Mes adresses',
      actions: [
        GlassIconButton(
          icon: _favoritesOnly ? Icons.star_rounded : Icons.star_outline_rounded,
          tooltip: _favoritesOnly ? 'Toutes les adresses' : 'Favoris seulement',
          filled: false,
          color: _favoritesOnly ? AppColors.secondaryDeep : null,
          onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly),
        ),
        PopupMenuButton<AddressSortType>(
          onSelected: _choisirTri,
          // Relever une position prend une à deux secondes, et davantage au
          // premier appel, quand le système demande l'autorisation. Sans ce
          // témoin, le menu se refermait sur une liste inchangée et le geste
          // paraissait ignoré.
          icon: _releveDePositionEnCours
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation(theme.colorScheme.primary),
                  ),
                )
              : Icon(Icons.sort_rounded, color: theme.colorScheme.primary),
          tooltip: 'Trier',
          itemBuilder: (context) => [
            _entreeDeTri(
              AddressSortType.recent,
              'Récemment utilisées',
              Icons.schedule_rounded,
            ),
            _entreeDeTri(
              AddressSortType.name,
              'Nom (A–Z)',
              Icons.sort_by_alpha_rounded,
            ),
            _entreeDeTri(
              AddressSortType.distance,
              'Distance',
              Icons.straighten_rounded,
            ),
            _entreeDeTri(
              AddressSortType.type,
              'Type',
              Icons.category_outlined,
            ),
          ],
        ),
      ],
    );
  }

  PopupMenuEntry<AddressSortType> _entreeDeTri(
    AddressSortType type,
    String libelle,
    IconData icone,
  ) {
    final retenu = _sortType == type;
    final theme = Theme.of(context);

    return PopupMenuItem(
      value: type,
      child: Row(
        children: [
          Icon(
            icone,
            size: DesignConstants.iconSizeSmall + 4,
            color: retenu ? theme.colorScheme.primary : null,
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: Text(
              libelle,
              style: retenu
                  ? AppTypography.labelLg(color: theme.colorScheme.primary)
                  : null,
            ),
          ),
          if (retenu)
            Icon(
              Icons.check_rounded,
              size: DesignConstants.iconSizeSmall + 4,
              color: theme.colorScheme.primary,
            ),
        ],
      ),
    );
  }

  Widget _etatDeconnecte(ThemeData theme) {
    return etats.EmptyStateWidget(
      title: 'Connectez-vous',
      message: 'Votre carnet d’adresses est rattaché à votre compte : '
          'il vous suit d’un appareil à l’autre.',
      icon: Icons.lock_outline_rounded,
      actionText: 'Se connecter',
      onAction: () => NavigationService.navigateToAuth(context),
    );
  }

  Widget _etatVide() {
    return etats.EmptyStateWidget(
      title: 'Aucune adresse enregistrée',
      message: 'Ajoutez-en une pour commander en deux gestes la prochaine fois.',
      icon: Icons.location_off_outlined,
      actionText: 'Ajouter une adresse',
      onAction: _showAddAddressSheet,
    );
  }

  Widget _contenu(ThemeData theme, AddressService addressService) {
    var addresses = _filterAddresses(addressService.addresses);
    addresses = _sortAddresses(addresses);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DesignConstants.edgeMargin,
        DesignConstants.spacingM,
        DesignConstants.edgeMargin,
        DesignConstants.spacingXL,
      ),
      children: [
        Text(
          'Gérez où vos plats sont livrés.',
          style: AppTypography.bodyLg(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: DesignConstants.spacingM),
        _reperes(theme, addressService),
        // Le seuil était de « plus de 3 adresses » : sous ce nombre, une
        // recherche déjà saisie restait active sans plus aucun moyen de
        // l'effacer, et la liste semblait vide sans raison visible.
        if (addressService.addresses.length > 3 || _searchQuery.isNotEmpty) ...[
          const SizedBox(height: DesignConstants.spacingM),
          AppSearchField(
            controller: _searchController,
            hintText: 'Nom, quartier, repère…',
            onChanged: (value) => setState(() => _searchQuery = value),
            trailing: _searchQuery.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Effacer la recherche',
                    onPressed: _clearSearch,
                  ),
          ),
        ],
        if (_hasActiveFilters) ...[
          const SizedBox(height: DesignConstants.spacingM),
          _puceDeFiltres(theme),
        ],
        const SizedBox(height: DesignConstants.spacingM),
        if (addresses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: DesignConstants.spacingXL,
            ),
            child: etats.EmptyStateWidget(
              title: 'Aucune adresse ne correspond',
              message: 'Modifiez votre recherche ou vos filtres.',
              icon: Icons.search_off_rounded,
              actionText: 'Tout afficher',
              onAction: () => setState(() {
                _clearSearch();
                _favoritesOnly = false;
              }),
            ),
          )
        else
          for (final address in addresses)
            AddressCard(
              address: address,
              isFavorite: addressService.estFavorite(address.id ?? ''),
              isSelected: addressService.selectedAddress?.id == address.id,
              onTap: () => _selectAddress(address),
              onEdit: () => _showEditAddressSheet(address),
              onDelete: () => _deleteAddress(address),
              onToggleFavorite: () => _toggleFavorite(address),
              onSetDefault: () => _setDefault(address),
            ),
      ],
    );
  }

  /// Trois repères en puces, là où une carte dégradée occupait 90 px.
  ///
  /// L'information — combien d'adresses, combien de favorites, y a-t-il une
  /// adresse par défaut — ne justifiait pas un bandeau à deux couleurs au-dessus
  /// de la liste qu'on vient consulter.
  Widget _reperes(ThemeData theme, AddressService addressService) {
    final total = addressService.addresses.length;
    final favorites = addressService.favoriteAddresses.length;
    final aUnDefaut = addressService.defaultAddress != null;

    return Wrap(
      spacing: DesignConstants.spacingS,
      runSpacing: DesignConstants.spacingS,
      children: [
        StatusChip(
          label: total <= 1 ? '$total adresse' : '$total adresses',
          icon: Icons.location_on_outlined,
          background: theme.colorScheme.surfaceContainerHigh,
          foreground: theme.colorScheme.onSurfaceVariant,
        ),
        if (favorites > 0)
          StatusChip(
            label: favorites <= 1 ? '$favorites favorite' : '$favorites favorites',
            icon: Icons.star_rounded,
            background: theme.colorScheme.secondaryContainer,
            foreground: theme.colorScheme.onSecondaryContainer,
          ),
        // Pas de puce « 0 défaut » : l'absence se signale, elle ne se compte
        // pas. Quand aucune adresse n'est par défaut, c'est cela qu'il faut
        // dire — et c'est utile, car le règlement en réclamera une.
        if (!aUnDefaut && total > 0)
          StatusChip(
            label: 'Aucune adresse par défaut',
            icon: Icons.info_outline_rounded,
            background: theme.colorScheme.errorContainer,
            foreground: theme.colorScheme.onErrorContainer,
          ),
      ],
    );
  }

  bool get _hasActiveFilters => _searchQuery.isNotEmpty || _favoritesOnly;

  Widget _puceDeFiltres(ThemeData theme) {
    return Wrap(
      spacing: DesignConstants.spacingS,
      runSpacing: DesignConstants.spacingS,
      children: [
        if (_searchQuery.isNotEmpty)
          InputChip(
            label: Text('« $_searchQuery »'),
            onDeleted: _clearSearch,
          ),
        if (_favoritesOnly)
          InputChip(
            label: const Text('Favoris'),
            onDeleted: () => setState(() => _favoritesOnly = false),
          ),
      ],
    );
  }

  List<eccore.Address> _filterAddresses(List<eccore.Address> addresses) {
    var filtered = addresses;

    if (_searchQuery.isNotEmpty) {
      filtered = _addressService.searchAddresses(_searchQuery);
    }

    if (_favoritesOnly) {
      filtered = filtered
          .where((a) => _addressService.estFavorite(a.id ?? ''))
          .toList();
    }

    return filtered;
  }

  /// Applique le tri choisi.
  ///
  /// Le tri par distance a besoin de la position de l'appareil. Elle n'était
  /// jamais demandée ici : si rien ne l'avait relevée auparavant — permission
  /// refusée, ou simple fait de n'avoir pas encore ouvert la carte —, l'option
  /// se cochait dans le menu et **l'ordre ne changeait pas d'une ligne**, sans
  /// un mot d'explication. On la demande maintenant au moment où elle sert, et
  /// on dit pourquoi quand on ne l'obtient pas.
  Future<void> _choisirTri(AddressSortType type) async {
    if (type != AddressSortType.distance ||
        _locationService.currentPosition != null) {
      setState(() => _sortType = type);
      return;
    }

    setState(() => _releveDePositionEnCours = true);
    final position = await _locationService.getCurrentLocation();
    if (!mounted) return;

    setState(() {
      _releveDePositionEnCours = false;
      if (position != null) _sortType = type;
    });

    if (position == null) {
      _signaler('Autorisez la localisation pour trier par distance.');
    }
  }

  List<eccore.Address> _sortAddresses(List<eccore.Address> addresses) {
    // `LocationService` est un singleton : cette position est celle relevée
    // par le reste de l'application. L'écran en construisait auparavant une
    // instance neuve, dont `currentPosition` valait toujours `null` — le tri
    // par distance ne triait donc jamais.
    final origin = _locationService.currentPosition;

    return sortAddressesForDisplay(
      addresses,
      sortType: _sortType,
      distanceFrom: origin == null ? null : (a) => _distanceFrom(origin, a),
    );
  }

  /// Distance à vol d'oiseau, en kilomètres.
  double _distanceFrom(Position origin, eccore.Address address) {
    return _calculateDistance(
      origin.latitude,
      origin.longitude,
      address.latitude,
      address.longitude,
    );
  }

  /// Recharge le carnet depuis le serveur.
  ///
  /// Appelait `initialize()`, qui sort immédiatement une fois le service
  /// initialisé : le geste « tirer pour rafraîchir » animait son indicateur
  /// sans jamais rien recharger.
  Future<void> _refresh() async {
    await _addressService.refresh();
  }

  void _showAddAddressSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressDetailBottomSheet(
        onSave: (draft) async {
          await _addressService.addAddress(draft);
          if (mounted) _annoncer('Adresse ajoutée');
        },
      ),
    );
  }

  void _showEditAddressSheet(eccore.Address address) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressDetailBottomSheet(
        address: address,
        onSave: (draft) async {
          await _addressService.updateAddress(address.id!, draft);
          if (mounted) _annoncer('Adresse modifiée');
        },
      ),
    );
  }

  // Ces trois actions étaient lancées sans être attendues : leur échec
  // remontait en exception non capturée, et le message de confirmation
  // s'affichait de toute façon — y compris quand rien n'avait été enregistré.

  Future<void> _selectAddress(eccore.Address address) async {
    try {
      await _addressService.selectAddress(address.id!);
      if (mounted) {
        _annoncer('Adresse sélectionnée : ${address.label}');
      }
    } catch (e) {
      if (mounted) _signaler(_messageFor(e));
    }
  }

  Future<void> _toggleFavorite(eccore.Address address) async {
    try {
      await _addressService.toggleFavorite(address.id!);
    } catch (e) {
      if (mounted) _signaler(_messageFor(e));
    }
  }

  Future<void> _setDefault(eccore.Address address) async {
    try {
      await _addressService.setDefaultAddress(address.id!);
      if (mounted) {
        _annoncer('${address.label} est votre adresse par défaut');
      }
    } catch (e) {
      if (mounted) _signaler(_messageFor(e));
    }
  }

  /// Message destiné au client.
  ///
  /// Les écrans affichaient `'Erreur : $e'`, ce qui met un `DioException` ou
  /// une trace d'exception sous les yeux de quelqu'un qui voulait enregistrer
  /// son adresse. Le serveur, lui, renvoie déjà une phrase utilisable
  /// (RFC 9457, champ `detail`) — c'est elle qu'on montre.
  String _messageFor(Object error) {
    if (error is AddressSessionRequired) return error.toString();
    if (error is eccore.ApiException) return error.detail;
    return 'Opération impossible pour le moment. Réessayez.';
  }

  /// Annonce une réussite.
  ///
  /// L'ancienne signature était `_showSnack(String, Color)` : chaque appelant
  /// choisissait un vert, un rouge ou un orange de Material, et un
  /// « Adresse supprimée » se retrouvait en orange quand un
  /// « Adresse ajoutée » était en vert, sans que rien ne le justifie. Nommer
  /// l'intention plutôt que la teinte laisse le design system trancher.
  void _annoncer(String message) {
    if (!mounted) return;
    context.showSuccessMessage(message);
  }

  void _signaler(String message) {
    if (!mounted) return;
    context.showErrorMessage(message);
  }

  /// Confirme avant de supprimer.
  ///
  /// Le geste était immédiat et sans retour en arrière : une adresse saisie
  /// avec son repère disparaissait sur une pression, et la suppression est
  /// dure côté serveur (droit à l'effacement — `AddressViewSet`), donc
  /// définitive.
  Future<void> _deleteAddress(eccore.Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.delete_outline_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Supprimer cette adresse ?'),
        content: Text('« ${address.label} » sera définitivement effacée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _addressService.deleteAddress(address.id!);
      if (mounted) {
        _annoncer('Adresse supprimée : ${address.label}');
      }
    } catch (e) {
      if (mounted) _signaler(_messageFor(e));
    }
  }

  /// Calcule la distance en kilomètres entre deux points GPS
  /// Utilise la formule de Haversine pour calculer la distance
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Rayon de la Terre en km

    // Convertir les degrés en radians
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = earthRadius * c;

    return distance;
  }

  /// Convertit des degrés en radians
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}
