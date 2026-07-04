import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import '../models/menu_models.dart';
import '../models/driver.dart';

class ReportService extends ChangeNotifier {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  bool _isGenerating = false;
  String? _error;

  bool get isGenerating => _isGenerating;
  String? get error => _error;

  /// Générer un rapport de ventes
  Future<Uint8List?> generateSalesReport({
    required DateTime startDate,
    required DateTime endDate,
    String? category,
  }) async {
    try {
      _isGenerating = true;
      _error = null;
      notifyListeners();

      // Simuler la récupération des données
      final orders = await _getOrdersForPeriod(startDate, endDate);
      final filteredOrders = category != null
          ? orders
                .where(
                  (order) =>
                      order.items.any((item) => item.categoryId == category),
                )
                .toList()
          : orders;

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              _buildHeader('Rapport de Ventes', startDate, endDate),
              pw.SizedBox(height: 20),
              _buildSalesSummary(filteredOrders),
              pw.SizedBox(height: 20),
              _buildOrdersTable(filteredOrders),
            ];
          },
        ),
      );

      _isGenerating = false;
      notifyListeners();

      return await pdf.save();
    } catch (e) {
      _isGenerating = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('ReportService: Erreur génération rapport ventes - $e');
      return null;
    }
  }

  /// Générer un rapport de performance des livreurs
  Future<Uint8List?> generateDriverPerformanceReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      _isGenerating = true;
      _error = null;
      notifyListeners();

      // Simuler la récupération des données
      final drivers = await _getDriversData();
      final orders = await _getOrdersForPeriod(startDate, endDate);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              _buildHeader(
                'Rapport de Performance des Livreurs',
                startDate,
                endDate,
              ),
              pw.SizedBox(height: 20),
              _buildDriverSummary(drivers, orders),
              pw.SizedBox(height: 20),
              _buildDriverPerformanceTable(drivers, orders),
            ];
          },
        ),
      );

      _isGenerating = false;
      notifyListeners();

      return await pdf.save();
    } catch (e) {
      _isGenerating = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('ReportService: Erreur génération rapport livreurs - $e');
      return null;
    }
  }

  /// Générer un rapport d'inventaire
  Future<Uint8List?> generateInventoryReport() async {
    try {
      _isGenerating = true;
      _error = null;
      notifyListeners();

      // Simuler la récupération des données
      final menuItems = await _getMenuItemsData();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              _buildHeader(
                'Rapport d\'Inventaire',
                DateTime.now(),
                DateTime.now(),
              ),
              pw.SizedBox(height: 20),
              _buildInventorySummary(menuItems),
              pw.SizedBox(height: 20),
              _buildInventoryTable(menuItems),
            ];
          },
        ),
      );

      _isGenerating = false;
      notifyListeners();

      return await pdf.save();
    } catch (e) {
      _isGenerating = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('ReportService: Erreur génération rapport inventaire - $e');
      return null;
    }
  }

  /// Exporter les données en CSV
  Future<String?> exportOrdersToCSV({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      _isGenerating = true;
      _error = null;
      notifyListeners();

      final orders = await _getOrdersForPeriod(startDate, endDate);

      final csv = StringBuffer();
      csv.writeln('ID,Date,Client,Total,Statut,Adresse');

      for (final order in orders) {
        csv.writeln(
          '${order.id},${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)},${order.userId},${order.total},${order.status},${order.deliveryAddress}',
        );
      }

      _isGenerating = false;
      notifyListeners();

      return csv.toString();
    } catch (e) {
      _isGenerating = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('ReportService: Erreur export CSV - $e');
      return null;
    }
  }

  /// Exporter les données en format Excel (CSV amélioré)
  Future<String?> exportToExcel({
    required DateTime startDate,
    required DateTime endDate,
    String reportType = 'orders', // 'orders', 'revenue', 'products', 'drivers'
  }) async {
    try {
      _isGenerating = true;
      _error = null;
      notifyListeners();

      String csv = '';

      switch (reportType) {
        case 'orders':
          csv = await exportOrdersToCSV(startDate: startDate, endDate: endDate) ?? '';
          break;
        case 'revenue':
          csv = await _exportRevenueToCSV(startDate: startDate, endDate: endDate);
          break;
        case 'products':
          csv = await _exportProductsToCSV();
          break;
        case 'drivers':
          csv = await _exportDriversToCSV(startDate: startDate, endDate: endDate);
          break;
        default:
          csv = await exportOrdersToCSV(startDate: startDate, endDate: endDate) ?? '';
      }

      _isGenerating = false;
      notifyListeners();

      return csv;
    } catch (e) {
      _isGenerating = false;
      _error = e.toString();
      notifyListeners();
      debugPrint('ReportService: Erreur export Excel - $e');
      return null;
    }
  }

  /// Exporter les revenus en CSV
  Future<String> _exportRevenueToCSV({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final orders = await _getOrdersForPeriod(startDate, endDate);
    final deliveredOrders = orders.where((o) => o.status == OrderStatus.delivered).toList();

    final csv = StringBuffer();
    csv.writeln('Date,Revenus,Commandes,Panier Moyen');

    // Grouper par jour
    final dailyRevenue = <String, Map<String, dynamic>>{};
    
    for (final order in deliveredOrders) {
      final date = DateFormat('yyyy-MM-dd').format(order.createdAt);
      if (!dailyRevenue.containsKey(date)) {
        dailyRevenue[date] = {
          'revenue': 0.0,
          'count': 0,
        };
      }
      dailyRevenue[date]!['revenue'] = (dailyRevenue[date]!['revenue'] as double) + order.total;
      dailyRevenue[date]!['count'] = (dailyRevenue[date]!['count'] as int) + 1;
    }

    // Trier par date
    final sortedDates = dailyRevenue.keys.toList()..sort();

    for (final date in sortedDates) {
      final data = dailyRevenue[date]!;
      final revenue = data['revenue'] as double;
      final count = data['count'] as int;
      final average = count > 0 ? revenue / count : 0.0;
      
      csv.writeln('$date,$revenue,$count,$average');
    }

    return csv.toString();
  }

  /// Exporter les produits en CSV
  Future<String> _exportProductsToCSV() async {
    final menuItems = await _getMenuItemsData();
    
    final csv = StringBuffer();
    csv.writeln('Nom,Catégorie,Prix,Disponible,Ordre');

    for (final item in menuItems) {
      csv.writeln(
        '${item.name},${item.categoryId},${item.basePrice},${item.isAvailable},${item.sortOrder}',
      );
    }

    return csv.toString();
  }

  /// Exporter les livreurs en CSV
  Future<String> _exportDriversToCSV({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final drivers = await _getDriversData();
    final orders = await _getOrdersForPeriod(startDate, endDate);

    final csv = StringBuffer();
    csv.writeln('Nom,Téléphone,Note,Livraisons,Statut');

    for (final driver in drivers) {
      final driverOrders = orders
          .where((order) => order.deliveryPersonId == driver.userId || order.deliveryPersonId == driver.id)
          .where((order) => order.status == OrderStatus.delivered)
          .length;

      csv.writeln(
        '${driver.name},${driver.phone},${driver.rating},$driverOrders,${driver.isActive ? "Actif" : "Inactif"}',
      );
    }

    return csv.toString();
  }

  /// Construire l'en-tête du rapport
  pw.Widget _buildHeader(String title, DateTime startDate, DateTime endDate) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'El Corazón - FastFoodGo',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Période: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
          style: const pw.TextStyle(fontSize: 12),
        ),
        pw.Text(
          'Généré le: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  /// Construire le résumé des ventes
  pw.Widget _buildSalesSummary(List<Order> orders) {
    final totalRevenue = orders.fold<double>(
      0,
      (sum, order) => sum + order.total,
    );
    final totalOrders = orders.length;
    final averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Résumé des Ventes',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total des commandes: $totalOrders'),
              pw.Text(
                'Chiffre d\'affaires: ${NumberFormat.currency(locale: 'fr_FR', symbol: '').format(totalRevenue)} FCFA',
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Valeur moyenne par commande: ${NumberFormat.currency(locale: 'fr_FR', symbol: '').format(averageOrderValue)} FCFA',
          ),
        ],
      ),
    );
  }

  /// Construire le tableau des commandes
  pw.Widget _buildOrdersTable(List<Order> orders) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'ID Commande',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Date',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Client',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Total',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Statut',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
        ...orders
            .take(50)
            .map(
              (order) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(order.id.substring(0, 8)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      DateFormat('dd/MM/yyyy').format(order.createdAt),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(order.userId.substring(0, 8)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('${order.total.toInt()} FCFA'),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(_getStatusText(order.status)),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  /// Construire le résumé des livreurs
  pw.Widget _buildDriverSummary(List<Driver> drivers, List<Order> orders) {
    final activeDrivers = drivers.where((driver) => driver.isActive).length;
    final totalDeliveries = orders
        .where((order) => order.status == OrderStatus.delivered)
        .length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Résumé des Livreurs',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Livreurs actifs: $activeDrivers'),
              pw.Text('Total livraisons: $totalDeliveries'),
            ],
          ),
        ],
      ),
    );
  }

  /// Construire le tableau de performance des livreurs
  pw.Widget _buildDriverPerformanceTable(
    List<Driver> drivers,
    List<Order> orders,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Nom',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Téléphone',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Livraisons',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Note',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Statut',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
        ...drivers.map((driver) {
          // Compter les commandes livrées par ce livreur
          final driverOrders = orders
              .where((order) {
                // Vérifier si le livreur correspond (via delivery_person_id ou user_id)
                return order.deliveryPersonId == driver.userId ||
                    order.deliveryPersonId == driver.id;
              })
              .where((order) => order.status == OrderStatus.delivered)
              .length;

          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(driver.name),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(driver.phone),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(driverOrders.toString()),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(driver.rating.toStringAsFixed(1)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(driver.isActive ? 'Actif' : 'Inactif'),
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Construire le résumé de l'inventaire
  pw.Widget _buildInventorySummary(List<MenuItem> menuItems) {
    final totalItems = menuItems.length;
    final availableItems = menuItems.where((item) => item.isAvailable).length;
    final outOfStockItems = totalItems - availableItems;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Résumé de l\'Inventaire',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total produits: $totalItems'),
              pw.Text('Disponibles: $availableItems'),
              pw.Text('Rupture: $outOfStockItems'),
            ],
          ),
        ],
      ),
    );
  }

  /// Construire le tableau d'inventaire
  pw.Widget _buildInventoryTable(List<MenuItem> menuItems) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Nom',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Catégorie',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Prix',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Stock',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Statut',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
        ...menuItems.map(
          (item) => pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(item.name),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(item/* .categoryName - REMOVED */.name),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('${item.basePrice.toInt()} FCFA'),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(item/* .availableQuantity - REMOVED */.sortOrder.toString()),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  item.isAvailable ? 'Disponible' : 'Indisponible',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Récupérer les commandes depuis Supabase
  Future<List<Order>> _getOrdersForPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('orders')
          .select('*, order_items(*)')
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false);

      return (response as List).map((data) => Order.fromMap(data)).toList();
    } catch (e) {
      debugPrint('ReportService: Erreur récupération commandes - $e');
      return [];
    }
  }

  /// Récupérer les livreurs depuis Supabase
  Future<List<Driver>> _getDriversData() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('drivers')
          .select('*')
          .order('name', ascending: true);

      return (response as List).map((data) => Driver.fromMap(data)).toList();
    } catch (e) {
      debugPrint('ReportService: Erreur récupération livreurs - $e');
      return [];
    }
  }

  /// Récupérer les produits depuis Supabase
  Future<List<MenuItem>> _getMenuItemsData() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('menu_items')
          .select('*, menu_categories(*)')
          .order('name', ascending: true);

      return (response as List).map((data) => MenuItem.fromMap(data)).toList();
    } catch (e) {
      debugPrint('ReportService: Erreur récupération produits - $e');
      return [];
    }
  }

  /// Obtenir le texte du statut
  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'En attente';
      case OrderStatus.confirmed:
        return 'Confirmée';
      case OrderStatus.preparing:
        return 'En préparation';
      case OrderStatus.ready:
        return 'Prête';
      case OrderStatus.onTheWay:
        return 'En route';
      case OrderStatus.pickedUp:
        return 'Récupérée';
      case OrderStatus.delivered:
        return 'Livrée';
      case OrderStatus.cancelled:
        return 'Annulée';
      case OrderStatus.refunded:
        return 'Remboursée';
      case OrderStatus.failed:
        return 'Échouée';
    }
  }

  /// Effacer l'erreur
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
