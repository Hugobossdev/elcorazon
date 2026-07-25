import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/customization_management_service.dart';

class CustomizationAssociationDialog extends StatefulWidget {
  final String optionId;
  final String optionName;

  const CustomizationAssociationDialog({
    super.key,
    required this.optionId,
    required this.optionName,
  });

  @override
  State<CustomizationAssociationDialog> createState() =>
      _CustomizationAssociationDialogState();
}

class _CustomizationAssociationDialogState
    extends State<CustomizationAssociationDialog> {
  String? _selectedMenuItemId;
  bool _isRequired = false;
  int _sortOrder = 0;
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _sortOrderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sortOrderController.text = _sortOrder.toString();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 600,
        constraints: const BoxConstraints(
          minWidth: 500,
          maxWidth: 800,
          minHeight: 500,
          maxHeight: 700,
        ),
        child: Column(
          children: [
            AppBar(
              title: const Text('Associer à un produit'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Option: ${widget.optionName}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un produit...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: Consumer<CustomizationManagementService>(
                builder: (context, service, child) {
                  final menuItems = service.menuItems
                      .where((item) =>
                          _searchQuery.isEmpty ||
                          item.name
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()))
                      .toList();

                  if (menuItems.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'Aucun produit disponible'
                            : 'Aucun produit trouvé',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    );
                  }

                  return RadioGroup<String>(
                    groupValue: _selectedMenuItemId,
                    onChanged: (value) {
                      if (value != null) {
                        final item = menuItems.firstWhere(
                          (item) => item.id == value,
                        );
                        final isAlreadyAssociated = service
                            .getOptionsForMenuItem(item.id)
                            .any((assoc) =>
                                assoc.customizationOptionId == widget.optionId);
                        if (!isAlreadyAssociated) {
                          setState(() {
                            _selectedMenuItemId = value;
                          });
                        }
                      }
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: menuItems.length,
                      itemBuilder: (context, index) {
                        final item = menuItems[index];
                        final isSelected = _selectedMenuItemId == item.id;
                        final isAlreadyAssociated = service
                            .getOptionsForMenuItem(item.id)
                            .any((assoc) =>
                                assoc.customizationOptionId == widget.optionId);

                        final radioTile = isAlreadyAssociated
                            ? RadioListTile<String>(
                                title: Text(item.name),
                                subtitle: Text(
                                  item.categoryId.isNotEmpty
                                      ? item.categoryId
                                      : 'Sans catégorie',
                                ),
                                value: item.id,
                                enabled: false,
                                secondary: Chip(
                                  label: const Text('Déjà associé'),
                                  backgroundColor: Colors.green.shade100,
                                ),
                              )
                            : RadioListTile<String>(
                                title: Text(item.name),
                                subtitle: Text(
                                  item.categoryId.isNotEmpty
                                      ? item.categoryId
                                      : 'Sans catégorie',
                                ),
                                value: item.id,
                              );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: radioTile,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedMenuItemId != null) ...[
                    SwitchListTile(
                      title: const Text('Option requise'),
                      subtitle: const Text(
                        'L\'utilisateur doit sélectionner cette option',
                      ),
                      value: _isRequired,
                      onChanged: (value) {
                        setState(() {
                          _isRequired = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _sortOrderController,
                      decoration: const InputDecoration(
                        labelText: 'Ordre d\'affichage',
                        hintText: '0',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _sortOrder = int.tryParse(value) ?? 0;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading || _selectedMenuItemId == null
                            ? null
                            : _handleAssociate,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Associer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAssociate() async {
    if (_selectedMenuItemId == null) return;

    setState(() {
      _isLoading = true;
    });

    final service = Provider.of<CustomizationManagementService>(
      context,
      listen: false,
    );

    final success = await service.associateOptionToMenuItem(
      menuItemId: _selectedMenuItemId!,
      optionId: widget.optionId,
      isRequired: _isRequired,
      sortOrder: _sortOrder,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Option associée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(service.error ?? 'Erreur lors de l\'association'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
