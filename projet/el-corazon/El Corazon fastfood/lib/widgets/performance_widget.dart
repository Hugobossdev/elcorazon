import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/performance_service.dart';

/// Widget pour afficher les métriques de performance (mode debug uniquement)
class PerformanceWidget extends StatelessWidget {
  final bool showDetails;

  const PerformanceWidget({
    super.key,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PerformanceService>(
      builder: (context, performanceService, child) {
        if (!performanceService.isInitialized) {
          return const SizedBox.shrink();
        }

        final report = performanceService.getPerformanceReport();
        
        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border.all(color: Colors.blue.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.speed,
                    color: Colors.blue.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Performance',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${report.totalOperations} ops',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Moyenne: ${report.averageDuration.inMilliseconds}ms',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 12,
                ),
              ),
              if (showDetails && report.slowestOperations.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildSlowestOperations(report.slowestOperations),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlowestOperations(List<PerformanceMetric> operations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plus lentes:',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.blue.shade800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        ...operations.take(3).map((op) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text(
            '${op.operation}: ${op.duration.inMilliseconds}ms',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 11,
            ),
          ),
        ),),
      ],
    );
  }
}

/// Widget pour afficher un indicateur de performance en temps réel
class PerformanceIndicator extends StatefulWidget {
  final String operation;
  final Widget child;

  const PerformanceIndicator({
    required this.operation, required this.child, super.key,
  });

  @override
  State<PerformanceIndicator> createState() => _PerformanceIndicatorState();
}

class _PerformanceIndicatorState extends State<PerformanceIndicator> {
  @override
  Widget build(BuildContext context) {
    return Consumer<PerformanceService>(
      builder: (context, performanceService, child) {
        // Mesurer le temps de build
        performanceService.startTimer('${widget.operation}_build');
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          performanceService.stopTimer('${widget.operation}_build');
        });

        return widget.child;
      },
    );
  }
}

/// Widget pour afficher un rapport de performance détaillé
class PerformanceReportWidget extends StatelessWidget {
  const PerformanceReportWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PerformanceService>(
      builder: (context, performanceService, child) {
        if (!performanceService.isInitialized) {
          return const Center(child: Text('Performance service not initialized'));
        }

        final report = performanceService.getPerformanceReport();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Rapport de Performance'),
            actions: [
              IconButton(
                onPressed: () => performanceService.clearMetrics(),
                icon: const Icon(Icons.clear),
                tooltip: 'Effacer les métriques',
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSummaryCard(report),
              const SizedBox(height: 16),
              _buildOperationsCard(report),
              const SizedBox(height: 16),
              _buildSlowestOperationsCard(report),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(PerformanceReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Résumé',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Opérations',
                    report.totalOperations.toString(),
                    Icons.functions,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Durée moyenne',
                    '${report.averageDuration.inMilliseconds}ms',
                    Icons.timer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildOperationsCard(PerformanceReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Opérations par type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...report.operationCounts.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text('${entry.value}'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSlowestOperationsCard(PerformanceReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Opérations les plus lentes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...report.slowestOperations.map((metric) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(metric.operation)),
                    Text('${metric.duration.inMilliseconds}ms'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

