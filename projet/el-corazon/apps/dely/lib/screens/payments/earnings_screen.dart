import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/services/error_handler_service.dart';
import 'package:elcora_dely/presentation/libelles_course.dart';
import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcora_dely/widgets/loading_widget.dart';
import 'package:elcora_dely/widgets/custom_button.dart';
import 'package:elcora_dely/screens/delivery/driver_profile_screen.dart';
import 'package:elcora_dely/screens/delivery/settings_screen.dart';
import 'package:elcora_dely/presentation/messages_erreur.dart';
import 'package:elcorazon_core/elcorazon_core.dart'
    show Journal, Money, Withdrawal;

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  bool _isLoading = true;
  bool _isWithdrawing = false;
  String _selectedPeriod = 'today';

  /// Gains par période, en unité mineure — somme des `courier_fee` que le
  /// serveur a arrêtées sur les courses livrées de la période.
  Map<String, Map<String, num>> _earningsData = {};

  /// Les dernières courses livrées, pour la liste « gains récents ».
  List<Course> _recentDeliveries = const [];

  /// Demandes de retrait déjà faites. Un retrait naît « en attente » : sans
  /// cette liste, le livreur demandait, voyait son solde baisser, et n'avait
  /// plus aucun moyen de savoir où en était son versement.
  List<Withdrawal> _withdrawals = const [];

  @override
  void initState() {
    super.initState();
    _loadEarningsData();
  }

  Future<void> _loadEarningsData() async {
    if (!mounted) return;

    try {
      final appService = Provider.of<AppService>(context, listen: false);

      // Load available orders to get latest data (with timeout)
      try {
        await appService
            .loadAvailableOrders()
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        // Continuer même si le chargement échoue, utiliser les données en cache
        Journal.trace('⚠️ Could not refresh orders, using cached data: $e');
      }

      // Les courses livrées **dont le serveur a horodaté la livraison**.
      //
      // Le regroupement par période se faisait sur `passeeLe`, c'est-à-dire,
      // pour une course livrée dont le détail de commande n'est plus relu, sur
      // `offered_at` — le moment où la course avait été *proposée*. Une course
      // proposée à 23 h 50 et livrée à 00 h 10 comptait donc dans les gains de
      // la veille, et le total d'une journée ne correspondait à aucune journée
      // de travail.
      final deliveries = appService.assignedDeliveries
          .where((course) =>
              course.etape == EtapeCourse.livree && course.livreeLe != null)
          .toList()
        ..sort((a, b) => b.livreeLe!.compareTo(a.livreeLe!));

      final todayDeliveries =
          deliveries.where((c) => _isToday(c.livreeLe!)).toList();
      final weekDeliveries =
          deliveries.where((c) => _isThisWeek(c.livreeLe!)).toList();
      final monthDeliveries =
          deliveries.where((c) => _isThisMonth(c.livreeLe!)).toList();

      // Best-effort : l'écran reste utilisable sans l'historique des retraits.
      var withdrawals = const <Withdrawal>[];
      try {
        withdrawals = await appService.loadWithdrawals();
      } catch (e) {
        Journal.trace('⚠️ Historique des retraits illisible : $e');
      }

      /// Somme des rémunérations que le serveur a arrêtées pour ces courses.
      ///
      /// Cet écran appliquait auparavant une commission de 10 % au total de la
      /// commande, majorée de pourboires et de primes estimés à 10 % et 5 %.
      /// Aucun de ces trois taux n'existe au contrat, et le total en question
      /// vaut **zéro** sur toute course livrée : le détail d'une commande
      /// n'est pas relu une fois la course terminée. L'écran affichait donc
      /// invariablement 0 FCFA, quelle que soit la période.
      ///
      /// `courier_fee` est la rémunération réelle, calculée et rendue par le
      /// serveur sur chaque affectation. Le taux appartient au serveur.
      Map<String, num> calculerGains(List<Course> courses) {
        final total = courses.fold<int>(
          0,
          (somme, course) => somme + (course.remuneration?.amountMinor ?? 0),
        );
        return {'total': total, 'deliveries': courses.length};
      }

      if (mounted) {
        setState(() {
          _earningsData = {
            'today': calculerGains(todayDeliveries),
            'week': calculerGains(weekDeliveries),
            'month': calculerGains(monthDeliveries),
          };

          _recentDeliveries = deliveries.take(10).toList();
          _withdrawals = withdrawals;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errorHandler =
            Provider.of<ErrorHandlerService>(context, listen: false);
        errorHandler.logError('Erreur chargement gains', details: e);
        errorHandler.showErrorSnackBar(context, messageErreur(e));
      }
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day &&
        date.month == now.month &&
        date.year == now.year;
  }

  bool _isThisWeek(DateTime date) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        date.isBefore(weekEnd.add(const Duration(days: 1)));
  }

  bool _isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.month == now.month && date.year == now.year;
  }

  /// Demande un retrait sur le **solde**, montant choisi par le livreur.
  ///
  /// ## Ce qui a remplacé quoi
  ///
  /// L'écran envoyait le total de la **période sélectionnée** : demander un
  /// retrait avec l'onglet « Aujourd'hui » ouvert ne réclamait que les gains
  /// du jour, alors que le bloc au-dessus l'annonçait comme le « solde
  /// disponible » — un solde qui changeait donc en touchant un sélecteur de
  /// période. Selon l'onglet, la demande était soit très inférieure à ce que
  /// le livreur avait gagné, soit supérieure à son solde et refusée par le
  /// serveur (`InsufficientBalance`), sans que l'écran explique pourquoi.
  ///
  /// Le solde qui fait foi est `total_earnings` du dossier livreur, que le
  /// serveur débite sous verrou. Il ne se recompose pas à partir des courses
  /// rendues : l'historique servi à l'application est borné.
  Future<void> _requestWithdrawal() async {
    if (_isWithdrawing) return;

    final appService = Provider.of<AppService>(context, listen: false);
    final solde = appService.soldeDisponible;

    if (solde == null || solde.amountMinor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun solde disponible pour le retrait'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final montant = await _demanderMontant(solde);
    if (montant == null || !mounted) return;

    setState(() => _isWithdrawing = true);
    try {
      await appService.requestWithdrawal(montant);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Demande enregistrée. Le versement est traité par '
              'El Corazón : votre solde est déjà débité.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _loadEarningsData();
      }
    } catch (e) {
      if (mounted) {
        final errorHandler =
            Provider.of<ErrorHandlerService>(context, listen: false);
        errorHandler.logError('Erreur retrait', details: e);
        // « Le montant demandé dépasse les gains disponibles. » vaut
        // mieux que le nom de la classe d'exception.
        errorHandler.showErrorSnackBar(context, messageErreur(e));
      }
    } finally {
      if (mounted) setState(() => _isWithdrawing = false);
    }
  }

  /// Combien retirer, dans la limite du solde. Rend l'unité mineure.
  Future<int?> _demanderMontant(Money solde) async {
    final controleur =
        TextEditingController(text: '${solde.amountMinor}');

    return showDialog<int>(
      context: context,
      builder: (context) {
        String? erreur;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Demander un retrait'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Solde disponible : ${solde.format()}'),
                const SizedBox(height: 12),
                TextField(
                  controller: controleur,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Montant à retirer',
                    suffixText: solde.currency,
                    errorText: erreur,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Le montant est débité de votre solde immédiatement. Le '
                  'versement est ensuite exécuté par El Corazón.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () {
                  final saisi = int.tryParse(controleur.text.trim());
                  // La même vérification qu'au serveur, pour l'expliquer ici
                  // plutôt que de la subir en erreur d'API.
                  setDialogState(() {
                    erreur = saisi == null || saisi <= 0
                        ? 'Entrez un montant supérieur à zéro.'
                        : saisi > solde.amountMinor
                            ? 'Vous ne pouvez pas retirer plus que '
                                '${solde.format()}.'
                            : null;
                  });
                  if (erreur == null) Navigator.pop(context, saisi);
                },
                child: const Text('Demander'),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, num> _getCurrentEarnings() {
    return _earningsData[_selectedPeriod] ?? {};
  }

  /// Devise dans laquelle le livreur est payé, telle que le serveur la rend.
  ///
  /// `'FCFA'` était collé en dur derrière chaque nombre, y compris derrière un
  /// `toStringAsFixed(2)` qui affichait « 1500.00 FCFA » — or le franc CFA n'a
  /// pas de décimales, et `Money.format()` le sait (`CURRENCY_EXPONENTS`).
  String get _devise =>
      Provider.of<AppService>(context, listen: false)
          .soldeDisponible
          ?.currency ??
      'XOF';

  /// Un montant en unité mineure, écrit selon la règle unique du socle.
  String _formatMontant(num montantMineur) =>
      Money(amountMinor: montantMineur.round(), currency: _devise).format();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes gains'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _requestWithdrawal,
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Demander un retrait',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverProfileScreen(),
                    ),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Mon profil'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Paramètres'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Chargement des gains...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 24),
                  _buildEarningsSummary(),
                  const SizedBox(height: 24),
                  _buildEarningsBreakdown(),
                  const SizedBox(height: 24),
                  _buildRecentEarnings(),
                  const SizedBox(height: 24),
                  _buildWithdrawalSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Période',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPeriodButton('Aujourd\'hui', 'today'),
                const SizedBox(width: 8),
                _buildPeriodButton('Cette semaine', 'week'),
                const SizedBox(width: 8),
                _buildPeriodButton('Ce mois', 'month'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsSummary() {
    final earnings = _getCurrentEarnings();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Column(
          children: [
            Text(
              switch (_selectedPeriod) {
                'week' => 'Gains de la semaine',
                'month' => 'Gains du mois',
                _ => 'Gains du jour',
              },
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatMontant(earnings['total'] ?? 0),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                    'Livraisons', '${earnings['deliveries'] ?? 0}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsBreakdown() {
    final earnings = _getCurrentEarnings();
    final deliveriesCount = earnings['deliveries'] ?? 0;
    final deliveriesEarning = earnings['total'] ?? 0;
    final avgPerDelivery =
        deliveriesCount > 0 ? deliveriesEarning / deliveriesCount : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Détail des gains',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildBreakdownItem(
              'Livraisons',
              '$deliveriesCount livraison${deliveriesCount > 1 ? 's' : ''}',
              _formatMontant(deliveriesEarning),
              Icons.delivery_dining,
              Colors.blue,
            ),

            const SizedBox(height: 12),
            _buildBreakdownItem(
              'Gain moyen',
              'par livraison',
              deliveriesCount > 0 ? _formatMontant(avgPerDelivery) : '—',
              Icons.payments_outlined,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(String title, String subtitle, String amount,
      IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentEarnings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gains récents',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (_recentDeliveries.isEmpty)
              Text(
                'Aucune livraison terminée pour l\'instant.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ..._recentDeliveries.map(_buildEarningItem),
          ],
        ),
      ),
    );
  }

  /// Une ligne de gain — la course, et ce qu'elle a rapporté.
  ///
  /// Elle passait par une `Map<String, dynamic>` recopiée à partir de la
  /// course, où le compilateur ne disait rien d'une clé disparue. La course
  /// est passée telle quelle : ses champs sont typés, et sa référence est
  /// celle du serveur plutôt qu'un fragment d'UUID.
  Widget _buildEarningItem(Course course) {
    final montant = course.remuneration?.amountMinor ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.reference,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatTimestamp(course.livreeLe ?? course.passeeLe),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                course.remuneration?.format() ?? _formatMontant(montant),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Le solde et la demande de retrait.
  ///
  /// « Solde disponible » affichait ici le total de la **période
  /// sélectionnée** : il changeait en touchant « Aujourd'hui » / « Cette
  /// semaine » / « Ce mois », alors qu'un solde ne dépend pas de la fenêtre
  /// qu'on regarde. Le vrai solde est `total_earnings` du dossier livreur, que
  /// le serveur débite à chaque retrait.
  Widget _buildWithdrawalSection() {
    final solde = Provider.of<AppService>(context).soldeDisponible;
    final montantDisponible = solde?.amountMinor ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Retrait',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solde disponible',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        solde?.format() ?? '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Tous vos gains non encore retirés',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                CustomButton(
                  text: 'Retirer',
                  onPressed: montantDisponible > 0 && !_isWithdrawing
                      ? _requestWithdrawal
                      : null,
                  icon: Icons.account_balance_wallet,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      // Le délai annoncé était « dans les 24 h », que rien ne
                      // garantit : le versement est un geste de
                      // l'exploitation, exécuté quand elle l'exécute. Mieux
                      // vaut décrire le mécanisme que promettre un délai.
                      'Votre demande débite le solde immédiatement. Le '
                      'versement est ensuite exécuté par El Corazón.',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_withdrawals.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Mes demandes',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ..._withdrawals.take(5).map(_buildWithdrawalItem),
            ],
          ],
        ),
      ),
    );
  }

  /// Une demande de retrait et son sort.
  ///
  /// Ce que le livreur a besoin de savoir tient dans ces trois lignes : le
  /// montant, la date, et où en est le versement. Un retrait échoué recrédite
  /// le solde côté serveur (`WithdrawalService.fail`) — sa raison est donc
  /// affichée, pour qu'il ne s'étonne pas de voir son solde remonter.
  Widget _buildWithdrawalItem(Withdrawal retrait) {
    final (couleur, libelle) = switch (retrait.status) {
      'completed' => (Colors.green, 'Versé'),
      'processing' => (Colors.blue, 'En cours de versement'),
      'failed' => (Colors.red, 'Échoué'),
      'cancelled' => (Colors.grey, 'Annulé'),
      _ => (Colors.orange, 'En attente'),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: couleur),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  retrait.amount.format(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  retrait.failureReason.isEmpty
                      ? '$libelle · ${_formatTimestamp(retrait.createdAt)}'
                      : '$libelle · ${retrait.failureReason}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes}min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return 'Il y a ${difference.inDays}j';
    }
  }
}
