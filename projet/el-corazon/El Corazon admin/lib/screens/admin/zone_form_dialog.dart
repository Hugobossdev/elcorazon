import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/services/delivery_zone_service.dart';
import 'package:admin/widgets/custom_button.dart';
import 'package:admin/widgets/custom_text_field.dart';

/// Édition du barème d'une zone de livraison.
///
/// C'est le seul endroit du produit où se décide ce que paiera un client pour
/// être livré. Le barème vit en **donnée** justement pour cela : ouvrir un
/// quartier, relever un forfait ou offrir la livraison au-dessus d'un montant
/// se font ici, sans republier trois applications.
///
/// Le **seuil de franco** est le champ que cet écran n'exposait pas. Il
/// existait en base et dans l'API depuis l'origine, mais aucune interface ne
/// permettait de le lire ni de le changer : une zone qui offrait la livraison
/// au-dessus de 10 000 F l'offrait jusqu'à ce qu'un développeur passe en base.
/// Il se **retire** aussi, ce qui demande d'envoyer un `null` explicite — d'où
/// l'interrupteur plutôt qu'un champ vide, qui se confondrait avec « ne pas y
/// toucher ».
///
/// La devise n'est pas saisie : elle est héritée du pays (ADR-006) et le
/// serveur refuse un montant libellé autrement. L'écran l'affiche pour que
/// l'exploitant sache dans quelle unité il tape.
class ZoneFormDialog extends StatefulWidget {
  const ZoneFormDialog({required this.zone, super.key});

  final DeliveryZone zone;

  /// Ouvre le formulaire et rend `true` si la zone a été enregistrée.
  static Future<bool> show(BuildContext context, DeliveryZone zone) async {
    final enregistre = await showDialog<bool>(
      context: context,
      builder: (_) => ZoneFormDialog(zone: zone),
    );
    return enregistre ?? false;
  }

  @override
  State<ZoneFormDialog> createState() => _ZoneFormDialogState();
}

class _ZoneFormDialogState extends State<ZoneFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _feeController = TextEditingController();
  final _freeThresholdController = TextEditingController();
  final _estimatedTimeController = TextEditingController();

  late bool _isActive;
  late bool _hasFreeDelivery;
  bool _isSaving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    final zone = widget.zone;
    _nameController.text = zone.name;
    _feeController.text = _montant(zone.deliveryFee);
    _estimatedTimeController.text = '${zone.estimatedTimeMinutes}';
    _isActive = zone.isActive;
    _hasFreeDelivery = zone.hasFreeDelivery;
    _freeThresholdController.text =
        zone.freeDeliveryThreshold == null ? '' : _montant(zone.freeDeliveryThreshold!);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _feeController.dispose();
    _freeThresholdController.dispose();
    _estimatedTimeController.dispose();
    super.dispose();
  }

  /// Un franc CFA n'a pas de décimale, un euro en a deux. Afficher « 600,00 »
  /// sur un barème en francs inviterait à saisir des centimes qui n'existent
  /// pas.
  String _montant(double valeur) =>
      valeur == valeur.roundToDouble() ? valeur.toStringAsFixed(0) : valeur.toStringAsFixed(2);

  /// Libellé usuel de la devise. `XOF` est le code ISO ; « FCFA » est ce que
  /// lit l'exploitant sur ses tickets.
  String get _devise => widget.zone.currency == 'XOF' ? 'FCFA' : widget.zone.currency;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 640.0);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: dialogWidth,
          maxWidth: dialogWidth,
          maxHeight: screenSize.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(key: _formKey, child: _buildForm(context)),
              ),
            ),
            const Divider(height: 1),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Barème de la zone',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Montants en $_devise',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          label: 'Nom de la zone',
          controller: _nameController,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Le nom est obligatoire';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        CustomTextField(
          label: 'Frais de livraison ($_devise)',
          hint: 'Forfait de base de la zone',
          controller: _feeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: Icons.monetization_on,
          validator: (value) => _validerMontant(value, obligatoire: true),
        ),
        const SizedBox(height: 8),
        Text(
          'Le client paie ce forfait plus ${_montant(widget.zone.feePerKm)} $_devise '
          'par kilomètre. Le total est calculé par le serveur au moment de la commande.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),

        // --- seuil de franco -------------------------------------------
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _hasFreeDelivery,
                  onChanged: (actif) => setState(() {
                    _hasFreeDelivery = actif;
                    if (!actif) _freeThresholdController.clear();
                  }),
                  title: const Text(
                    'Livraison offerte au-delà d’un montant',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _hasFreeDelivery
                        ? 'Les frais tombent à zéro dès que le panier atteint le seuil.'
                        : 'La livraison est facturée quel que soit le montant du panier.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                if (_hasFreeDelivery) ...[
                  const SizedBox(height: 8),
                  CustomTextField(
                    label: 'Seuil de gratuité ($_devise)',
                    hint: 'Par exemple 12000',
                    controller: _freeThresholdController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    prefixIcon: Icons.card_giftcard,
                    validator: (value) => _validerMontant(value, obligatoire: true),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        CustomTextField(
          label: 'Temps de livraison estimé (minutes)',
          controller: _estimatedTimeController,
          keyboardType: TextInputType.number,
          prefixIcon: Icons.schedule,
          validator: _validerDelai,
        ),
        const SizedBox(height: 16),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _isActive,
          onChanged: (actif) => setState(() => _isActive = actif),
          title: const Text('Zone active', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            _isActive
                ? 'La zone est desservie et apparaît aux clients.'
                : 'La zone n’est plus desservie. Les commandes déjà passées gardent '
                    'leurs frais.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),

        if (_serverError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _serverError!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
          ),
          const SizedBox(width: 12),
          CustomButton(
            text: 'Enregistrer',
            onPressed: _isSaving ? null : _save,
            isLoading: _isSaving,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ validations

  /// Un montant : nombre, positif, et pas de centimes sur une devise qui n'en
  /// a pas. La virgule est acceptée — c'est la touche du clavier français, et
  /// la refuser transformerait une habitude en erreur de saisie.
  String? _validerMontant(String? valeur, {required bool obligatoire}) {
    final texte = (valeur ?? '').trim();
    if (texte.isEmpty) {
      return obligatoire ? 'Montant obligatoire' : null;
    }

    final montant = double.tryParse(texte.replaceAll(',', '.'));
    if (montant == null) return 'Entrez un montant en chiffres';
    if (montant < 0) return 'Le montant ne peut pas être négatif';
    if (montant > 10000000) return 'Montant hors des ordres de grandeur attendus';

    if (widget.zone.currency == 'XOF' && montant != montant.roundToDouble()) {
      return 'Le franc CFA n’a pas de centimes';
    }
    return null;
  }

  String? _validerDelai(String? valeur) {
    final texte = (valeur ?? '').trim();
    if (texte.isEmpty) return 'Temps estimé obligatoire';

    final minutes = int.tryParse(texte);
    if (minutes == null) return 'Entrez un nombre de minutes';
    if (minutes <= 0) return 'Le temps estimé doit être supérieur à zéro';
    // `PositiveSmallIntegerField` côté serveur : au-delà, l'écriture est
    // refusée en 400. Le dire ici évite un aller-retour pour rien.
    if (minutes > 32767) return 'Temps estimé irréaliste';
    return null;
  }

  double _lireMontant(TextEditingController controller) =>
      double.parse(controller.text.trim().replaceAll(',', '.'));

  // ---------------------------------------------------------- enregistrement

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _serverError = null;
    });

    final service = context.read<DeliveryZoneService>();
    final enregistre = await service.saveZoneSettings(
      zoneId: widget.zone.id,
      name: _nameController.text.trim(),
      deliveryFee: _lireMontant(_feeController),
      freeDeliveryThreshold:
          _hasFreeDelivery ? _lireMontant(_freeThresholdController) : null,
      // Le seuil n'est retiré que s'il existait : envoyer un `null` explicite
      // à une zone qui n'en avait pas serait une écriture pour rien.
      clearFreeDeliveryThreshold: !_hasFreeDelivery && widget.zone.hasFreeDelivery,
      estimatedTimeMinutes: int.parse(_estimatedTimeController.text.trim()),
      isActive: _isActive,
    );

    if (!mounted) return;

    if (enregistre) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSaving = false;
      _serverError = service.error ?? 'Enregistrement refusé par le serveur.';
    });
  }
}
