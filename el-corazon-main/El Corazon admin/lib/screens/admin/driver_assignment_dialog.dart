import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/driver_management_service.dart';
import '../../services/order_management_service.dart';
import '../../models/driver.dart';
import '../../models/order.dart';
import '../../widgets/custom_button.dart';
import '../../utils/price_formatter.dart';

class DriverAssignmentDialog extends StatefulWidget {
  final Order order;

  const DriverAssignmentDialog({super.key, required this.order});

  @override
  State<DriverAssignmentDialog> createState() => _DriverAssignmentDialogState();
}

class _DriverAssignmentDialogState extends State<DriverAssignmentDialog> {
  Driver? _selectedDriver;
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 600.0);
    final dialogHeight = (screenSize.height * 0.8).clamp(500.0, 800.0);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: dialogWidth,
          maxWidth: dialogWidth,
          minHeight: dialogHeight,
          maxHeight: dialogHeight,
        ),
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.delivery_dining,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assigner un livreur',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Commande #${widget.order.id.substring(0, 8).toUpperCase()}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary
                                          .withValues(alpha: 0.8),
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.close,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Contenu
              Expanded(
                child: Consumer<DriverManagementService>(
                  builder: (context, driverService, child) {
                    if (driverService.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Filtrer les livreurs disponibles
                    final availableDrivers = driverService.drivers
                        .where(
                          (driver) =>
                              driver.status == DriverStatus.available ||
                              driver.status == DriverStatus.onDelivery,
                        )
                        .toList();

                    if (availableDrivers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delivery_dining_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun livreur disponible',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tous les livreurs sont actuellement occupés',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        // Informations de la commande
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.grey[100],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.grey[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.order.deliveryAddress,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.monetization_on,
                                    size: 16,
                                    color: Colors.grey[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total: ${PriceFormatter.format(widget.order.total)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Liste des livreurs
                        Expanded(
                          child: RadioGroup<Driver>(
                            groupValue: _selectedDriver,
                            onChanged: (value) {
                              setState(() {
                                _selectedDriver = value;
                                _error = null;
                              });
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: availableDrivers.length,
                              itemBuilder: (context, index) {
                                final driver = availableDrivers[index];
                                final isSelected =
                                    _selectedDriver?.id == driver.id;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: isSelected ? 4 : 1,
                                  color: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.2)
                                      : null,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minHeight: 56,
                                    ),
                                    child: RadioListTile<Driver>(
                                      value: driver,
                                      title: Text(
                                        driver.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : null,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                driver.status.icon,
                                                size: 14,
                                                color: _getStatusColor(
                                                  driver.status,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                driver.status.displayName,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: _getStatusColor(
                                                    driver.status,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (driver.vehicleType != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.motorcycle,
                                                  size: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  driver.vehicleType!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                      secondary: CircleAvatar(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        child: Text(
                                          driver.name
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            color: Colors.red[50],
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error,
                                  color: Colors.red[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CustomButton(
                      text: 'Assigner',
                      onPressed: _selectedDriver == null || _isLoading
                          ? null
                          : _assignDriver,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(DriverStatus status) {
    switch (status) {
      case DriverStatus.available:
        return Colors.green;
      case DriverStatus.onDelivery:
        return Colors.orange;
      case DriverStatus.offline:
        return Colors.grey;
      case DriverStatus.unavailable:
        return Colors.red;
    }
  }

  Future<void> _assignDriver() async {
    if (_selectedDriver == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orderService = context.read<OrderManagementService>();

      // Utiliser user_id si disponible, sinon utiliser l'id du driver
      final driverId = _selectedDriver!.userId ?? _selectedDriver!.id;

      final success = await orderService.assignDriver(
        widget.order.id,
        driverId,
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Livreur ${_selectedDriver!.name} assigné avec succès',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _error = 'Erreur lors de l\'assignation du livreur';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }
}
