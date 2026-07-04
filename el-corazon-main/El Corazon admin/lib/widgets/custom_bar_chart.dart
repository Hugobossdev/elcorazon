import 'package:flutter/material.dart';

class CustomBarChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  final Color color;
  final double height;
  final String? tooltipFormat;

  const CustomBarChart({
    super.key,
    required this.data,
    required this.labels,
    this.color = Colors.blue,
    this.height = 200,
    this.tooltipFormat,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();
    final maxValue = data.reduce((curr, next) => curr > next ? curr : next);
    final normalizedMax = maxValue == 0 ? 1.0 : maxValue;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(data.length, (index) {
          final value = data[index];
          final label = labels[index];
          final percentage = value / normalizedMax;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Valeur au survol ou toujours visible si peu de barres
                if (data.length < 10)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                // Barre
                Flexible(
                  child: Container(
                    width: 12, // Largeur fixe pour l'esthétique
                    height: percentage * (height - 30), // -30 pour les labels
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.8),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          color.withValues(alpha: 0.5),
                          color,
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Label
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}



