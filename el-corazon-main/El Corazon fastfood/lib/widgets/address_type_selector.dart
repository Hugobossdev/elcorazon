import 'package:flutter/material.dart';
import 'package:elcora_fast/models/address.dart';

/// Address Type Selector with Emojis
/// Beautiful type selector with emoji icons and labels
class AddressTypeSelector extends StatelessWidget {
  final AddressType selectedType;
  final ValueChanged<AddressType> onTypeSelected;
  final bool isCompact;

  const AddressTypeSelector({
    required this.selectedType,
    required this.onTypeSelected,
    super.key,
    this.isCompact = false,
  });

  String _getEmoji(AddressType type) {
    switch (type) {
      case AddressType.home:
        return '🏠';
      case AddressType.work:
        return '💼';
      case AddressType.other:
        return '📍';
    }
  }

  Color _getColor(AddressType type) {
    switch (type) {
      case AddressType.home:
        return Colors.green;
      case AddressType.work:
        return Colors.blue;
      case AddressType.other:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactSelector();
    }
    return _buildFullSelector();
  }

  Widget _buildFullSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TYPE D\'ADRESSE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: AddressType.values.map((type) {
            final isSelected = selectedType == type;
            final color = _getColor(type);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => onTypeSelected(type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : Colors.grey.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getEmoji(type),
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          type.displayName.toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? color : Colors.black38,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCompactSelector() {
    return Wrap(
      spacing: 8,
      children: AddressType.values.map((type) {
        final isSelected = selectedType == type;
        final color = _getColor(type);

        return GestureDetector(
          onTap: () => onTypeSelected(type),
          child: Chip(
            avatar: Text(_getEmoji(type)),
            label: Text(type.displayName),
            backgroundColor: isSelected
                ? color.withValues(alpha: 0.2)
                : Colors.grey.shade200,
            side: BorderSide(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            labelStyle: TextStyle(
              color: isSelected ? color : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Single Address Type Chip
class AddressTypeChip extends StatelessWidget {
  final AddressType type;
  final bool showEmoji;

  const AddressTypeChip({
    required this.type,
    super.key,
    this.showEmoji = true,
  });

  String _getEmoji(AddressType type) {
    switch (type) {
      case AddressType.home:
        return '🏠';
      case AddressType.work:
        return '💼';
      case AddressType.other:
        return '📍';
    }
  }

  Color _getColor(AddressType type) {
    switch (type) {
      case AddressType.home:
        return Colors.green;
      case AddressType.work:
        return Colors.blue;
      case AddressType.other:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showEmoji) ...[
            Text(_getEmoji(type), style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
          ],
          Text(
            type.displayName,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
