import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:admin/presentation/echec.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Les filtres de l'écran des encaissements, tels qu'ils partent au serveur.
@immutable
class FiltresEncaissements {
  const FiltresEncaissements({
    this.statut,
    this.restaurantSlug,
    this.devise,
    this.recherche = '',
    this.depuis,
    this.jusqua,
  });

  final String? statut;
  final String? restaurantSlug;
  final String? devise;
  final String recherche;
  final DateTime? depuis;
  final DateTime? jusqua;

  FiltresEncaissements copyWith({
    String? statut,
    String? restaurantSlug,
    String? devise,
    String? recherche,
    DateTime? depuis,
    DateTime? jusqua,
    bool effacerStatut = false,
    bool effacerRestaurant = false,
    bool effacerDevise = false,
    bool effacerPeriode = false,
  }) {
    return FiltresEncaissements(
      statut: effacerStatut ? null : (statut ?? this.statut),
      restaurantSlug: effacerRestaurant ? null : (restaurantSlug ?? this.restaurantSlug),
      devise: effacerDevise ? null : (devise ?? this.devise),
      recherche: recherche ?? this.recherche,
      depuis: effacerPeriode ? null : (depuis ?? this.depuis),
      jusqua: effacerPeriode ? null : (jusqua ?? this.jusqua),
    );
  }
}

/// Encaissements et remboursements — `/payments/*` (Phase 6).
///
/// ## Ce qui a changé (22 septembre 2026)
///
/// * **La liste est paginée par le serveur.** Elle suivait `next` jusqu'au
///   bout — tout l'historique des encaissements du périmètre, sans borne de
///   date — pour en afficher vingt.
/// * **La recherche et les filtres sont ceux du serveur** (référence, période,
///   établissement, devise, statut). La recherche ne portait que sur la page
///   chargée, et l'écran ne proposait pas le statut « Annulé ».
/// * **Le total est rendu par devise** par le serveur. L'écran additionnait les
///   montants affichés, XOF et XAF confondus.
///
/// Consultation seule, et par construction : le statut d'une transaction
/// n'avance que sur webhook signé du prestataire. Le seul geste d'écriture est
/// le remboursement (`orders.refund`), qui crée un objet distinct.
class PaymentsService extends ChangeNotifier {
  PaymentsService({eccore.PaymentRepository? depot}) : _depot = depot;

  final eccore.PaymentRepository? _depot;

  eccore.PaymentRepository get _payments =>
      _depot ?? eccore.PaymentRepository(apiClient: AdminAuthService().apiClient);

  eccore.Page<eccore.Transaction>? _page;
  eccore.TransactionSummary? _totaux;
  FiltresEncaissements _filtres = const FiltresEncaissements();
  int _numeroDePage = 1;
  bool _enCours = false;
  Echec? _echec;
  bool _initialise = false;

  List<eccore.Transaction> get transactions => _page?.results ?? const [];
  eccore.TransactionSummary? get totaux => _totaux;
  FiltresEncaissements get filtres => _filtres;
  int get numeroDePage => _numeroDePage;
  int get total => _page?.count ?? 0;
  bool get aPageSuivante => _page?.hasNext ?? false;
  bool get aPagePrecedente => _page?.hasPrevious ?? false;
  bool get isLoading => _enCours;
  Echec? get echec => _echec;

  static const int tailleDePage = 20;

  int get nombreDePages => total == 0 ? 1 : (total + tailleDePage - 1) ~/ tailleDePage;

  Future<void> initialize() async {
    if (_initialise) return;
    _initialise = true;
    await appliquer(_filtres);
  }

  /// Applique une sélection : première page **et** totaux, sur les mêmes
  /// filtres — deux lectures qui ne s'accorderaient pas seraient pires que pas
  /// de totaux du tout.
  Future<void> appliquer(FiltresEncaissements filtres) async {
    _filtres = filtres;
    _numeroDePage = 1;
    await _lire(
      () => _payments.transactionsPage(
        status: filtres.statut,
        restaurantSlug: filtres.restaurantSlug,
        currency: filtres.devise,
        search: filtres.recherche,
        from: filtres.depuis,
        to: filtres.jusqua,
        pageSize: tailleDePage,
      ),
      avecTotaux: true,
    );
  }

  Future<void> refresh() => appliquer(_filtres);

  Future<void> pageSuivante() async {
    final suivante = _page?.next;
    if (suivante == null) return;
    _numeroDePage += 1;
    await _lire(() => _payments.transactionsAt(suivante));
  }

  Future<void> pagePrecedente() async {
    final precedente = _page?.previous;
    if (precedente == null) return;
    _numeroDePage -= 1;
    await _lire(() => _payments.transactionsAt(precedente));
  }

  Future<void> _lire(
    Future<eccore.Page<eccore.Transaction>> Function() lecture, {
    bool avecTotaux = false,
  }) async {
    _enCours = true;
    _echec = null;
    notifyListeners();
    try {
      _page = await lecture();
      if (avecTotaux) {
        _totaux = await _payments.transactionsSummary(
          status: _filtres.statut,
          restaurantSlug: _filtres.restaurantSlug,
          currency: _filtres.devise,
          search: _filtres.recherche,
          from: _filtres.depuis,
          to: _filtres.jusqua,
        );
      }
    } on eccore.ApiException catch (e) {
      _echec = Echec.de(e);
      eccore.Journal.trace('Paiements : lecture impossible — ${e.code}');
    } finally {
      _enCours = false;
      notifyListeners();
    }
  }

  /// Transactions d'une commande, sans toucher à la liste. Lève `ApiException`.
  Future<List<eccore.Transaction>> transactionsOf(String orderId) =>
      _payments.getTransactions(orderId: orderId);

  /// Rembourse tout ou partie d'une commande (permission `orders.refund`).
  ///
  /// [amount] porte **la devise de l'encaissement**. La version précédente
  /// convertissait la saisie avec la devise de l'établissement sélectionné
  /// dans le back-office — son commentaire disait l'inverse : un siège qui
  /// remboursait une commande de Douala (XAF) envoyait des XOF.
  ///
  /// Lève `ApiException` : le dialogue affiche le refus du serveur — « il
  /// reste 2 000 XOF remboursables » — sans se fermer, et sans que la saisie
  /// soit perdue.
  Future<eccore.Refund> refund({
    required String orderId,
    required String transactionId,
    required eccore.Money amount,
    required String reason,
  }) async {
    final rembourse = await _payments.refund(
      orderId: orderId,
      transactionId: transactionId,
      amount: amount,
      reason: reason,
    );
    // Le statut de la transaction d'origine ne change pas : un encaissement a
    // bien eu lieu, et l'écraser ferait disparaître ce fait.
    notifyListeners();
    return rembourse;
  }
}
