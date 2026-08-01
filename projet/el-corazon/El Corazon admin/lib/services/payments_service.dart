import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'admin_auth_service.dart';

/// Encaissements et remboursements — `/payments/*` (Phase 6).
///
/// Ce service remplace `PayDunyaService`, et le remplacement est d'abord une
/// correction de sécurité.
///
/// L'ancien appelait PayDunya **depuis le navigateur**, avec les quatre clés
/// marchandes (`master_key`, `public_key`, `private_key`, `token`) saisies dans
/// l'écran des réglages et rangées dans `SharedPreferences`. Autrement dit :
/// les clés qui autorisent un remboursement voyageaient dans l'application,
/// lisibles par quiconque ouvrait le bundle ou le stockage local du poste. Un
/// remboursement pouvait être déclenché sans passer par le serveur, donc sans
/// permission, sans rattachement, sans trace, et sans plafond.
///
/// Ici, les clés ne quittent pas le serveur. Le remboursement est une requête
/// authentifiée qui exige `orders.refund`, vérifie que la commande appartient
/// au périmètre du compte — un opérateur de Kara ne rembourse pas une commande
/// de Lomé, avec l'argent de Lomé — et applique l'invariant P3 : la somme des
/// remboursements d'une transaction ne dépasse jamais ce qui a été encaissé.
///
/// Trois fonctions ont disparu avec le service :
///
/// * **la configuration des clés** : elles sont côté serveur ;
/// * **la vérification d'un statut auprès de PayDunya** : le statut d'une
///   transaction est celui que le webhook signé a écrit. Interroger le
///   prestataire depuis l'écran donnait une seconde réponse, parfois en avance
///   sur la première, et l'écran affichait alors « payé » sur une commande que
///   le serveur tenait pour en attente ;
/// * **la « réconciliation »** : elle comparait deux listes chargées côté
///   client et n'écrivait rien. Un rapprochement comptable se fait là où sont
///   les écritures.
class PaymentsService extends ChangeNotifier {
  eccore.PaymentRepository get _payments =>
      eccore.PaymentRepository(apiClient: AdminAuthService().apiClient);

  List<eccore.Transaction> _transactions = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<eccore.Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await refresh();
  }

  /// Encaissements du périmètre — le filtre est celui du serveur.
  Future<void> refresh({String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _transactions = await _payments.listTransactions(status: status);
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Paiements : chargement impossible — ${e.code}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Transactions d'une commande, sans recharger la liste complète.
  Future<List<eccore.Transaction>> transactionsOf(String orderId) async {
    try {
      return await _payments.getTransactions(orderId: orderId);
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Paiements : transactions indisponibles — ${e.code}');
      return const [];
    }
  }

  /// Rembourse tout ou partie d'une commande (permission `orders.refund`).
  ///
  /// [amountMajor] est en unité majeure — ce que saisit l'opérateur — et
  /// converti ici, une fois. Le serveur refuse ce qui dépasse l'encaissement
  /// (P3) ; le message remonte tel quel plutôt que d'être reformulé, parce
  /// qu'il dit exactement combien reste remboursable.
  Future<eccore.Refund?> refund({
    required String orderId,
    required String transactionId,
    required double amountMajor,
    required String reason,
  }) async {
    try {
      final rembourse = await _payments.refund(
        orderId: orderId,
        transactionId: transactionId,
        amount: eccore.Money(
          amountMinor: amountMajor.round(),
          currency: 'XOF',
        ),
        reason: reason,
      );
      // Le statut de la transaction d'origine ne change pas : un encaissement
      // a bien eu lieu, et l'écraser ferait disparaître ce fait.
      notifyListeners();
      return rembourse;
    } on eccore.ApiException catch (e) {
      _error = e.detail;
      debugPrint('Paiements : remboursement refusé — ${e.code}');
      notifyListeners();
      return null;
    }
  }
}
