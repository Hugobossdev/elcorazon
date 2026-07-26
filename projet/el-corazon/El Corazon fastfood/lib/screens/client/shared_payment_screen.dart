import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:elcora_fast/models/group_payment.dart';
import 'package:elcora_fast/services/database_service.dart';
import 'package:elcora_fast/services/paydunya_service.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/widgets/custom_button.dart';
import 'package:elcora_fast/widgets/custom_text_field.dart';

class SharedPaymentScreen extends StatefulWidget {
  final String groupId;
  final String orderId;
  final double totalAmount;
  final List<PaymentParticipant> participants;

  const SharedPaymentScreen({
    required this.groupId,
    required this.orderId,
    required this.totalAmount,
    required this.participants,
    super.key,
  });

  @override
  State<SharedPaymentScreen> createState() => _SharedPaymentScreenState();
}

class _SharedPaymentScreenState extends State<SharedPaymentScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final PayDunyaService _payDunyaService = PayDunyaService();

  GroupPaymentSession? _session;
  List<PaymentParticipant> _participants = [];
  List<TextEditingController> _phoneControllers = [];
  List<String> _selectedOperators = [];
  List<PaymentResult?> _participantResults = [];

  bool _isLoading = true;
  String? _loadError;
  bool _isProcessing = false;
  SharedPaymentResult? _paymentResult;

  // Realtime subscriptions
  RealtimeChannel? _participantsSubscription;
  RealtimeChannel? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _participantsSubscription?.unsubscribe();
    _sessionSubscription?.unsubscribe();
    for (final controller in _phoneControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final session = await _databaseService.ensureGroupPaymentSession(
        orderId: widget.orderId,
        groupId: widget.groupId,
        initiatorUserId: widget.participants.isNotEmpty
            ? widget.participants.first.userId
            : null,
        totalAmount: widget.totalAmount,
        participants: widget.participants,
      );

      _applySession(session);
      _setupRealtimeSubscription(session.id);
    } catch (e) {
      setState(() {
        _loadError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupRealtimeSubscription(String sessionId) {
    if (_participantsSubscription != null) return;

    final supabase = _databaseService.supabase;

    // Écouter les mises à jour de la session (statut global)
    _sessionSubscription = supabase
        .channel('public:group_payments:id=eq.$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'group_payments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: sessionId,
          ),
          callback: (payload) {
            _refreshSession();
          },
        )
        .subscribe();

    // Écouter les mises à jour des participants (paiements individuels)
    _participantsSubscription = supabase
        .channel(
          'public:group_payment_participants:group_payment_id=eq.$sessionId',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_payment_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_payment_id',
            value: sessionId,
          ),
          callback: (payload) {
            _refreshSession();
          },
        )
        .subscribe();
  }

  Future<void> _refreshSession() async {
    try {
      final session = await _databaseService
          .getGroupPaymentSessionByOrderId(widget.orderId);
      if (session != null && mounted) {
        _applySession(session);
      }
    } catch (e) {
      debugPrint('Erreur lors du rafraîchissement de la session: $e');
    }
  }

  void _applySession(GroupPaymentSession session) {
    final defaultOperator = _payDunyaService
        .getAvailableMobileMoneyOperators()
        .first['id'] as String;

    final mappedParticipants = session.participants.map((participant) {
      return PaymentParticipant(
        userId: participant.userId ?? '',
        name: participant.name,
        email: participant.email ?? '',
        phoneNumber: participant.phone ?? '',
        operator: participant.operator ?? '',
        amount: participant.amount,
        backendId: participant.id,
      );
    }).toList(growable: false);

    final results = <PaymentResult?>[];
    final controllers = <TextEditingController>[];
    final operators = <String>[];

    for (var i = 0; i < mappedParticipants.length; i++) {
      final participant = session.participants[i];
      PaymentResult? result;
      if (participant.status == GroupPaymentParticipantStatus.paid) {
        result = PaymentResult(
          success: true,
          invoiceToken: participant.paymentResult?['invoice_token']?.toString(),
          invoiceUrl: participant.paymentResult?['invoice_url']?.toString(),
          orderId: _buildOrderId(session.orderId, participant),
        );
      } else if (participant.status == GroupPaymentParticipantStatus.failed) {
        result = PaymentResult(
          success: false,
          invoiceToken: participant.paymentResult?['invoice_token']?.toString(),
          invoiceUrl: participant.paymentResult?['invoice_url']?.toString(),
          error: participant.paymentResult?['error']?.toString() ??
              'Paiement échoué',
          orderId: _buildOrderId(session.orderId, participant),
        );
      }
      results.add(result);

      controllers.add(
        TextEditingController(
          text: mappedParticipants[i].phoneNumber,
        ),
      );

      final operatorValue = mappedParticipants[i].operator.isNotEmpty
          ? mappedParticipants[i].operator
          : defaultOperator;
      operators.add(operatorValue);
    }

    for (final controller in _phoneControllers) {
      controller.dispose();
    }

    setState(() {
      _session = session;
      _participants = mappedParticipants;
      _participantResults = results;
      _phoneControllers = controllers;
      _selectedOperators = operators;
      _paymentResult = _buildSummaryResultForSession(session);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar:
            AppBar(title: const Text('Paiement Partagé'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar:
            AppBar(title: const Text('Paiement Partagé'), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Impossible de charger la commande groupée.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _loadError!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                CustomButton(
                  onPressed: _loadSession,
                  text: 'Réessayer',
                  icon: Icons.refresh,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement Partagé'),
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.25),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildPaymentSummary(),
            Expanded(child: _buildParticipantsList()),
            _buildPaymentButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSummary() {
    final totalAmount = _session?.totalAmount ?? widget.totalAmount;
    final participantCount = _participants.length;
    final statusColor = _resolveStatusColor(_session?.status);
    final statusLabel = _resolveStatusLabel(_session?.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paiement groupé',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        'Commande ${widget.orderId}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(statusLabel, statusColor),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _buildSummaryPill(
                  label: 'Total',
                  value: PriceFormatter.format(totalAmount),
                ),
                const SizedBox(width: 12),
                _buildSummaryPill(
                  label: 'Participants',
                  value: participantCount.toString(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryPill(
                    label: 'Par personne',
                    value: PriceFormatter.format(
                      participantCount == 0
                          ? totalAmount
                          : totalAmount / participantCount,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPill({
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 10),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsList() {
    if (_participants.isEmpty) {
      return const Center(
        child: Text('Aucun participant n’est enregistré pour ce paiement.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      physics: const BouncingScrollPhysics(),
      itemCount: _participants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final participant = _participants[index];
        final isPaid = _participantResults.length > index &&
            (_participantResults[index]?.success ?? false);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPaid
                  ? Colors.green.withValues(alpha: 0.6)
                  : Theme.of(context).colorScheme.outlineVariant,
              width: isPaid ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 14,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    child: Text(
                      participant.name.isNotEmpty
                          ? participant.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          participant.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          participant.email,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (isPaid)
                    const Chip(
                      avatar: Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Payé',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: Colors.green,
                      shape: StadiumBorder(),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Montant à payer',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    PriceFormatter.format(participant.amount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!isPaid) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Informations de paiement',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Participant ${index + 1}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildOperatorSelector(index),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _phoneControllers[index],
                  label: 'Numéro de téléphone',
                  hint: '+225 XX XX XX XX',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _processIndividualPayment(index),
                    text: 'Payer ma part',
                    icon: Icons.payment,
                    isLoading: _isProcessing,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildOperatorSelector(int participantIndex) {
    final operators = _payDunyaService.getAvailableMobileMoneyOperators();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Opérateur Mobile Money',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: operators.length,
            itemBuilder: (context, index) {
              final operator = operators[index];
              final isSelected =
                  _selectedOperators[participantIndex] == operator['id'];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedOperators[participantIndex] = operator['id'];
                  });
                },
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color((operator['color'] as num).toInt())
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.phone_android,
                          color: Color((operator['color'] as num).toInt()),
                          size: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (operator['name'] as String).split(' ')[0],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[700],
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentButton() {
    final paidCount =
        _participantResults.where((r) => r?.success ?? false).length;
    final allPaid = _participants.isNotEmpty &&
        _participantResults.length == _participants.length &&
        paidCount == _participants.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_paymentResult != null && !allPaid) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Paiements effectués'),
                Text(
                  '$paidCount/${_participants.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value:
                  _participants.isEmpty ? 0 : paidCount / _participants.length,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: CustomButton(
                key: ValueKey<bool>(allPaid),
                onPressed: allPaid ? _finishOrder : _processAllPayments,
                text: allPaid
                    ? 'Finaliser la commande'
                    : 'Traiter tous les paiements',
                icon: allPaid ? Icons.check_circle : Icons.payment,
                isLoading: _isProcessing,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processIndividualPayment(int participantIndex) async {
    if (_session == null) {
      _showError('Session de paiement indisponible. Veuillez réessayer.');
      return;
    }

    final participant = _participants[participantIndex];
    final phoneController = _phoneControllers[participantIndex];

    if (phoneController.text.isEmpty) {
      _showError('Veuillez saisir le numéro de téléphone');
      return;
    }

    final participantId = participant.backendId;
    if (participantId == null || participantId.isEmpty) {
      _showError(
        'Participant introuvable dans la base de données. Veuillez recharger.',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final updatedParticipant = participant.copyWith(
        phoneNumber: phoneController.text,
        operator: _selectedOperators[participantIndex],
      );
      _participants[participantIndex] = updatedParticipant;

      final result = await _payDunyaService.processMobileMoneyPayment(
        orderId: '${widget.orderId}_${updatedParticipant.userId}',
        amount: updatedParticipant.amount,
        phoneNumber: phoneController.text,
        operator: _selectedOperators[participantIndex],
        customerName: updatedParticipant.name,
        customerEmail: updatedParticipant.email,
      );

      if (result.success) {
        _showSuccess(
          'Paiement effectué avec succès pour ${updatedParticipant.name}',
        );
      } else {
        _showError('Erreur lors du paiement: ${result.error}');
      }

      await _databaseService.updateGroupPaymentParticipant(
        participantId: participantId,
        phone: phoneController.text,
        operator: _selectedOperators[participantIndex],
        paidAmount: result.success ? updatedParticipant.amount : 0,
        status: result.success
            ? GroupPaymentParticipantStatus.paid
            : GroupPaymentParticipantStatus.failed,
        transactionId: result.invoiceToken,
        paymentResult: {
          'invoice_token': result.invoiceToken,
          'invoice_url': result.invoiceUrl,
          'error': result.error,
          'success': result.success,
          'order_id': result.orderId,
          'processed_at': DateTime.now().toIso8601String(),
        },
      );

      await _databaseService.refreshGroupPaymentTotals(_session!.id);
      final refreshed = await _databaseService
          .getGroupPaymentSessionByOrderId(widget.orderId);
      if (refreshed != null) {
        _applySession(refreshed);
      } else {
        setState(() {
          if (_participantResults.length <= participantIndex) {
            _participantResults.length = participantIndex + 1;
          }
          _participantResults[participantIndex] = result;
          _paymentResult = _buildSummaryResult();
        });
      }
    } catch (e) {
      _showError('Erreur: ${e.toString()}');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processAllPayments() async {
    if (_session == null) {
      _showError('Session de paiement indisponible. Veuillez réessayer.');
      return;
    }

    if (_participants.isEmpty) {
      _showError('Aucun participant pour le paiement partagé.');
      return;
    }

    // Si on traite TOUS les paiements, on vérifie que tous les numéros sont là pour les participants NON PAYÉS
    bool hasMissingPhone = false;
    for (int i = 0; i < _participants.length; i++) {
      // Ignorer ceux déjà payés
      final isPaid = _participantResults.length > i &&
          (_participantResults[i]?.success ?? false);
      if (isPaid) continue;

      if (_phoneControllers[i].text.trim().isEmpty) {
        hasMissingPhone = true;
        break;
      }
    }

    if (hasMissingPhone) {
      _showError(
        'Veuillez saisir les numéros de téléphone pour tous les participants non payés.',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Mettre à jour les participants avec les données saisies
      for (int i = 0; i < _participants.length; i++) {
        _participants[i] = _participants[i].copyWith(
          phoneNumber: _phoneControllers[i].text,
          operator: _selectedOperators[i],
        );
      }

      // Appeler le service PayDunya pour traiter les paiements en lot
      // Note: Idéalement, cela devrait être fait un par un ou via une API batch si disponible
      // Pour l'instant, on boucle ici

      int successCount = 0;
      int processedCount = 0;

      for (int i = 0; i < _participants.length; i++) {
        final participant = _participants[i];
        final isAlreadyPaid = _participantResults.length > i &&
            (_participantResults[i]?.success ?? false);

        if (isAlreadyPaid) {
          successCount++;
          continue;
        }

        processedCount++;
        final participantId = participant.backendId;
        if (participantId == null) continue;

        try {
          final result = await _payDunyaService.processMobileMoneyPayment(
            orderId: '${widget.orderId}_${participant.userId}',
            amount: participant.amount,
            phoneNumber: participant.phoneNumber,
            operator: participant.operator,
            customerName: participant.name,
            customerEmail: participant.email,
          );

          if (result.success) {
            successCount++;
          }

          // Mise à jour DB
          await _databaseService.updateGroupPaymentParticipant(
            participantId: participantId,
            phone: participant.phoneNumber,
            operator: participant.operator,
            paidAmount: result.success ? participant.amount : 0,
            status: result.success
                ? GroupPaymentParticipantStatus.paid
                : GroupPaymentParticipantStatus.failed,
            transactionId: result.invoiceToken,
            paymentResult: {
              'invoice_token': result.invoiceToken,
              'invoice_url': result.invoiceUrl,
              'error': result.error,
              'success': result.success,
              'order_id': result.orderId,
              'processed_at': DateTime.now().toIso8601String(),
            },
          );
        } catch (e) {
          debugPrint('Erreur paiement participant $i: $e');
        }
      }

      // Rafraîchir
      if (_session != null) {
        await _databaseService.refreshGroupPaymentTotals(_session!.id);
      }

      // Feedback utilisateur
      if (successCount == _participants.length) {
        _showSuccess('Tous les paiements ont été effectués avec succès !');
      } else if (processedCount > 0) {
        _showWarning(
          '$successCount/${_participants.length} paiements réussis. Vérifiez les erreurs.',
        );
      }
    } catch (e) {
      _showError('Erreur globale lors du traitement: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _finishOrder() async {
    if (_session == null) {
      _showError('Session de paiement indisponible.');
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      // Mettre à jour le statut du paiement groupé
      await _databaseService.updateGroupPaymentStatus(
        _session!.id,
        status: GroupPaymentStatus.completed,
      );

      // Mettre à jour le statut de la commande
      try {
        await _databaseService.supabase.from('orders').update({
          'status': 'confirmed',
          'payment_status': 'completed',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.orderId);

        debugPrint('✅ Commande groupée confirmée: ${widget.orderId}');
      } catch (e) {
        debugPrint(
          '⚠️ Erreur lors de la mise à jour du statut de la commande: $e',
        );
        // Continuer même en cas d'erreur
      }

      setState(() {
        _isProcessing = false;
      });

      if (!mounted) return;

      // Afficher le dialogue de confirmation
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Commande Confirmée'),
            ],
          ),
          content: const Text(
            'Tous les paiements ont été effectués avec succès. Votre commande partagée est en cours de préparation.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(true);
              },
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ Erreur lors de la finalisation de la commande: $e');
      setState(() {
        _isProcessing = false;
      });

      if (context.mounted) {
        _showError('Erreur lors de la finalisation: ${e.toString()}');
      }
    }
  }

  SharedPaymentResult _buildSummaryResult() {
    final session = _session;
    final totalAmount = session?.totalAmount ?? widget.totalAmount;
    final orderId = session?.orderId ?? widget.orderId;
    return _buildSummaryResultFromState(
      orderId: orderId,
      totalAmount: totalAmount,
      participants: _participants,
      results: _participantResults,
    );
  }

  SharedPaymentResult _buildSummaryResultForSession(
    GroupPaymentSession session,
  ) {
    final participants = session.participants
        .map(
          (p) => PaymentParticipant(
            userId: p.userId ?? '',
            name: p.name,
            email: p.email ?? '',
            phoneNumber: p.phone ?? '',
            operator: p.operator ?? '',
            amount: p.amount,
            backendId: p.id,
          ),
        )
        .toList();

    final results = session.participants.map((participant) {
      final orderId = _buildOrderId(session.orderId, participant);
      if (participant.status == GroupPaymentParticipantStatus.paid) {
        return PaymentResult(
          success: true,
          invoiceToken: participant.paymentResult?['invoice_token']?.toString(),
          invoiceUrl: participant.paymentResult?['invoice_url']?.toString(),
          orderId: orderId,
        );
      }
      if (participant.status == GroupPaymentParticipantStatus.failed) {
        return PaymentResult(
          success: false,
          invoiceToken: participant.paymentResult?['invoice_token']?.toString(),
          invoiceUrl: participant.paymentResult?['invoice_url']?.toString(),
          error: participant.paymentResult?['error']?.toString() ??
              'Paiement échoué',
          orderId: orderId,
        );
      }
      return null;
    }).toList();

    return _buildSummaryResultFromState(
      orderId: session.orderId,
      totalAmount: session.totalAmount,
      participants: participants,
      results: results,
    );
  }

  SharedPaymentResult _buildSummaryResultFromState({
    required String orderId,
    required double totalAmount,
    required List<PaymentParticipant> participants,
    required List<PaymentResult?> results,
  }) {
    double paidAmount = 0.0;
    final resultList = <PaymentResult>[];

    for (int i = 0; i < participants.length; i++) {
      final participant = participants[i];
      final result = (i < results.length) ? results[i] : null;
      final entryOrderId = '${orderId}_${participant.userId}';

      if (result != null) {
        resultList.add(result);
        if (result.success) {
          paidAmount += participant.amount;
        }
      } else {
        resultList.add(
          PaymentResult(
            success: false,
            orderId: entryOrderId,
            error: 'En attente',
          ),
        );
      }
    }

    final success =
        resultList.isNotEmpty && resultList.every((element) => element.success);

    return SharedPaymentResult(
      success: success,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      participants: List<PaymentParticipant>.from(participants),
      results: resultList,
      orderId: orderId,
      error: success ? null : 'Paiements incomplets',
    );
  }

  String _buildOrderId(
    String baseOrderId,
    GroupPaymentParticipant participant,
  ) {
    final userPart = participant.userId?.isNotEmpty == true
        ? participant.userId
        : participant.id;
    return '${baseOrderId}_$userPart';
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  String _resolveStatusLabel(GroupPaymentStatus? status) {
    switch (status) {
      case GroupPaymentStatus.completed:
        return 'Terminé';
      case GroupPaymentStatus.inProgress:
        return 'En cours';
      case GroupPaymentStatus.cancelled:
        return 'Annulé';
      case GroupPaymentStatus.pending:
      case null:
        return 'En attente';
    }
  }

  Color _resolveStatusColor(GroupPaymentStatus? status) {
    switch (status) {
      case GroupPaymentStatus.completed:
        return Colors.greenAccent;
      case GroupPaymentStatus.inProgress:
        return Colors.orangeAccent;
      case GroupPaymentStatus.cancelled:
        return Colors.redAccent;
      case GroupPaymentStatus.pending:
      case null:
        return Colors.yellowAccent;
    }
  }
}
